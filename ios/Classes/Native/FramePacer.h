#pragma once

namespace nosmai_zoom {
// The camera and Zoom need not use the same frame rate.
class FramePacer {
 public:
  void Reset() { next_due_ = 0; }

  bool Admit(double now, int fps) {
    if (fps <= 0) return false;
    const double interval = 1.0 / fps;
    if (now + interval * 0.1 < next_due_) return false;
    // Keep the original cadence over a late camera frame. After a stall,
    // start a new cadence so the sender never tries to catch up in a burst.
    next_due_ = (next_due_ == 0 || now - next_due_ >= interval)
                    ? now + interval
                    : next_due_ + interval;
    return true;
  }

 private:
  double next_due_ = 0;
};
}
