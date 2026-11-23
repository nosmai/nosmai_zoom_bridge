#include "FrameFit.h"
#include <algorithm>
#include <cstring>
#include "libyuv/rotate.h"
#include "libyuv/scale.h"

namespace nosmai_zoom {
size_t I420Size(int w, int h) {
  if (w <= 0 || h <= 0 || w > 8192 || h > 8192 || (w & 1) || (h & 1)) return 0;
  return size_t(w) * h * 3 / 2;
}

bool NeedsQuarterTurn(int w, int h, int tw, int th) {
  return (w > h && tw < th) || (w < h && tw > th);
}

bool FrameFit::Convert(const uint8_t* src, int w, int h, uint8_t* dst,
                       int tw, int th, uint8_t black) {
  const size_t inSize = I420Size(w, h);
  const size_t outSize = I420Size(tw, th);
  if (!inSize || !outSize || !src || !dst) return false;
  if (w == tw && h == th) {
    std::memcpy(dst, src, inSize);
    return true;
  }
  int area = w * h;
  if (NeedsQuarterTurn(w, h, tw, th)) {
    const bool exact = w == th && h == tw;
    if (!exact) rotated_.resize(inSize);
    uint8_t* rot = exact ? dst : rotated_.data();
    if (libyuv::I420Rotate(src, w, src + area, w / 2, src + area * 5 / 4, w / 2,
            rot, h, rot + area, h / 2, rot + area * 5 / 4, h / 2,
            w, h, libyuv::kRotate270) != 0) return false;
    if (exact) return true;
    src = rot;
    std::swap(w, h);
  }
  int fw = tw, fh = th;
  if (w * th > h * tw) fh = std::max(2, (h * tw / w) & ~1);
  else fw = std::max(2, (w * th / h) & ~1);
  const int x = ((tw - fw) / 2) & ~1, y = ((th - fh) / 2) & ~1;
  const int outArea = tw * th;
  if (fw != tw || fh != th) {
    std::memset(dst, black, outArea);
    std::memset(dst + outArea, 128, outArea / 2);
  }
  const int uvOffset = y / 2 * (tw / 2) + x / 2;
  return libyuv::I420Scale(src, w, src + area, w / 2, src + area * 5 / 4, w / 2,
             w, h, dst + y * tw + x, tw, dst + outArea + uvOffset, tw / 2,
             dst + outArea * 5 / 4 + uvOffset, tw / 2, fw, fh,
             libyuv::kFilterBilinear) == 0;
}
}
