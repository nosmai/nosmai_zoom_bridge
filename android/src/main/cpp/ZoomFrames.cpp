#include <jni.h>
#include "FrameFit.h"

extern "C" JNIEXPORT jint JNICALL
Java_com_nosmai_zoom_NosmaiZoomSource_fit(JNIEnv* env, jclass, jobject in, jint w,
    jint h, jobject out, jint tw, jint th) {
  const auto inSize = nosmai_zoom::I420Size(w, h);
  const auto outSize = nosmai_zoom::I420Size(tw, th);
  if (!inSize || !outSize || env->GetDirectBufferCapacity(in) < jlong(inSize) ||
      env->GetDirectBufferCapacity(out) < jlong(outSize)) return -1;
  thread_local nosmai_zoom::FrameFit fit;
  if (!fit.Convert(static_cast<uint8_t*>(env->GetDirectBufferAddress(in)), w, h,
                   static_cast<uint8_t*>(env->GetDirectBufferAddress(out)), tw, th, 0)) return -1;
  return nosmai_zoom::NeedsQuarterTurn(w, h, tw, th) ? 90 : 0;
}
