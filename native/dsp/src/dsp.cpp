#include "core_eq/dsp.hpp"
#include <algorithm>
#include <cmath>

namespace core_eq {
namespace {
constexpr float kPi = 3.14159265358979323846f;
float db_to_gain(float db) noexcept { return std::pow(10.0f, db / 20.0f); }
}

void Biquad::set_peaking(float f, float q, float gain_db, float sr) noexcept {
  if (!(sr > 0.0f) || !(q > 0.0f) || !std::isfinite(f) || !std::isfinite(q) || !std::isfinite(gain_db)) {
    c_ = {}; return;
  }
  f = std::clamp(f, 1.0f, sr * 0.49f);
  const float A = std::pow(10.0f, gain_db / 40.0f);
  const float w = 2.0f * kPi * f / sr;
  const float alpha = std::sin(w) / (2.0f * q);
  const float cw = std::cos(w);
  c_.b0 = 1.0f + alpha * A; c_.b1 = -2.0f * cw; c_.b2 = 1.0f - alpha * A;
  c_.a0 = 1.0f + alpha / A; c_.a1 = -2.0f * cw; c_.a2 = 1.0f - alpha / A;
}
void Biquad::set_coefficients(const BiquadCoefficients& c) noexcept { c_ = c; }
void Biquad::reset() noexcept { x1_ = x2_ = y1_ = y2_ = 0.0f; }
float Biquad::process(float x) noexcept {
  const float y = (c_.b0 / c_.a0) * x + (c_.b1 / c_.a0) * x1_ + (c_.b2 / c_.a0) * x2_ - (c_.a1 / c_.a0) * y1_ - (c_.a2 / c_.a0) * y2_;
  x2_ = x1_; x1_ = x; y2_ = y1_; y1_ = std::isfinite(y) ? y : 0.0f;
  return y1_;
}
void ParametricEq10::configure_band(std::size_t band, float f, float q, float db, float sr) noexcept {
  if (band >= kBands) return;
  left_[band].set_peaking(f, q, db, sr); right_[band].set_peaking(f, q, db, sr);
}
void ParametricEq10::set_input_gain_db(float db) noexcept { input_gain_ = db_to_gain(std::clamp(db, -24.0f, 24.0f)); }
void ParametricEq10::set_output_gain_db(float db) noexcept { output_gain_ = db_to_gain(std::clamp(db, -24.0f, 12.0f)); }
void ParametricEq10::set_bypassed(bool b) noexcept { bypassed_ = b; }
void ParametricEq10::reset() noexcept { for (auto& f : left_) f.reset(); for (auto& f : right_) f.reset(); }
void ParametricEq10::process(float* data, std::size_t frames, std::size_t channels) noexcept {
  if (!data || channels == 0 || channels > 2) return;
  if (bypassed_) return;
  for (std::size_t frame = 0; frame < frames; ++frame) {
    for (std::size_t ch = 0; ch < channels; ++ch) {
      float s = data[frame * channels + ch] * input_gain_;
      auto& filters = ch == 0 ? left_ : right_;
      for (auto& filter : filters) s = filter.process(s);
      data[frame * channels + ch] = std::clamp(s * output_gain_, -1.0f, 1.0f);
    }
  }
}
}  // namespace core_eq
