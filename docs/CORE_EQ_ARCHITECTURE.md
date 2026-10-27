# CORE-EQ Architecture Notes

## Current milestone: Phase 0 / Command Deck prototype

CORE-EQ is an independent repository. ZillaEQ is not a dependency and will not receive CORE-EQ implementation changes.

### Prototype boundary
The first UI milestone is a presentation and interaction prototype. Its EQ curve, meters, preset values, bypass state, latency labels, and DSP load labels are not connected to a real-time audio engine. The UI must continue to say UI PREVIEW, NOT MEASURED, and NOT CONNECTED until those values are backed by native engine telemetry.

## Target architecture

- Flutter / Dart: presentation, gestures, preset editing and serialization.
- C++17 DSP core: sample processing, parameter smoothing, metering and tests.
- Android Kotlin/JNI: native effect integration, session discovery, foreground service and route state.
- iOS Swift/Objective-C++: in-app player graph and AUv3 extension. No system-wide processing of unrelated apps is promised on iOS.
- Control bridge: parameter events and status only. Never send PCM through Flutter method channels.

## Phase sequence

1. Command Deck UI: responsive signal path, EQ visualization, master bypass control, preset chooser, A/B slot selector and honest engine status.
2. DSP foundation: standalone C++ tests, input/output gain, 10-band parametric EQ, lock-free parameter queue, smoothed parameter changes, bypass and limiter baseline.
3. Android integration: native test playback session and verification of available effect attachment on actual devices. Add foreground service and compatibility reporting.
4. Playback-capture experiment: API 29+, user-granted MediaProjection only, in-memory processing, visible capture status, and explicit latency warning. Respect source-app capture policy.
5. iOS player/AUv3: process audio owned by CORE-EQ and expose the shared DSP core to compatible AUv3 hosts.
6. Advanced modules: dynamic EQ, MBC, bass synthesis, width, AutoEQ data, convolution and analysis, each gated by tests and device performance.

## Real-time safety contract

The render callback performs no heap allocation, blocking locks, filesystem/network work, logging, or Flutter/Java/Swift calls. UI changes are delivered as bounded parameter events and smoothed in the audio thread. Public control setters enqueue events instead of mutating filter/gain state directly. Gain conversion and coefficient design happen on the producer side; the render callback consumes prepared gain values. The queue is single-producer/single-consumer, so callers must serialize producers and treat a full queue as a rejected update. Graph reconfiguration occurs off-thread and swaps immutable graph snapshots at safe block boundaries.

## Platform constraints

Android output effects and session attachment vary by OS version, OEM and audio route. Playback capture is not a universal fallback: it requires user consent, adds latency and cannot capture sources that disallow it. iOS public APIs do not allow arbitrary third-party processing of another app's system output; the supported product is an in-app reference player and AUv3 effect.

## Definition of done for the UI milestone

- [ ] Flutter screen is responsive in portrait and landscape/tablet layouts.
- [ ] Signal-flow modules can be selected.
- [ ] EQ graph responds to macro changes and preset selection.
- [ ] Bypass state is obvious but does not falsely claim to process system audio.
- [ ] Status distinguishes prototype UI from real engine telemetry.
- [ ] Flutter analyze and widget tests pass on the development machine.
