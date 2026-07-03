---
name: simulator-parity
description: Simulator build discipline for the native SDL2 desktop simulator. Use when adding new hardware-dependent code, modifying platformio.ini build filters, or creating simulator stubs. Covers the build_src_filter exclusions, sim_stubs for HAL-only code, the lib_ignore list, and keeping simulator builds green.
---

# Simulator Parity

The simulator runs the firmware natively on the host (Linux/macOS/Windows)
using SDL2 for display emulation. It shares ~95% of the device codebase but
excludes hardware-specific and network code. Keeping the simulator build green
is a CI requirement.

## What the simulator covers

- EPUB/XTC/TXT rendering and layout
- Activity lifecycle and navigation
- Settings load/save
- Font system (builtin + SD card)
- All UI themes
- Games, flashcards, tools

## What it does NOT cover

- BLE (stub empty)
- WiFi / OTA / network (files excluded from build)
- Hardware GPIO / display SPI
- Deep sleep / power management

## Build filter

The `[env:simulator]` section in `platformio.ini` excludes device-only files:

```ini
build_src_filter =
  +<*>
  -<network/CrossPointWebServer.cpp>
  -<network/FirmwareFlasher.cpp>
  -<network/OtaBootSwitch.cpp>
  -<network/OtaUpdater.cpp>
  -<network/WebDAVHandler.cpp>
  -<platform/skip_efuse_blk_check.c>
```

**When adding a new file:** if it depends on WiFi, OTA, or hardware-specific
APIs, add it to the exclusion list. Otherwise the simulator build will fail.

## sim_stubs

The `src/simulator/sim_stubs/` directory contains no-op implementations of
HAL classes that don't exist on the host:

```cpp
// src/simulator/sim_stubs/HalGPIO_stub.h
class HalGPIO {
 public:
  void begin() {}
  void update() {}
  bool isPressed(uint8_t) const { return false; }
  // ... all methods return safe defaults
};
```

The `-Isrc/simulator/sim_stubs` flag in `build_flags` makes these stubs
visible to the simulator build instead of the real HAL headers.

**When adding a new HAL class:** create a stub in `sim_stubs/` that provides
safe no-op implementations of all public methods.

## lib_ignore

The simulator ignores libraries that don't compile natively:

```ini
lib_ignore = hal, WebSockets
```

The `hal` library depends on ESP-IDF headers. The simulator uses `sim_stubs`
instead.

## Conditional compilation

For code that needs different behavior on device vs simulator:

```cpp
#ifdef SIMULATOR
  // Simulator-specific code
  SDL_Delay(10);
#else
  // Device-specific code
  delay(10);
#endif
```

Use sparingly — prefer abstraction through the HAL.

## Keeping the simulator green

Before pushing, verify the simulator builds:

```bash
pio run -e simulator
```

Common failures:
- New file uses `WiFi.h` or `WebServer.h` → add to `build_src_filter` exclusion
- New HAL method added but no stub → add to `sim_stubs/`
- ESP-IDF-specific API used without `#ifdef SIMULATOR` guard

## Self-review

- [ ] New device-only files added to `build_src_filter` exclusion list.
- [ ] New HAL methods have stub implementations in `sim_stubs/`.
- [ ] `pio run -e simulator` passes locally before push.
- [ ] No `#include <WiFi.h>` or similar in shared code paths.
- [ ] Hardware-specific code guarded with `#ifndef SIMULATOR` if in shared files.
