#include <jni.h>

#include <cstdint>

#include "core_eq/c_api.h"

extern "C" JNIEXPORT jlong JNICALL
Java_dev_coreeq_audio_CoreEqAudioPlugin_nativeCreate(JNIEnv*, jobject) {
  return reinterpret_cast<jlong>(core_eq_create());
}

extern "C" JNIEXPORT void JNICALL
Java_dev_coreeq_audio_CoreEqAudioPlugin_nativeDestroy(JNIEnv*, jobject, jlong raw_handle) {
  auto* handle = reinterpret_cast<core_eq_handle*>(raw_handle);
  if (handle != nullptr) {
    core_eq_destroy(handle);
  }
}

extern "C" JNIEXPORT jint JNICALL
Java_dev_coreeq_audio_CoreEqAudioPlugin_nativeProcess(
    JNIEnv* env, jobject, jlong raw_handle, jobject pcm, jint frames, jint channels) {
  auto* handle = reinterpret_cast<core_eq_handle*>(raw_handle);
  if (handle == nullptr || pcm == nullptr || frames <= 0 ||
      (channels != 1 && channels != 2)) {
    return CORE_EQ_STATUS_INVALID_ARGUMENT;
  }
  auto* samples = static_cast<float*>(env->GetDirectBufferAddress(pcm));
  const jlong capacity = env->GetDirectBufferCapacity(pcm);
  const jlong required = static_cast<jlong>(frames) * channels;
  if (samples == nullptr || capacity < required) {
    return CORE_EQ_STATUS_INVALID_ARGUMENT;
  }
  return static_cast<jint>(
      core_eq_process(handle, samples, static_cast<size_t>(frames),
                      static_cast<size_t>(channels)));
}
