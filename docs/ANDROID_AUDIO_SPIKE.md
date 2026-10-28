# Android audio integration spike

## Scope

The first device-audio milestone is an in-app generated test tone processed by the native C++ DSP and played through Android `AudioTrack`. It is not microphone monitoring, not system-wide processing, and not a claim that other apps' audio can be captured.

## Required ownership and lifecycle

- Android owns the playback thread, `AudioTrack`, direct PCM buffer, and native engine handle.
- Allocate the direct PCM buffer and engine before playback starts. Reuse the buffer for every block.
- Generate a conservative-amplitude sine wave into interleaved float PCM, pass the same direct buffer to the native C ABI, then write the processed buffer to `AudioTrack`.
- Use `AudioTrack` float PCM only on supported Android API levels; surface initialization/write failures rather than silently falling back.
- Start and stop are idempotent. Stop must signal the render loop, stop/release `AudioTrack`, join the worker, and only then destroy the native engine.
- No PCM payloads travel through a Flutter platform channel. Platform messages contain only lifecycle/configuration and status values.
- Meter reads report the most recently processed block, not an invented UI animation.

## Acceptance gate

1. Build the Android library and app for CI-supported ABIs.
2. Start and stop repeatedly without a worker surviving stop or native use-after-free.
3. Process generated PCM with `core_eq_process` before writing it to `AudioTrack`.
4. Handle native library, engine, audio-track initialization, and write errors visibly.
5. Keep the UI disconnected until the playback worker reports running; never label the generated test tone as microphone or system audio.
6. Verify on a physical Android device and record Android version, output route, sample rate, and channel count before calling the path device-validated.

## Real-time constraints

The audio worker must reuse preallocated native/direct memory. Do not log, call Flutter, access the filesystem/network, allocate per block, or invoke platform APIs from inside the C++ processing function. This spike is a generated-tone playback proof only; microphone capture and feedback-sensitive loopback are a separate milestone.
