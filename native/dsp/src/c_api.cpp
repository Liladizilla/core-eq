#include "core_eq/c_api.h"
#include "core_eq/dsp.hpp"

#include <cmath>
#include <new>

struct core_eq_handle {
  core_eq::ParametricEq10 processor;
};

namespace {
core_eq_status enqueue_event(core_eq_handle* handle, const core_eq::ParameterEvent& event) noexcept {
  if (handle == nullptr) return CORE_EQ_STATUS_INVALID_ARGUMENT;
  return handle->processor.enqueue(event) ? CORE_EQ_STATUS_OK : CORE_EQ_STATUS_QUEUE_FULL;
}
}

extern "C" {

uint32_t core_eq_abi_version(void) { return 1U; }

core_eq_handle* core_eq_create(void) {
  return new (std::nothrow) core_eq_handle{};
}

void core_eq_destroy(core_eq_handle* handle) { delete handle; }

core_eq_status core_eq_set_input_gain_db(core_eq_handle* handle, float gain_db) {
  if (!std::isfinite(gain_db)) return CORE_EQ_STATUS_INVALID_ARGUMENT;
  core_eq::ParameterEvent event;
  event.type = core_eq::ParameterType::kInputGainDb;
  event.value = gain_db;
  return enqueue_event(handle, event);
}

core_eq_status core_eq_set_output_gain_db(core_eq_handle* handle, float gain_db) {
  if (!std::isfinite(gain_db)) return CORE_EQ_STATUS_INVALID_ARGUMENT;
  core_eq::ParameterEvent event;
  event.type = core_eq::ParameterType::kOutputGainDb;
  event.value = gain_db;
  return enqueue_event(handle, event);
}

core_eq_status core_eq_set_bypassed(core_eq_handle* handle, int bypassed) {
  if (bypassed != 0 && bypassed != 1) return CORE_EQ_STATUS_INVALID_ARGUMENT;
  core_eq::ParameterEvent event;
  event.type = core_eq::ParameterType::kBypass;
  event.value = bypassed == 1 ? 1.0f : 0.0f;
  return enqueue_event(handle, event);
}

core_eq_status core_eq_configure_band(core_eq_handle* handle, uint32_t band,
                                      float frequency_hz, float q,
                                      float gain_db, float sample_rate_hz) {
  if (handle == nullptr || band >= core_eq::ParametricEq10::kBands ||
      !std::isfinite(frequency_hz) || !std::isfinite(q) || !std::isfinite(gain_db) ||
      !std::isfinite(sample_rate_hz) || sample_rate_hz <= 0.0f || q <= 0.0f) {
    return CORE_EQ_STATUS_INVALID_ARGUMENT;
  }
  core_eq::ParameterEvent event;
  event.type = core_eq::ParameterType::kBandCoefficients;
  event.band = static_cast<std::uint8_t>(band);
  event.coefficients = core_eq::design_peaking(frequency_hz, q, gain_db, sample_rate_hz);
  const auto& coefficients = event.coefficients;
  if (!std::isfinite(coefficients.a0) || std::abs(coefficients.a0) < 1.0e-12f ||
      !std::isfinite(coefficients.a1) || !std::isfinite(coefficients.a2) ||
      !std::isfinite(coefficients.b0) || !std::isfinite(coefficients.b1) ||
      !std::isfinite(coefficients.b2)) {
    return CORE_EQ_STATUS_INVALID_ARGUMENT;
  }
  return enqueue_event(handle, event);
}

core_eq_status core_eq_reset(core_eq_handle* handle) {
  core_eq::ParameterEvent event;
  event.type = core_eq::ParameterType::kReset;
  return enqueue_event(handle, event);
}

core_eq_status core_eq_process(core_eq_handle* handle, float* interleaved,
                               size_t frames, size_t channels) {
  if (handle == nullptr || (frames > 0 && interleaved == nullptr) ||
      channels == 0 || channels > 2) {
    return CORE_EQ_STATUS_INVALID_ARGUMENT;
  }
  handle->processor.process(interleaved, frames, channels);
  return CORE_EQ_STATUS_OK;
}

}
