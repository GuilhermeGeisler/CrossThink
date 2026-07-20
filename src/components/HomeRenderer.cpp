#include "HomeRenderer.h"

#include <GfxRenderer.h>
#include <algorithm>

namespace HomeRenderer {

void drawRoundedProgressBar(const GfxRenderer& renderer, const int x, const int y, const int width, const int height,
                            const int8_t percent, const int maxRadius) {
  if (width <= 0 || height <= 0) return;
  const int radius = std::min({maxRadius, width / 2, height / 2});

  renderer.drawRoundedRect(x, y, width, height, 1, radius, true);

  if (percent < 0) return;
  const int clamped = percent > 100 ? 100 : static_cast<int>(percent);
  const int innerW = width - 2;
  const int innerH = height - 2;
  if (innerW <= 0 || innerH <= 0) return;

  const int fillW = innerW * clamped / 100;
  if (fillW <= 0) return;

  const int fillRadius = std::max(0, radius - 1);
  if (fillW >= innerW) {
    renderer.fillRoundedRect(x + 1, y + 1, innerW, innerH, fillRadius, Color::Black);
  } else {
    renderer.fillRoundedRect(x + 1, y + 1, fillW, innerH, fillRadius,
                             /*roundTopLeft=*/true, /*roundTopRight=*/false,
                             /*roundBottomLeft=*/true, /*roundBottomRight=*/false, Color::Black);
  }
}

}  // namespace HomeRenderer
