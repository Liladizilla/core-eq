#include "core_eq/c_api.h"

#include <cmath>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <vector>

int main() {
  if (core_eq_abi_version() != 1U) return EXIT_FAILURE;
  if (core_eq_set_input_gain_db(nullptr, 0.0f) != CORE_EQ_STATUS_INVALID_ARGUMENT) return EXIT_FAILURE;

  core_eq_handle* handle = core_eq_create();
  if (handle == nullptr) return EXIT_FAILURE;
  if (core_eq_set_input_gain_db(handle, std::numeric_limits<float>::quiet_NaN()) != CORE_EQ_STATUS_INVALID_ARGUMENT) return EXIT_FAILURE;
  if (core_eq_set_bypassed(handle, 2) != CORE_EQ_STATUS_INVALID_ARGUMENT) return EXIT_FAILURE;
  if (core_eq_configure_band(handle, 10, 1000.0f, 1.0f, 0.0f, 48000.0f) != CORE_EQ_STATUS_INVALID_ARGUMENT) return EXIT_FAILURE;
  if (core_eq_configure_band(handle, 0, 1000.0f, std::numeric_limits<float>::denorm_min(), 6.0f, 48000.0f) != CORE_EQ_STATUS_INVALID_ARGUMENT) return EXIT_FAILURE;
  if (core_eq_process(handle, nullptr, 1, 2) != CORE_EQ_STATUS_INVALID_ARGUMENT) return EXIT_FAILURE;
  if (core_eq_process(handle, nullptr, 0, 2) != CORE_EQ_STATUS_OK) return EXIT_FAILURE;
  float peak_level = -1.0f;
  if (core_eq_get_peak_level(handle, &peak_level) != CORE_EQ_STATUS_OK || peak_level != 0.0f) return EXIT_FAILURE;
  if (core_eq_get_peak_level(nullptr, &peak_level) != CORE_EQ_STATUS_INVALID_ARGUMENT) return EXIT_FAILURE;
  if (core_eq_get_peak_level(handle, nullptr) != CORE_EQ_STATUS_INVALID_ARGUMENT) return EXIT_FAILURE;

  if (core_eq_set_bypassed(handle, 1) != CORE_EQ_STATUS_OK) return EXIT_FAILURE;
  std::vector<float> samples(64, 0.25f);
  if (core_eq_process(handle, samples.data(), 32, 2) != CORE_EQ_STATUS_OK) return EXIT_FAILURE;
  for (float sample : samples) if (sample != 0.25f) return EXIT_FAILURE;
  if (core_eq_get_peak_level(handle, &peak_level) != CORE_EQ_STATUS_OK ||
      std::abs(peak_level - 0.25f) > 1.0e-6f) return EXIT_FAILURE;
  std::vector<float> silence(64, 0.0f);
  if (core_eq_process(handle, silence.data(), 32, 2) != CORE_EQ_STATUS_OK ||
      core_eq_get_peak_level(handle, &peak_level) != CORE_EQ_STATUS_OK ||
      peak_level != 0.0f) return EXIT_FAILURE;

  if (core_eq_set_bypassed(handle, 0) != CORE_EQ_STATUS_OK) return EXIT_FAILURE;
  if (core_eq_set_input_gain_db(handle, 3.0f) != CORE_EQ_STATUS_OK) return EXIT_FAILURE;
  if (core_eq_set_output_gain_db(handle, -2.0f) != CORE_EQ_STATUS_OK) return EXIT_FAILURE;
  if (core_eq_configure_band(handle, 0, 1000.0f, 1.0f, 4.0f, 48000.0f) != CORE_EQ_STATUS_OK) return EXIT_FAILURE;
  if (core_eq_reset(handle) != CORE_EQ_STATUS_OK) return EXIT_FAILURE;

  std::vector<float> audio(256, 0.1f);
  if (core_eq_process(handle, audio.data(), 256, 1) != CORE_EQ_STATUS_OK) return EXIT_FAILURE;
  for (float sample : audio) if (!std::isfinite(sample) || std::abs(sample) > 1.0f) return EXIT_FAILURE;
  if (core_eq_get_peak_level(handle, &peak_level) != CORE_EQ_STATUS_OK ||
      !std::isfinite(peak_level) || peak_level <= 0.0f || peak_level > 1.0f) {
    std::cerr << "Peak meter did not report processed audio\n";
    return EXIT_FAILURE;
  }

  core_eq_destroy(handle);

  core_eq_handle* queue_handle = core_eq_create();
  if (queue_handle == nullptr) return EXIT_FAILURE;
  for (int i = 0; i < 127; ++i) {
    if (core_eq_set_input_gain_db(queue_handle, 0.0f) != CORE_EQ_STATUS_OK) return EXIT_FAILURE;
  }
  if (core_eq_set_input_gain_db(queue_handle, 0.0f) != CORE_EQ_STATUS_QUEUE_FULL) {
    std::cerr << "Full parameter queue was not reported\n";
    return EXIT_FAILURE;
  }

  // A render callback consumes queued events. Once drained, setters must be
  // able to enqueue again instead of remaining permanently stuck at full.
  std::vector<float> drain_buffer(2, 0.0f);
  if (core_eq_process(queue_handle, drain_buffer.data(), 1, 2) != CORE_EQ_STATUS_OK) {
    std::cerr << "Processing failed while draining the parameter queue\n";
    return EXIT_FAILURE;
  }
  if (core_eq_set_input_gain_db(queue_handle, 0.0f) != CORE_EQ_STATUS_OK) {
    std::cerr << "Parameter queue did not recover after processing\n";
    return EXIT_FAILURE;
  }
  core_eq_destroy(queue_handle);

  // Processing the same stream in differently sized blocks must preserve
  // filter history and produce the same samples. This is the core contract
  // needed by a future decoded-PCM player feeding native DSP incrementally.
  core_eq_handle* whole_handle = core_eq_create();
  core_eq_handle* chunked_handle = core_eq_create();
  if (whole_handle == nullptr || chunked_handle == nullptr) return EXIT_FAILURE;
  for (core_eq_handle* current : {whole_handle, chunked_handle}) {
    if (core_eq_configure_band(current, 0, 1000.0f, 0.9f, 5.0f, 48000.0f) != CORE_EQ_STATUS_OK ||
        core_eq_configure_band(current, 3, 250.0f, 1.2f, -3.0f, 48000.0f) != CORE_EQ_STATUS_OK ||
        core_eq_set_input_gain_db(current, -1.5f) != CORE_EQ_STATUS_OK ||
        core_eq_set_output_gain_db(current, 1.0f) != CORE_EQ_STATUS_OK) {
      return EXIT_FAILURE;
    }
  }
  constexpr std::size_t stream_frames = 1024;
  std::vector<float> whole_stream(stream_frames * 2);
  for (std::size_t i = 0; i < whole_stream.size(); ++i) {
    whole_stream[i] = 0.2f * std::sin(
        2.0f * 3.14159265358979323846f * 997.0f * (i / 2) / 48000.0f +
        ((i % 2) ? 0.03f : 0.0f));
  }
  std::vector<float> chunked_stream = whole_stream;
  if (core_eq_process(whole_handle, whole_stream.data(), stream_frames, 2) != CORE_EQ_STATUS_OK) {
    return EXIT_FAILURE;
  }
  const std::size_t chunks[] = {1, 137, 256, 17, 401, 212};
  std::size_t frame_offset = 0;
  for (const std::size_t chunk_frames : chunks) {
    if (core_eq_process(chunked_handle, chunked_stream.data() + frame_offset * 2,
                        chunk_frames, 2) != CORE_EQ_STATUS_OK) {
      return EXIT_FAILURE;
    }
    frame_offset += chunk_frames;
  }
  if (frame_offset != stream_frames) {
    std::cerr << "Streaming test chunks do not cover the entire signal\n";
    return EXIT_FAILURE;
  }
  for (std::size_t i = 0; i < whole_stream.size(); ++i) {
    if (!std::isfinite(whole_stream[i]) || !std::isfinite(chunked_stream[i]) ||
        std::abs(whole_stream[i] - chunked_stream[i]) > 1.0e-6f) {
      std::cerr << "PCM output changed across processing block boundaries\n";
      return EXIT_FAILURE;
    }
  }
  core_eq_destroy(whole_handle);
  core_eq_destroy(chunked_handle);

  std::cout << "CORE-EQ C ABI tests passed\n";
  return EXIT_SUCCESS;
}
