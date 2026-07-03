---
name: theme-system
description: Theme system architecture for the firmware's UI rendering. Use when creating a new theme, modifying BaseTheme methods, or changing ThemeMetrics. Covers the BaseTheme interface, ThemeMetrics struct, UITheme singleton, GUI macro, theme inheritance, and the draw* method contract.
---

# Theme System

The UI rendering is abstracted through `BaseTheme` and `ThemeMetrics`. All
drawing goes through the `GUI` macro (UITheme singleton), never direct
renderer calls for UI components. This allows multiple visual themes to share
the same activity code.

## Architecture

```
UITheme (singleton)
├── currentTheme: unique_ptr<BaseTheme>   // active theme instance
└── currentMetrics: const ThemeMetrics*   // active metrics

BaseTheme (interface)
├── ClassicTheme (default, built into BaseTheme.cpp)
├── LyraTheme
├── Lyra3CoversTheme
└── RoundedRaffTheme
```

Activities call `GUI.drawHeader(...)`, `GUI.drawList(...)`, etc. The `GUI`
macro resolves to `UITheme::getInstance().getTheme()`, which dispatches to the
active theme's implementation.

## The GUI macro

```cpp
// In any activity's render() method:
GUI.drawHeader(renderer, rect, title, subtitle);
GUI.drawList(renderer, rect, itemCount, selectedIndex, rowTitle);
GUI.drawButtonHints(renderer, btn1, btn2, btn3, btn4);
GUI.drawPopup(renderer, message);
```

**Never** bypass `GUI` for UI components. Direct `renderer.drawText()` calls
for UI elements break theme consistency.

## ThemeMetrics

`ThemeMetrics` defines all spacing, sizing, and layout constants:

```cpp
struct ThemeMetrics {
  int topPadding;
  int headerHeight;
  int tabBarHeight;
  int listRowHeight;
  int buttonHintsHeight;
  int homeTopPadding;
  int homeCoverHeight;
  // ... 60+ fields
};
```

Access via `UITheme::getInstance().getMetrics()`:

```cpp
const auto& metrics = UITheme::getInstance().getMetrics();
Rect headerRect{0, metrics.topPadding, pageWidth, metrics.headerHeight};
GUI.drawHeader(renderer, headerRect, title);
```

**Never** hardcode pixel values. Always use metrics.

## BaseTheme methods

| Method | Purpose |
|--------|---------|
| `drawHeader` | Top bar with title and optional subtitle |
| `drawList` | Scrollable list with selection highlight |
| `drawTabBar` | Category tabs (settings screen) |
| `drawButtonHints` | Bottom button labels |
| `drawSideButtonHints` | Side button labels (physical buttons) |
| `drawProgressBar` | Horizontal progress bar |
| `drawBatteryLeft/Right` | Battery icon with percentage |
| `drawStatusBar` | Reader status bar (page, progress, clock) |
| `drawPopup` | Modal popup with optional progress |
| `drawOptionPopup` | Selection popup with options list |
| `drawTextField` | Text input field with cursor |
| `drawKeyboardKey` | On-screen keyboard key |
| `drawRecentBookCover` | Home screen cover tile |
| `drawButtonMenu` | Home screen menu with icons |

## Creating a new theme

1. **Create the theme class** inheriting from `BaseTheme`:

```cpp
// src/components/themes/mytheme/MyTheme.h
#pragma once
#include "components/themes/BaseTheme.h"

class MyTheme : public BaseTheme {
 public:
  void drawHeader(const GfxRenderer& renderer, Rect rect,
                  const char* title, const char* subtitle) const override;
  void drawList(const GfxRenderer& renderer, Rect rect, int itemCount,
                int selectedIndex, ...) const override;
  // Override only the methods you want to customize
};
```

2. **Define custom metrics** (or reuse `BaseMetrics::values`):

```cpp
namespace MyMetrics {
constexpr ThemeMetrics values = {
  .topPadding = 8,        // override specific values
  .headerHeight = 50,
  // ... copy rest from BaseMetrics::values
};
}
```

3. **Register in UITheme::setTheme()**:

```cpp
void UITheme::setTheme(CrossPointSettings::UI_THEME type) {
  switch (type) {
    case CrossPointSettings::CLASSIC:
      currentTheme = std::make_unique<BaseTheme>();
      currentMetrics = &BaseMetrics::values;
      break;
    case CrossPointSettings::MY_THEME:
      currentTheme = std::make_unique<MyTheme>();
      currentMetrics = &MyMetrics::values;
      break;
  }
}
```

4. **Add to the settings enum** in `CrossPointSettings.h`:

```cpp
enum UI_THEME { CLASSIC = 0, LYRA = 1, LYRA_3_COVERS = 2,
                ROUNDEDRAFF = 3, MY_THEME = 4 };
```

## Theme inheritance

Themes can inherit and override selectively. `LyraTheme` overrides only
`drawHeader`, `drawList`, and `drawRecentBookCover` — everything else falls
through to `BaseTheme`'s default implementation.

## Self-review

- [ ] All UI rendering goes through `GUI.draw*()` methods.
- [ ] No hardcoded pixel values; using `ThemeMetrics`.
- [ ] New theme registered in `UITheme::setTheme()`.
- [ ] New theme added to `UI_THEME` enum in `CrossPointSettings.h`.
- [ ] Theme selectable in Settings → Display → UI Theme.
