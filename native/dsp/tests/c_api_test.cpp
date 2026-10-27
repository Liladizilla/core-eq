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
  if (core_eq_process(handle, nullptr, 1, 2) != CORE_EQ_STATUS_INVALID_ARGUMENT) return EXIT_FAILURE;
  if (core_eq_process(handle, nullptr, 0, 2) != CORE_EQ_STATUS_OK) return EXIT_FAILURE;

  if (core_eq_set_bypassed(handle, 1) != CORE_EQ_STATUS_OK) return EXIT_FAILURE;
  std::vector<float> samples(64, 0.25f);
  if (core_eq_process(handle, samples.data(), 32, 2) != CORE_EQ_STATUS_OK) return EXIT_FAILURE;
  for (float sample : samples) if (sample != 0.25f) return EXIT_FAILURE;

  if (core_eq_set_bypassed(handle, 0) != CORE_EQ_STATUS_OK) return EXIT_FAILURE;
  if (core_eq_set_input_gain_db(handle, 3.0f) != CORE_EQ_STATUS_OK) return EXIT_FAILURE;
  if (core_eq_set_output_gain_db(handle, -2.0f) != CORE_EQ_STATUS_OK) return EXIT_FAILURE;
  if (core_eq_configure_band(handle, 0, 1000.0f, 1.0f, 4.0f, 48000.0f) != CORE_EQ_STATUS_OK) return EXIT_FAILURE;
  if (core_eq_reset(handle) != CORE_EQ_STATUS_OK) return EXIT_FAILURE;

  std::vector<float> audio(256, 0.1f);
  if (core_eq_process(handle, audio.data(), 256, 1) != CORE_EQ_STATUS_OK) return EXIT_FAILURE;
  for (float sample : audio) if (!std::isfinite(sample) || std::abs(sample) > 1.0f) return EXIT_FAILURE;

  core_eq_destroy(handle);
  std::cout << "CORE-EQ C ABI tests passed\n";
  return EXIT_SUCCESS;
}
