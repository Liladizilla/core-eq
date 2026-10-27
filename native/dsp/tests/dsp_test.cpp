#include "core_eq/dsp.hpp"
#include <cmath>
#include <cstdlib>
#include <iostream>
#include <vector>

int main() {
  constexpr float sr = 48000.0f;
  core_eq::Biquad filter;
  filter.set_peaking(1000.0f, 1.0f, 9.0f, sr);
  std::vector<float> signal(48000);
  for (std::size_t i = 0; i < signal.size(); ++i) signal[i] = 0.2f * std::sin(2.0f * 3.14159265358979323846f * 1000.0f * i / sr);
  double in = 0.0, out = 0.0;
  for (float x : signal) in += x * x;
  for (float& x : signal) x = filter.process(x);
  for (float x : signal) out += x * x;
  if (!(std::isfinite(out) && out > in)) { std::cerr << "EQ gain test failed\n"; return EXIT_FAILURE; }
  core_eq::ParametricEq10 eq;
  eq.configure_band(0, 1000.0f, 1.0f, 6.0f, sr);
  std::vector<float> stereo(512 * 2, 0.1f);
  eq.process(stereo.data(), 512, 2);
  for (float x : stereo) if (!std::isfinite(x) || std::abs(x) > 1.0f) return EXIT_FAILURE;
  std::cout << "CORE-EQ DSP smoke tests passed\n";
  return EXIT_SUCCESS;
}
