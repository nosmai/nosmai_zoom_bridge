#include "FrameFit.h"
#include "FramePacer.h"
#include <cassert>
#include <vector>
using namespace nosmai_zoom;
int main() {
  for (int output_fps : {15, 20, 25, 30}) {
    FramePacer pacer;
    int sent = 0;
    for (int frame = 0; frame < 300; ++frame) {
      if (pacer.Admit(1.0 + frame / 30.0, output_fps)) ++sent;
    }
    assert(sent == 10 * output_fps);
    assert(pacer.Admit(30.0, output_fps));
    assert(!pacer.Admit(30.001, output_fps));
    pacer.Reset();
    assert(!pacer.Admit(30.002, 0));
    assert(pacer.Admit(30.002, output_fps));
  }
  assert(I420Size(4, 2) == 12);
  assert(!I420Size(3, 2) && !I420Size(4, -2) && !I420Size(16384, 2));
  FrameFit fit;
  const std::vector<uint8_t> input = {1,2,3,4,5,6,7,8, 91,92, 151,152};
  std::vector<uint8_t> out(12);
  assert(fit.Convert(input.data(), 4, 2, out.data(), 4, 2, 16) && out == input);
  assert(NeedsQuarterTurn(4, 2, 2, 4));
  const std::vector<uint8_t> rotated = {4,8,3,7,2,6,1,5, 92,91, 152,151};
  assert(fit.Convert(input.data(), 4, 2, out.data(), 2, 4, 16) && out == rotated);
  // A rotated and resized portrait must keep U/V order and neutral bars.
  const std::vector<uint8_t> portrait = {60,60,60,60,60,60,60,60, 22,22, 208,208};
  out.assign(I420Size(12, 4), 255);
  assert(fit.Convert(portrait.data(), 2, 4, out.data(), 12, 4, 16));
  assert(out[0] == 16 && out[2] == 60 && out[11] == 16);
  assert(out[48] == 128 && out[49] == 22 && out[60] == 128 && out[61] == 208);
}
