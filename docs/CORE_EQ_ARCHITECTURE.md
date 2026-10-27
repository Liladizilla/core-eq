# CORE-EQ Architecture Notes

## Current milestone: Phase 2 / C ABI bridge

CORE-EQ is an independent repository. ZillaEQ is not a dependency and will not receive CORE-EQ implementation changes.

### Prototype boundary
The Flutter screen is still a presentation prototype. Its EQ curve, meters, preset values, bypass state, latency labels, and DSP load labels are not connected to device audio. Keep UI PREVIEW, NOT MEASURED, and NOT CONNECTED indicators until those values are backed by native engine telemetry.

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
