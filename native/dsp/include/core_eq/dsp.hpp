#pragma once
#include <array>
#include <atomic>
#include <cstddef>
#include <cstdint>

namespace core_eq {

struct BiquadCoefficients {
  float b0{1.0f}, b1{0.0f}, b2{0.0f};
  float a0{1.0f}, a1{0.0f}, a2{0.0f};
};

BiquadCoefficients design_peaking(float frequency_hz, float q, float gain_db, float sample_rate) noexcept;

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

enum class ParameterType : std::uint8_t { kInputGainDb, kOutputGainDb, kBypass, kBandCoefficients, kReset };
struct ParameterEvent {
  ParameterType type{ParameterType::kInputGainDb};
  std::uint8_t band{0};
  float value{0.0f};
  BiquadCoefficients coefficients{};
};

// Single-producer/single-consumer queue. One slot remains empty to distinguish full from empty.
template <typename T, std::size_t Capacity>
class SpscQueue {
  static_assert(Capacity >= 2, "SPSC queue needs at least two slots");
 public:
  bool try_push(const T& value) noexcept {
    const auto head = head_.load(std::memory_order_relaxed);
    const auto next = (head + 1) % Capacity;
    if (next == tail_.load(std::memory_order_acquire)) return false;
    data_[head] = value;
    head_.store(next, std::memory_order_release);
    return true;
  }
  bool try_pop(T& value) noexcept {
    const auto tail = tail_.load(std::memory_order_relaxed);
    if (tail == head_.load(std::memory_order_acquire)) return false;
    value = data_[tail];
    tail_.store((tail + 1) % Capacity, std::memory_order_release);
    return true;
  }
 private:
  std::array<T, Capacity> data_{};
  alignas(64) std::atomic<std::size_t> head_{0};
  alignas(64) std::atomic<std::size_t> tail_{0};
};

class ParametricEq10 {
 public:
  static constexpr std::size_t kBands = 10;
  bool enqueue(const ParameterEvent& event) noexcept;
  void configure_band(std::size_t band, float frequency_hz, float q, float gain_db, float sample_rate) noexcept;
  void set_input_gain_db(float gain_db) noexcept;
  void set_output_gain_db(float gain_db) noexcept;
  void set_bypassed(bool bypassed) noexcept;
  void reset() noexcept;
  void process(float* interleaved, std::size_t frames, std::size_t channels) noexcept;
  float peak_level() const noexcept { return peak_level_.load(std::memory_order_relaxed); }
 private:
  void consume_events() noexcept;
  std::array<Biquad, kBands> left_{};
  std::array<Biquad, kBands> right_{};
  SpscQueue<ParameterEvent, 128> events_{};
  float input_gain_{1.0f}, target_input_gain_{1.0f};
  float output_gain_{1.0f}, target_output_gain_{1.0f};
  float smoothing_coefficient_{0.002f};
  bool bypassed_{false};
  std::atomic<float> peak_level_{0.0f};
};

}  // namespace core_eq
