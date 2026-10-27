#pragma once
#include <array>
#include <cstddef>

namespace core_eq {

struct BiquadCoefficients {
  float b0{1.0f}, b1{0.0f}, b2{0.0f};
  float a0{1.0f}, a1{0.0f}, a2{0.0f};
};

class Biquad {
 public:
  void set_peaking(float frequency_hz, float q, float gain_db, float sample_rate) noexcept;
  void set_coefficients(const BiquadCoefficients& coefficients) noexcept;
  void reset() noexcept;
  float process(float input) noexcept;
 private:
  BiquadCoefficients c_{};
  float x1_{0}, x2_{0}, y1_{0}, y2_{0};
};

class ParametricEq10 {
 public:
  static constexpr std::size_t kBands = 10;
  void configure_band(std::size_t band, float frequency_hz, float q, float gain_db, float sample_rate) noexcept;
  void set_input_gain_db(float gain_db) noexcept;
  void set_output_gain_db(float gain_db) noexcept;
  void set_bypassed(bool bypassed) noexcept;
  void reset() noexcept;
  void process(float* interleaved, std::size_t frames, std::size_t channels) noexcept;
 private:
  std::array<Biquad, kBands> left_{};
  std::array<Biquad, kBands> right_{};
  float input_gain_{1.0f};
  float output_gain_{1.0f};
  bool bypassed_{false};
};

}  // namespace core_eq
