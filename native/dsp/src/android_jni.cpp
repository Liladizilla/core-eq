#include <jni.h>

#include <cmath>

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
  const jlong capacity_bytes = env->GetDirectBufferCapacity(pcm);
  const jlong required_bytes =
      static_cast<jlong>(frames) * channels * static_cast<jlong>(sizeof(float));
  if (samples == nullptr || capacity_bytes < required_bytes) {
    return CORE_EQ_STATUS_INVALID_ARGUMENT;
  }
  return static_cast<jint>(
      core_eq_process(handle, samples, static_cast<size_t>(frames),
                      static_cast<size_t>(channels)));
}

extern "C" JNIEXPORT jfloat JNICALL
Java_dev_coreeq_audio_CoreEqAudioPlugin_nativeGetPeakLevel(
    JNIEnv*, jobject, jlong raw_handle) {
  auto* handle = reinterpret_cast<core_eq_handle*>(raw_handle);
  float peak_level = 0.0f;
  if (handle == nullptr ||
      core_eq_get_peak_level(handle, &peak_level) != CORE_EQ_STATUS_OK) {
    return 0.0f;
  }
  return peak_level;
}

extern "C" JNIEXPORT jint JNICALL
Java_dev_coreeq_audio_CoreEqAudioPlugin_nativeSetBandGain(
    JNIEnv*, jobject, jlong raw_handle, jint band, jfloat gain_db) {
  auto* handle = reinterpret_cast<core_eq_handle*>(raw_handle);
  if (handle == nullptr || band < 0 || band >= 10 ||
      !std::isfinite(gain_db) || gain_db < -12.0f || gain_db > 12.0f) {
    return CORE_EQ_STATUS_INVALID_ARGUMENT;
  }
  constexpr float frequencies[] = {
      32.0f, 64.0f, 125.0f, 250.0f, 500.0f,
      1000.0f, 2000.0f, 4000.0f, 8000.0f, 16000.0f};
  return static_cast<jint>(core_eq_configure_band(
      handle, static_cast<uint32_t>(band), frequencies[band], 1.0f,
      gain_db, 48000.0f));
}

extern "C" JNIEXPORT jint JNICALL
Java_dev_coreeq_audio_CoreEqAudioPlugin_nativeSetOutputGain(
    JNIEnv*, jobject, jlong raw_handle, jfloat gain_db) {
  auto* handle = reinterpret_cast<core_eq_handle*>(raw_handle);
  if (handle == nullptr || !std::isfinite(gain_db) ||
      gain_db < -24.0f || gain_db > 6.0f) {
    return CORE_EQ_STATUS_INVALID_ARGUMENT;
  }
  return static_cast<jint>(core_eq_set_output_gain_db(handle, gain_db));
}

extern "C" JNIEXPORT jint JNICALL
Java_dev_coreeq_audio_CoreEqAudioPlugin_nativeSetBypassed(
    JNIEnv*, jobject, jlong raw_handle, jboolean bypassed) {
  auto* handle = reinterpret_cast<core_eq_handle*>(raw_handle);
  if (handle == nullptr) return CORE_EQ_STATUS_INVALID_ARGUMENT;
  return static_cast<jint>(core_eq_set_bypassed(handle, bypassed == JNI_TRUE ? 1 : 0));
}
