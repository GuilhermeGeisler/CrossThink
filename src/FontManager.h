#pragma once

#include "ExternalFont.h"

// Stub for CrossInk font manager (not yet ported).
// See SCOPE.md section 2 — CrossInk fonts are "planejado".
class FontManager {
 public:
  static FontManager& getInstance() {
    static FontManager instance;
    return instance;
  }

  bool isExternalFontEnabled() const { return false; }
  bool isExternalPrimary() const { return false; }
  ExternalFont* getActiveFont() { return nullptr; }
};
