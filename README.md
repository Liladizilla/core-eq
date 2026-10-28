# CORE-EQ

CORE-EQ is a standalone, cross-platform modular audio processing project. It is intentionally separate from ZillaEQ.

## Product direction

- **Android:** pursue system-wide processing where device APIs permit it, with explicit compatibility reporting and a foreground service. Session attachment and playback capture have different limitations; neither will be advertised as universally supported.
- **iOS:** provide a reference player and AUv3 mastering effect. iOS does not allow third-party apps to intercept arbitrary audio from other apps system-wide.
- **UI:** Flutter hardware-inspired command deck with an animated spherical spectrum, precision labels, and flat machined control surfaces.
- **Visual reference:** [Music Player, Web/UX & UI by Artemii Lebedev](https://dribbble.com/shots/18450373-Music-Player-Web-UX-UI). The sphere is procedural 2.5D canvas artwork; do not describe it as a live 3D engine.
- **Typography:** use a geometric futuristic display face in the spirit of Nexus. The commercial Nexus font is not bundled; add properly licensed font files before claiming an exact match.
- **DSP:** shared C++17 engine, exposed through a narrow C ABI/FFI boundary.
- **Privacy:** audio processing stays on-device; captured samples are not retained or transmitted.

## Current implementation status

The Flutter app includes a dark command-deck interface, an animated spectrum presentation, presets and controls, plus a native Android generated-test-tone path. On that generated PCM path, the Android plugin currently wires EQ band gains, bass boost through effective band gains, bypass, output gain, an output peak limiter, and optional mid/side stereo widening. The header reports whether the generated test tone is active, and the visualizer receives native DSP peak measurements.

**Important scope limit:** this is not yet a system-wide equalizer. It does not intercept audio from Spotify, browsers, or other apps, and it does not process microphone input. The generated tone is a test signal, not a reference music player. Actual playback, stereo effect quality, and stability have not been verified on physical Android hardware. Do not claim device-level behavior until it has been tested there.

The repository also contains a C++17 10-band parametric EQ foundation, native DSP smoke tests, Flutter tests, and Android library packaging work for arm64-v8a, armeabi-v7a, and x86_64. The Dart FFI loader can resolve packaged library names and validate ABI version 1. Android system-wide audio integration and the iOS player/AUv3 integration remain unfinished.

## Phase 0 priorities

1. Keep the Flutter command deck and its controls consistent with the actual processing implementation.
2. Test the shared C++ DSP engine with response, clipping, parameter-boundary, and regression tests.
3. Define a real-time-safe parameter and metering interface.
4. Build and listen to the Android generated-tone path on physical hardware before expanding claims.
5. Investigate Android audio-effect attachment and compatibility without promising universal system-wide access.
6. Establish an iOS player graph and AUv3 extension path.

## Important platform constraints

Android effect attachment varies by OEM, firmware, and playback session. Playback capture requires user consent, is blocked by apps that opt out, and routing captured audio back to output can add significant latency.

iOS system-wide interception is not available to ordinary third-party apps. The iOS implementation is therefore player-centric and AUv3-based.

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
