---
name: freertos-patterns
description: FreeRTOS concurrency patterns for the ESP32-C3 single-core firmware. Use when creating tasks, using mutexes/semaphores, communicating between ISR and task context, or debugging deadlocks and race conditions. Covers task creation, RenderLock, xTaskNotify for signaling, ISR-safe primitives, critical sections, and common deadlock scenarios.
---

# FreeRTOS Patterns

The ESP32-C3 is single-core but still runs multiple FreeRTOS tasks concurrently
(main loop, render task, WiFi task, web server). Concurrency bugs are subtle
and often manifest as silent hangs or panics, not crashes.

## Task creation

```cpp
void MyActivity::onEnter() {
  Activity::onEnter();
  xTaskCreate(
      &taskTrampoline,   // function pointer
      "MyTask",          // name (for debugging)
      4096,              // stack size in BYTES (not words)
      this,              // parameter (usually 'this')
      1,                 // priority (1 = normal)
      &taskHandle        // output handle
  );
}

void MyActivity::taskTrampoline(void* param) {
  static_cast<MyActivity*>(param)->taskLoop();
}

[[noreturn]] void MyActivity::taskLoop() {
  while (true) {
    ulTaskNotifyTake(pdTRUE, portMAX_DELAY);  // wait for signal
    doWork();
  }
}
```

**Stack sizing:** 2048 for simple tasks, 4096 for EPUB parsing or network I/O.
Monitor with `uxTaskGetStackHighWaterMark(taskHandle)` — if it drops below 512,
increase the stack.

## Signaling with xTaskNotify

The render task uses `xTaskNotify` for lightweight signaling (cheaper than
semaphores, no allocation):

```cpp
// Signal the render task
void ActivityManager::requestUpdate(bool immediate) {
  if (immediate && renderTaskHandle) {
    xTaskNotify(renderTaskHandle, 1, eIncrement);  // increment counter
  } else {
    requestedUpdate = true;  // defer to end of loop
  }
}

// Wait for signal (render task loop)
void ActivityManager::renderTaskLoop() {
  while (true) {
    ulTaskNotifyTake(pdTRUE, portMAX_DELAY);  // block until notified
    RenderLock lock;
    if (currentActivity) currentActivity->render(std::move(lock));
  }
}
```

`eIncrement` means rapid calls don't lose signals — the counter accumulates.

## RenderLock (RAII mutex)

`RenderLock` wraps `xSemaphoreTake`/`xSemaphoreGive` on the rendering mutex:

```cpp
// Automatic — render() is called under lock
void MyActivity::render(RenderLock&& lock) {
  renderer.clearScreen();
  // ... draw ...
  renderer.displayBuffer();
}

// Manual — from loop() or another task
{
  RenderLock lock;
  renderer.clearScreen();
  GUI.drawPopup(renderer, "Message");
  renderer.displayBuffer();
}
```

**Deadlock rule:** never call `requestUpdateAndWait()` while holding a
`RenderLock`. The render task needs the lock to complete, and you're holding it
while waiting for the render task.

## ISR vs task communication

ISR handlers (`IRAM_ATTR`) cannot call `xSemaphoreTake` — it will crash. Use
the correct primitive for each direction:

| Direction | Primitive |
|-----------|-----------|
| ISR → task (data) | `xQueueSendFromISR()` + `portYIELD_FROM_ISR()` |
| ISR → task (signal) | `xSemaphoreGiveFromISR()` + `portYIELD_FROM_ISR()` |
| Task → task | `xSemaphoreTake()` / mutex |
| Simple flag (single writer ISR) | `volatile bool` + `portENTER_CRITICAL_ISR()` |

```cpp
void IRAM_ATTR gpioISR() {
  BaseType_t xHigherPriorityTaskWoken = pdFALSE;
  xSemaphoreGiveFromISR(eventSemaphore, &xHigherPriorityTaskWoken);
  portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}
```

## Critical sections

For short, non-blocking operations on shared state:

```cpp
static portMUX_TYPE spinlock = portMUX_INITIALIZER_UNLOCKED;

taskENTER_CRITICAL(&spinlock);
sharedCounter++;
taskEXIT_CRITICAL(&spinlock);
```

**Rules:**
- Keep critical sections short (no I/O, no allocations, no logging)
- Never call `xSemaphoreTake` inside a critical section
- Use `taskENTER_CRITICAL_ISR` / `taskEXIT_CRITICAL_ISR` from ISR context

## Common deadlock scenarios

1. **RenderLock + requestUpdateAndWait:** holding the lock while waiting for
   the render task that needs the lock.
2. **Nested mutexes:** taking mutex A while holding mutex B, when another path
   takes B then A.
3. **Task deletion while blocked:** deleting a task that's blocked on a mutex
   held by the deleting task.

## Self-review

- [ ] Task stack sized appropriately (2048 simple, 4096 complex).
- [ ] `vTaskDelete` in `onExit` before buffer deallocation.
- [ ] No `xSemaphoreTake` in ISR context.
- [ ] No `requestUpdateAndWait` while holding `RenderLock`.
- [ ] Critical sections short and non-blocking.
- [ ] `uxTaskGetStackHighWaterMark` checked during testing.
