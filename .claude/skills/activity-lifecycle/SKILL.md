---
name: activity-lifecycle
description: Activity lifecycle pattern for the firmware's UI framework. Use when creating, modifying, or reviewing any Activity subclass. Covers onEnter/onExit resource pairing, the render task and RenderLock, startActivityForResult result flow, the activity stack (push/pop vs replace), and common pitfalls (use-after-free, leaked tasks, double-delete).
---

# Activity Lifecycle

The UI is a stack of `Activity` objects managed by `ActivityManager`. Each
activity is **heap-allocated** and **deleted on exit**. Getting the lifecycle
wrong is the #1 source of crashes in this codebase.

## The contract

```
onEnter()  → allocate resources, start tasks, first render
loop()     → process input (called every frame while active)
render()   → draw to framebuffer (called by render task, under RenderLock)
onExit()   → free ALL resources in reverse order of allocation
```

**Rule:** anything allocated in `onEnter` MUST be freed in `onExit`. The
activity is `delete`d immediately after `onExit` returns.

## Resource pairing

```cpp
void MyActivity::onEnter() {
  Activity::onEnter();
  buffer = makeUniqueNoThrow<uint8_t[]>(BUFFER_SIZE);  // alloc
  xTaskCreate(&taskTrampoline, "MyTask", 4096, this, 1, &taskHandle);  // task
  requestUpdate();
}

void MyActivity::onExit() {
  if (taskHandle) { vTaskDelete(taskHandle); taskHandle = nullptr; }  // task first
  buffer.reset();  // then buffers
  Activity::onExit();
}
```

**Order matters:** delete FreeRTOS tasks BEFORE freeing buffers they may access.
A deleted task cannot touch freed memory; a freed buffer accessed by a live task
is a use-after-free.

## RenderLock and the render task

`render()` runs on a **separate FreeRTOS task** pinned to core 0. It acquires
`RenderLock` (RAII mutex) before calling your `render()` method. This means:

- `render()` and `loop()` can run concurrently
- Never touch shared state from `render()` without synchronization
- `requestUpdate()` signals the render task; it does NOT call `render()` directly
- `requestUpdateAndWait()` blocks until the render completes (never call from
  the render task itself — deadlock)

## Navigation patterns

| Pattern | Method | Behavior |
|---------|--------|----------|
| Replace | `activityManager.replaceActivity()` | Delete current, create new |
| Push | `startActivityForResult()` | Current goes to stack, new on top |
| Pop | `finish()` | Delete current, restore from stack |

**startActivityForResult** passes a result back via callback:

```cpp
startActivityForResult(
    std::make_unique<KeyboardActivity>(renderer, mappedInput),
    [this](const ActivityResult& result) {
      if (!result.isCancelled) {
        auto text = std::get<KeyboardResult>(result.data).text;
        // handle result
      }
      requestUpdate();
    });
```

## Common pitfalls

1. **Use-after-free:** task still running after `onExit` deletes the activity.
   Always `vTaskDelete` in `onExit`.
2. **Leaked task:** forgot to delete → task accesses deleted activity on next
   iteration.
3. **Double-delete:** calling `finish()` from `onExit` (already being destroyed).
4. **Member `HalFile` not closed:** member `FsFile`/`HalFile` handles persist
   beyond function scope — close them in `onExit` (local variables auto-close
   via `DESTRUCTOR_CLOSES_FILE`).
5. **Allocating in `loop()` or `render()`:** hoist to `onEnter`, reuse across
   frames.

## Self-review

- [ ] Every `onEnter` allocation has a matching free in `onExit`.
- [ ] FreeRTOS tasks deleted in `onExit` before buffer deallocation.
- [ ] No allocation inside `loop()` or `render()` that could be hoisted.
- [ ] Member `HalFile`/`FsFile` handles closed in `onExit`.
- [ ] `finish()` never called from `onExit`.
- [ ] `startActivityForResult` callback handles `isCancelled`.
