# CORE-EQ

CORE-EQ is a standalone, cross-platform modular audio processing project. It is intentionally separate from ZillaEQ.

## Product direction

- **Android:** pursue system-wide processing where device APIs permit it, with explicit compatibility reporting and a foreground service. Session attachment and playback capture have different limitations; neither will be advertised as universally supported.
- **iOS:** provide a reference player and AUv3 mastering effect. iOS does not allow third-party apps to intercept arbitrary audio from other apps system-wide.
- **UI:** Flutter hardware-inspired command deck with an animated spherical spectrum, precision labels, and flat machined control surfaces.
- **Visual reference:** [Music Player, Web/UX & UI by Artemii Lebedev](https://dribbble.com/shots/18450373-Music-Player-Web-UX-UI). The current sphere is procedural 2.5D canvas artwork with demo animation, not a live 3D engine or audio-reactive feed.
- **Typography:** use a geometric futuristic display face in the spirit of Nexus. The commercial Nexus font is not bundled; add the properly licensed font files before claiming an exact match.
- **DSP:** shared C++17 engine, exposed through a narrow C ABI/FFI boundary.
- **Privacy:** audio processing stays on-device; captured samples are not retained or transmitted.

## Phase 0 scope

1. Establish the Flutter app shell and command-deck visual system.
2. Implement and test a C++ DSP foundation: input/output gain, biquad parametric EQ, bypass, parameter smoothing, and response tests.
3. Define a real-time-safe parameter and metering interface.
4. Prove Android audio integration on actual hardware before claiming system-wide processing.
5. Establish an iOS player graph and AUv3 extension path.

## Important platform constraints

Android effect attachment varies by OEM, firmware, and playback session. Playback capture requires user consent and is blocked by apps that opt out; routing captured audio back to output can add significant latency.

iOS system-wide interception is not available to ordinary third-party apps. The iOS implementation is therefore player-centric and AUv3-based.

## Development status

The standalone repository contains the Flutter command deck, an animated orbital spectrum presentation, widget tests, a C++17 10-band parametric EQ foundation, a bounded single-producer/single-consumer parameter queue, smoothed input/output gain, and native DSP smoke tests. The visualizer animation, numeric meters, latency/CPU telemetry, preset controls, and bypass switch remain presentation-only; they are not connected to native processing or device audio. Android/iOS audio integration remains unimplemented and must be validated on real hardware.

## Planned structure

```
core-eq/
  lib/                 # Flutter presentation and state
  native/dsp/          # Shared C++17 DSP core
  android/             # Android service and audio integration
  ios/                 # AVAudioEngine host and AUv3 extension
  test/                # Flutter and DSP-facing tests
  docs/                # Architecture and platform compatibility
```

## Engineering rules

- No allocation, locks, logging, or platform-runtime calls on the DSP render thread.
- UI changes cross into DSP through bounded, real-time-safe parameter queues.
- Never claim latency, CPU, or audio quality targets without measurements.
- Validate DSP with automated tests and real-device audio tests.
