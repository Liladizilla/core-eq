#include "core_eq/dsp.hpp"
#include <cmath>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <vector>

int main() {
  constexpr float sr = 48000.0f;

  // Very low positive rates make the old fixed 1 Hz lower clamp exceed the
  // 0.49 * sample-rate upper clamp, violating std::clamp's precondition.
  const auto low_rate = core_eq::design_peaking(1000.0f, 1.0f, 6.0f, 2.0f);
  for (float coefficient : {low_rate.b0, low_rate.b1, low_rate.b2,
                            low_rate.a0, low_rate.a1, low_rate.a2}) {
    if (!std::isfinite(coefficient)) {
      std::cerr << "Low-sample-rate coefficient design failed\n";
      return EXIT_FAILURE;
    }
  }
  if (std::abs(low_rate.a0) < 1.0e-12f) {
    std::cerr << "Low-sample-rate denominator is invalid\n";
    return EXIT_FAILURE;
  }
  core_eq::Biquad filter;
  filter.set_peaking(1000.0f, 1.0f, 9.0f, sr);
  std::vector<float> signal(48000);
  for (std::size_t i = 0; i < signal.size(); ++i)
    signal[i] = 0.2f * std::sin(2.0f * 3.14159265358979323846f * 1000.0f * i / sr);
  double in = 0.0, out = 0.0;
  for (float x : signal) in += x * x;
  for (float& x : signal) x = filter.process(x);
  for (float x : signal) out += x * x;
  if (!(std::isfinite(out) && out > in)) {
    std::cerr << "EQ gain test failed\n"; return EXIT_FAILURE;
  }

  core_eq::SpscQueue<int, 4> queue;
  int value = 0;
  if (!queue.try_push(11) || !queue.try_push(22) || !queue.try_push(33) || queue.try_push(44)) {
    std::cerr << "SPSC queue capacity test failed\n"; return EXIT_FAILURE;
  }
  if (!queue.try_pop(value) || value != 11 || !queue.try_pop(value) || value != 22 ||
      !queue.try_pop(value) || value != 33 || queue.try_pop(value)) {
    std::cerr << "SPSC queue ordering test failed\n"; return EXIT_FAILURE;
  }

  core_eq::ParametricEq10 eq;
  core_eq::ParameterEvent invalid_band;
  invalid_band.type = core_eq::ParameterType::kBandCoefficients;
  invalid_band.band = 10;
  if (eq.enqueue(invalid_band)) {
    std::cerr << "Out-of-range EQ band was accepted\n"; return EXIT_FAILURE;
  }
  core_eq::ParameterEvent invalid_gain;
  invalid_gain.type = core_eq::ParameterType::kOutputGainDb;
  invalid_gain.value = std::numeric_limits<float>::quiet_NaN();
  if (eq.enqueue(invalid_gain)) {
    std::cerr << "Non-finite gain was accepted\n"; return EXIT_FAILURE;
  }

  core_eq::ParameterEvent band;
  band.type = core_eq::ParameterType::kBandCoefficients;
  band.band = 0;
  band.coefficients = core_eq::design_peaking(1000.0f, 1.0f, 6.0f, sr);
  if (!eq.enqueue(band)) return EXIT_FAILURE;
  core_eq::ParameterEvent gain;
  gain.type = core_eq::ParameterType::kOutputGainDb;
  gain.value = 6.0f;
  if (!eq.enqueue(gain)) return EXIT_FAILURE;
  eq.set_input_gain_db(3.0f);
  eq.configure_band(1, 250.0f, 0.8f, -3.0f, sr);
  std::vector<float> stereo(512 * 2, 0.1f);
  eq.process(stereo.data(), 512, 2);
  for (float x : stereo) if (!std::isfinite(x) || std::abs(x) > 1.0f) return EXIT_FAILURE;

  core_eq::ParametricEq10 bypass;
  bypass.set_bypassed(true);
  std::vector<float> setter_bypass(32, 0.25f);
  bypass.process(setter_bypass.data(), setter_bypass.size(), 1);
  for (float x : setter_bypass) if (x != 0.25f) return EXIT_FAILURE;

  core_eq::ParametricEq10 event_bypass;
  core_eq::ParameterEvent mute;
  mute.type = core_eq::ParameterType::kBypass;
  mute.value = 1.0f;
  if (!event_bypass.enqueue(mute)) return EXIT_FAILURE;
  std::vector<float> unchanged(32, 0.25f);
  event_bypass.process(unchanged.data(), unchanged.size(), 1);
  for (float x : unchanged) if (x != 0.25f) return EXIT_FAILURE;

  std::cout << "CORE-EQ DSP smoke tests passed\n";
  return EXIT_SUCCESS;
}
