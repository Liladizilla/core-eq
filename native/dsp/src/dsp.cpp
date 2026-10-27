#include "core_eq/dsp.hpp"
#include <algorithm>
#include <cmath>

namespace core_eq {
namespace {
constexpr float kPi = 3.14159265358979323846f;
float db_to_gain(float db) noexcept { return std::pow(10.0f, db / 20.0f); }
}

BiquadCoefficients design_peaking(float f, float q, float gain_db, float sr) noexcept {
  BiquadCoefficients c{};
  if (!(sr > 0.0f) || !std::isfinite(sr) || !(q > 0.0f) || !std::isfinite(f) || !std::isfinite(q) || !std::isfinite(gain_db)) return c;
  f = std::clamp(f, 1.0f, sr * 0.49f);
  const float A = std::pow(10.0f, gain_db / 40.0f);
  const float w = 2.0f * kPi * f / sr;
  const float alpha = std::sin(w) / (2.0f * q);
  const float cw = std::cos(w);
  c.b0 = 1.0f + alpha * A; c.b1 = -2.0f * cw; c.b2 = 1.0f - alpha * A;
  c.a0 = 1.0f + alpha / A; c.a1 = -2.0f * cw; c.a2 = 1.0f - alpha / A;
  return c;
}

void Biquad::set_peaking(float f, float q, float gain_db, float sr) noexcept { set_coefficients(design_peaking(f, q, gain_db, sr)); }
void Biquad::set_coefficients(const BiquadCoefficients& c) noexcept { c_ = c; }
void Biquad::reset() noexcept { x1_ = x2_ = y1_ = y2_ = 0.0f; }
float Biquad::process(float x) noexcept {
  const float y = (c_.b0 / c_.a0) * x + (c_.b1 / c_.a0) * x1_ + (c_.b2 / c_.a0) * x2_ - (c_.a1 / c_.a0) * y1_ - (c_.a2 / c_.a0) * y2_;
  x2_ = x1_; x1_ = x; y2_ = y1_; y1_ = std::isfinite(y) ? y : 0.0f;
  return y1_;
}

bool ParametricEq10::enqueue(const ParameterEvent& event) noexcept {
  ParameterEvent prepared = event;
  switch (prepared.type) {
    case ParameterType::kInputGainDb:
      if (!std::isfinite(prepared.value)) return false;
      prepared.value = db_to_gain(std::clamp(prepared.value, -24.0f, 24.0f));
      break;
    case ParameterType::kOutputGainDb:
      if (!std::isfinite(prepared.value)) return false;
      prepared.value = db_to_gain(std::clamp(prepared.value, -24.0f, 12.0f));
      break;
    case ParameterType::kBandCoefficients: {
      if (prepared.band >= kBands) return false;
      const auto& c = prepared.coefficients;
      if (!std::isfinite(c.a0) || std::abs(c.a0) < 1.0e-12f ||
          !std::isfinite(c.a1) || !std::isfinite(c.a2) ||
          !std::isfinite(c.b0) || !std::isfinite(c.b1) || !std::isfinite(c.b2)) return false;
      break;
    }
    case ParameterType::kBypass:
    case ParameterType::kReset:
      break;
  }
  return events_.try_push(prepared);
}
void ParametricEq10::consume_events() noexcept {
  ParameterEvent event;
  while (events_.try_pop(event)) {
    switch (event.type) {
      case ParameterType::kInputGainDb:
        target_input_gain_ = event.value; break;
      case ParameterType::kOutputGainDb:
        target_output_gain_ = event.value; break;
      case ParameterType::kBypass:
        bypassed_ = event.value >= 0.5f; break;
      case ParameterType::kBandCoefficients:
        left_[event.band].set_coefficients(event.coefficients);
        right_[event.band].set_coefficients(event.coefficients); break;
      case ParameterType::kReset:
        for (auto& filter : left_) filter.reset();
        for (auto& filter : right_) filter.reset();
        input_gain_ = target_input_gain_;
        output_gain_ = target_output_gain_;
        break;
    }
  }
}
void ParametricEq10::configure_band(std::size_t band, float f, float q, float db, float sr) noexcept {
  if (band >= kBands) return;
  ParameterEvent event;
  event.type = ParameterType::kBandCoefficients;
  event.band = static_cast<std::uint8_t>(band);
  event.coefficients = design_peaking(f, q, db, sr);
  (void)enqueue(event);
}
void ParametricEq10::set_input_gain_db(float db) noexcept {
  ParameterEvent event; event.type = ParameterType::kInputGainDb; event.value = db;
  (void)enqueue(event);
}
void ParametricEq10::set_output_gain_db(float db) noexcept {
  ParameterEvent event; event.type = ParameterType::kOutputGainDb; event.value = db;
  (void)enqueue(event);
}
void ParametricEq10::set_bypassed(bool b) noexcept {
  ParameterEvent event; event.type = ParameterType::kBypass; event.value = b ? 1.0f : 0.0f;
  (void)enqueue(event);
}
void ParametricEq10::reset() noexcept {
  ParameterEvent event; event.type = ParameterType::kReset;
  (void)enqueue(event);
}
void ParametricEq10::process(float* data, std::size_t frames, std::size_t channels) noexcept {
  if (!data || channels == 0 || channels > 2) return;
  consume_events();
  if (bypassed_) return;
  for (std::size_t frame = 0; frame < frames; ++frame) {
    input_gain_ += smoothing_coefficient_ * (target_input_gain_ - input_gain_);
    output_gain_ += smoothing_coefficient_ * (target_output_gain_ - output_gain_);
    for (std::size_t ch = 0; ch < channels; ++ch) {
      float s = data[frame * channels + ch] * input_gain_;
      auto& filters = ch == 0 ? left_ : right_;
      for (auto& filter : filters) s = filter.process(s);
      data[frame * channels + ch] = std::clamp(s * output_gain_, -1.0f, 1.0f);
    }
  }
}
}  // namespace core_eq
