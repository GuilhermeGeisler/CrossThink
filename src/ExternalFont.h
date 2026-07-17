#pragma once

#include <cstdint>
#include <vector>

// Stub for CrossInk external font support (not yet ported).
// See SCOPE.md section 2 — CrossInk fonts are "planejado".
class ExternalFont {
 public:
  void preloadGlyphs(const uint32_t* codepoints, size_t count) {
    (void)codepoints;
    (void)count;
  }
};
