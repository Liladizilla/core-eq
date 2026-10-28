#include "core_eq/dsp.hpp"

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <iostream>
#include <vector>

namespace {
constexpr float kSampleRate = 48000.0f;
constexpr float kPi = 3.14159265358979323846f;

double rms_after_warmup(float frequency_hz, float gain_db, std::size_t band) {
  core_eq::ParametricEq10 eq;
  eq.configure_band(band, frequency_hz, 1.0f, gain_db, kSampleRate);

  // Two seconds lets parameter events settle and excludes filter startup.
  constexpr std::size_t frames = 96000;
  std::vector<float> pcm(frames);
  for (std::size_t i = 0; i < frames; ++i) {
    pcm[i] = 0.2f * std::sin(2.0f * kPi * frequency_hz *
                            static_cast<float>(i) / kSampleRate);
  }
  eq.process(pcm.data(), pcm.size(), 1);

  double sum = 0.0;
  std::size_t count = 0;
  for (std::size_t i = frames / 2; i < frames; ++i) {
    sum += static_cast<double>(pcm[i]) * pcm[i];
    ++count;
  }
  return std::sqrt(sum / static_cast<double>(count));
}
}  // namespace

int main() {
  // Each selected frequency targets the corresponding low-frequency band.
  // A +9 dB peak should measurably increase steady-state RMS over flat.
  struct Case { std::size_t band; float frequency; };
  constexpr Case cases[] = {
      {0, 32.0f}, {1, 64.0f}, {2, 125.0f}, {3, 250.0f},
      {4, 500.0f}, {5, 1000.0f}, {6, 2000.0f}, {7, 4000.0f},
      {8, 8000.0f}, {9, 16000.0f},
  };

  for (const auto& test : cases) {
    const double flat = rms_after_warmup(test.frequency, 0.0f, test.band);
    const double boosted = rms_after_warmup(test.frequency, 9.0f, test.band);
    if (!(std::isfinite(flat) && std::isfinite(boosted) && flat > 0.01 &&
          boosted > flat * 1.15)) {
      std::cerr << "Frequency response failed at " << test.frequency
                << " Hz: flat RMS=" << flat << ", boosted RMS=" << boosted
                << '\n';
      return EXIT_FAILURE;
    }
  }

  // Bypass should preserve the input samples exactly, even when a band is set.
  core_eq::ParametricEq10 bypass;
  bypass.configure_band(1, 64.0f, 1.0f, 12.0f, kSampleRate);
  bypass.set_bypassed(true);
  std::vector<float> signal(4096);
  for (std::size_t i = 0; i < signal.size(); ++i) {
    signal[i] = 0.2f * std::sin(2.0f * kPi * 64.0f *
                               static_cast<float>(i) / kSampleRate);
  }
  const auto original = signal;
  bypass.process(signal.data(), signal.size(), 1);
  if (signal != original) {
    std::cerr << "Bypass changed samples with EQ enabled\n";
    return EXIT_FAILURE;
  }

  std::cout << "CORE-EQ frequency response tests passed\n";
  return EXIT_SUCCESS;
}
