#pragma once

#include <cstdint>

class GfxRenderer;

namespace HomeRenderer {

constexpr int kThumbnailCoverHeight = 210;
constexpr int kCoverCornerRadius = 6;

void drawRoundedProgressBar(const GfxRenderer& renderer, int x, int y, int width, int height, int8_t percent,
                            int maxRadius = 3);

}  // namespace HomeRenderer
