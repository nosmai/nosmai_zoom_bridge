#pragma once
#include <cstddef>
#include <cstdint>
#include <vector>

namespace nosmai_zoom {
// Zoom's external sender accepts tightly packed I420 in the advertised geometry.
size_t I420Size(int width, int height);
bool NeedsQuarterTurn(int width, int height, int targetWidth, int targetHeight);

class FrameFit {
 public:
  bool Convert(const uint8_t* input, int width, int height, uint8_t* output,
               int targetWidth, int targetHeight, uint8_t black);
 private:
  std::vector<uint8_t> rotated_;
};
}
