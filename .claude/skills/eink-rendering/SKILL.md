---
name: eink-rendering
description: E-Ink display rendering discipline for the firmware. Use when modifying any rendering code, adding refresh modes, handling grayscale, or working with the framebuffer. Covers half vs full refresh tradeoffs, ghosting management, the single-buffer constraint, grayscale tiled streaming, RenderLock, and orientation-aware geometry.
---

# E-Ink Rendering

E-Ink is not LCD. Every paint takes 500ms–2s, the panel retains its last frame
without power, and partial updates leave ghost artifacts. The rendering code
must account for all of this.

## Refresh modes

| Mode | Duration | Use case | Ghosting |
|------|----------|----------|----------|
| `FULL_REFRESH` | ~2s | Boot screen, sleep screen, every N pages | None |
| `HALF_REFRESH` | ~1.7s | Balanced quality/speed | Minimal |
| `FAST_REFRESH` | ~500ms | Page turns, UI navigation | Accumulates |

**Rule:** use `FAST_REFRESH` for interactive content, promote to `FULL_REFRESH`
periodically (controlled by `SETTINGS.refreshFrequency`, default every 15 pages)
to clear ghosting.

```cpp
renderer.displayBuffer(HalDisplay::FAST_REFRESH);  // normal page turn
renderer.displayBuffer(HalDisplay::FULL_REFRESH);  // clear ghosting
```

## Single-buffer constraint

The ESP32-C3 has only **one** 48KB framebuffer (`DEINK_DISPLAY_SINGLE_BUFFER_MODE=1`).
There is no double-buffering. This means:

- **Grayscale rendering** must use `storeBwBuffer()` / `restoreBwBuffer()` to
  temporarily save the BW base frame, render grayscale planes, then restore.
  Never malloc a second 48KB buffer.
- **Tiled grayscale** streams one band at a time via `writeGrayscalePlaneStrip()`
  to avoid needing a full grayscale buffer in RAM.
- **Cover image caching** in `HomeActivity` snapshots only the tile rect
  (~16KB), not the full framebuffer.

## Ghosting management

Ghost artifacts accumulate with `FAST_REFRESH`. The reader tracks pages since
last full refresh and promotes automatically:

```cpp
if (++pagesUntilFullRefresh >= SETTINGS.getRefreshFrequency()) {
  renderer.displayBuffer(HalDisplay::FULL_REFRESH);
  pagesUntilFullRefresh = 0;
} else {
  renderer.displayBuffer(HalDisplay::FAST_REFRESH);
}
```

**When to force FULL_REFRESH:**
- After showing a full-screen image (cover, sleep screen)
- After orientation change
- On user-requested refresh (power button with `FORCE_REFRESH` setting)

## Orientation-aware geometry

Never hardcode 800 or 480. The renderer transforms coordinates based on
`SETTINGS.orientation` (portrait, landscape CW/CCW, inverted).

```cpp
// WRONG
renderer.drawText(font, 10, 790, text);  // hardcoded Y

// CORRECT
const auto [top, right, bottom, left] = renderer.getOrientedViewableTRBL();
const auto pageHeight = renderer.getScreenHeight();
renderer.drawText(font, left, pageHeight - bottom - lineHeight, text);
```

Use `renderer.getScreenWidth()` / `getScreenHeight()` for logical dimensions.
Use `getOrientedViewableTRBL()` for the safe area inside bezel margins.

## RenderLock

`render()` runs on a separate task. `RenderLock` (RAII mutex) is acquired
automatically before your `render()` method is called. Manual locking:

```cpp
// From loop() or another task:
{
  RenderLock lock;
  renderer.clearScreen();
  renderer.drawText(font, x, y, "Popup message");
  renderer.displayBuffer();
}
```

**Never** call `requestUpdateAndWait()` while holding a `RenderLock` — deadlock.

## Self-review

- [ ] No hardcoded 800/480 coordinates; using renderer metrics.
- [ ] Refresh mode appropriate for context (FAST for interactive, FULL for images).
- [ ] No second full-screen buffer; grayscale uses store/restoreBwBuffer.
- [ ] Ghosting managed (auto-promote after N pages, or explicit after images).
- [ ] RenderLock not held when calling `requestUpdateAndWait()`.
