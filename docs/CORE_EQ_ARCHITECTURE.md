# CORE-EQ Architecture Notes

## Current milestone: Phase 4 / Native control and meter bindings

The C++ DSP, C ABI, Dart FFI control surface, managed peak reads, and Android shared-library packaging are implemented and covered by CI. These milestones validate the processing API and library delivery, not live device audio. The next gate is a real in-app Android audio path with explicit lifecycle and route/error reporting.

CORE-EQ is an independent repository. ZillaEQ is not a dependency and will not receive CORE-EQ implementation changes.

## Android native packaging

Run `bash scripts/build_android_native.sh` after installing Flutter, Android SDK command-line tools, and an Android NDK. The script builds the shared C ABI library for `arm64-v8a`, `armeabi-v7a`, and `x86_64`, then places each `libcore_eq.so` in `android/app/src/main/jniLibs/<abi>/`. The CI workflow generates the Android runner first, builds the native libraries, verifies all three artifacts, and builds the APK.

The Dart `CoreEqNative.openDefault()` factory resolves library names for supported Flutter targets and checks ABI version 1. This Android packaging step does not initialize the engine from the UI or provide audio-device routing. The parameter queue remains single-producer/single-consumer: serialize control calls and process audio from one render thread.

### Prototype boundary
The Flutter screen is still a presentation prototype. Its EQ curve, meters, preset values, bypass state, latency labels, and DSP load labels are not connected to device audio. Keep UI PREVIEW, NOT MEASURED, and NOT CONNECTED indicators until those values are backed by native engine telemetry.

## Next integration gate: in-app Android audio

Do not start by claiming system-wide processing. First build a narrow, testable in-app path:

1. Add a platform-owned audio component with explicit `start` / `stop` lifecycle and visible permission/device errors.
2. Prove native processing with a deterministic generated PCM signal before enabling microphone loopback. The test signal must pass through `core_eq_process`, and its output peak must come from `core_eq_get_peak_level`.
3. Add real-time capture/playback only after the test-signal path is stable. Keep capture and playback buffers bounded, avoid feedback by default, and require an explicit user action before starting any microphone-to-output path.
4. Keep all platform calls outside the C++ render callback. Serialize parameter writes and stop/join processing before destroying the native session.
5. Show live-meter or connected status only while the processing path is actually running; show unavailable/error states otherwise.
6. Record device/API-level limitations. Do not imply arbitrary other-app audio is captured; Android support varies and playback capture requires consent and is not universal.

Acceptance checks for this gate:

- Start and stop repeatedly without leaking the engine or leaving audio callbacks active.
- Generated test PCM is measurably processed by the native engine, with peak readings matching the processed block.
- Invalid device/session states are surfaced instead of silently falling back to an idle animation.
- No PCM is sent through Flutter method channels or retained/transmitted.
- Device-level checks document Android version, route, sample rate, channel count, and buffer size.

## Target architecture

- Flutter / Dart: presentation, gestures, preset editing and serialization.
- C++17 DSP core: sample processing, parameter smoothing, 10-band EQ and native tests.
- Stable C ABI: opaque engine handle, status codes, parameter events and block processing.
- Dart FFI: a thin typed wrapper around the C ABI. PCM remains in native memory; do not send PCM through Flutter method channels.
- Android Kotlin/JNI: native effect integration, session discovery, foreground service and route state.
- iOS Swift/Objective-C++: in-app player graph and AUv3 extension. No system-wide processing of unrelated apps is promised on iOS.

## Phase sequence

1. Command Deck UI and honest prototype status.
2. Standalone C++ DSP with bounded parameter queue and thread-safety contract.
3. C ABI and native shared-library target with lifecycle, processing, parameter validation and ABI tests.
4. Dart FFI adapter and platform library packaging; verify Dart control changes reach the native engine.
5. Android audio integration experiments with native test playback and device compatibility reporting.
6. iOS in-app player/AUv3, followed by advanced modules gated by tests and performance.

## C ABI contract

- The ABI version function reports the major version; incompatible signatures require a version change.
- Engine creation returns an opaque handle or null on allocation failure. Every successful create must be paired with destroy.
- Functions return explicit status codes for invalid arguments and full parameter queues. Callers must not assume an update was applied if a non-OK status is returned.
- The parameter queue is single-producer/single-consumer. Serialize control calls from multiple producer threads and call process from one render thread only.
- Audio buffers are interleaved floating-point PCM with one or two channels. The caller owns buffer memory for the duration of the call.
- The C ABI does not itself provide device audio routing, permission handling, or system-wide audio capture. Those require platform-specific work.

## Real-time safety contract

The render callback performs no heap allocation, blocking locks, filesystem/network work, logging, or Flutter/Java/Swift calls. UI changes are delivered as bounded parameter events and smoothed in the audio thread. Gain conversion and coefficient design happen on the producer side; the render callback consumes prepared events. The queue is single-producer/single-consumer, so callers must serialize producers and treat a full queue as a rejected update. Graph reconfiguration occurs off-thread and swaps immutable graph snapshots at safe block boundaries.

## Platform constraints

Android output effects and session attachment vary by OS version, OEM and audio route. Playback capture is not a universal fallback: it requires user consent, adds latency and cannot capture sources that disallow it. iOS public APIs do not allow arbitrary third-party processing of another app's system output; the supported product is an in-app reference player and AUv3 effect.

## Definition of done

- [ ] C++ DSP unit tests pass.
- [ ] C ABI validation and processing tests pass.
- [ ] Flutter analyze and widget tests pass.
- [ ] Dart FFI wrapper uses typed bindings and has no PCM copies through platform channels.
- [ ] UI distinguishes prototype state from live native engine telemetry.
- [ ] Android/iOS integration claims are made only after device tests.
