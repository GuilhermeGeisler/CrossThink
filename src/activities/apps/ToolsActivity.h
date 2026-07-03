#pragma once
#include <I18n.h>

#include <functional>
#include <vector>

#include "../Activity.h"
#include "util/ButtonNavigator.h"

// Central hub for games, utilities, and flashcards merged in from CrossPet,
// Shortbread, and CrossWordle. Mirrors CrossPet's ToolsActivity pattern:
// a simple toggle-filtered menu list, each entry pushing its own Activity.
class ToolsActivity final : public Activity {
  ButtonNavigator buttonNavigator;
  int selectorIndex = 0;

  struct AppEntry {
    StrId labelId;
    std::function<void()> launch;
  };
  std::vector<AppEntry> menuEntries;

  void buildMenu();

 public:
  explicit ToolsActivity(GfxRenderer& renderer, MappedInputManager& mappedInput)
      : Activity("Tools", renderer, mappedInput) {}

  void onEnter() override;
  void loop() override;
  void render(RenderLock&&) override;
};
