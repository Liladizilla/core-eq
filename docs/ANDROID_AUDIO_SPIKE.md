# Android audio integration

## Product target

CORE-EQ is an audio effects control surface intended to run beside the user's existing music player. It is not a music player. The app must distinguish three separate Android paths:

1. **OEM global output effects (session 0):** Android's `Equalizer(0, 0)` and `BassBoost(0, 0)` may attach to the global output mix on some devices. This is an optional capability, not a guaranteed third-party API. OEM implementations can reject creation, ignore changes on a route, or apply effects inconsistently.
2. **App-owned native DSP:** the C++ DSP processes CORE-EQ's generated diagnostic tone and any future audio rendered by CORE-EQ itself. It does not process Spotify or arbitrary external-app streams.
3. **Per-session effects:** Android audio sessions belong to the app/player that created them. A third-party app cannot assume it can discover and attach to another app's private session.

## Global output effect implementation

- Probe session-0 Equalizer and BassBoost independently and report their availability/errors.
- Read back the enabled state, supported band count/range, band center frequencies, current band levels, BassBoost enabled state, strength support and current strength.
- Map the ten CORE-EQ frequency targets to the nearest hardware bands exposed by the OEM effect. Some hardware effects expose fewer than ten bands, so multiple CORE-EQ controls can map to the same physical band.
- Read back actual accepted values after commands. Do not display requested slider values as applied values when the hardware clamps or rejects them.
- Listen for Android output-device additions/removals and report wired, Bluetooth, USB, speaker and other output routes.
- Route detection is not proof that a global effect is applied to that route. The user must compare external-player audio with the effect enabled and disabled.

## Generated-tone diagnostic path

The generated test tone is an in-app diagnostic processed by the native C++ DSP and played through Android `AudioTrack`. It is not microphone monitoring, not system-wide processing, and not evidence that another app's audio is being modified.

- Android owns the playback thread, `AudioTrack`, direct PCM buffer, and native engine handle.
- Allocate the direct PCM buffer and engine before playback starts. Reuse the buffer for every block.
- Generate a conservative-amplitude sine wave into interleaved float PCM, pass the same direct buffer to the native C ABI, then write the processed buffer to `AudioTrack`.
- Start and stop are idempotent. Stop must signal the render loop, stop/release `AudioTrack`, join the worker, and only then destroy the native engine.
- No PCM payloads travel through a Flutter platform channel. Platform messages contain only lifecycle/configuration and status values.
- Meter reads report the most recently processed block, not an invented UI animation.

## Acceptance gates

1. Build the Android library and app for CI-supported ABIs.
2. Run native DSP unit tests and Flutter tests/analyzer.
3. Start and stop the generated tone repeatedly without a surviving worker or native use-after-free.
4. Handle native library, engine, audio-track initialization, and write errors visibly.
5. Test session-0 capability creation on real hardware and record the reported support/error.
6. With Bluetooth headphones connected, play audio in Spotify or another external app and compare the same segment with global EQ/BassBoost enabled and disabled.
7. Repeat on phone speaker and wired headphones if available. Record Android version, device model, route, headphone model, effect availability, and audible result.
8. Do not describe the app as system-wide or device-validated unless the actual external-player test succeeds on the target device.

## Real-time constraints

The audio worker must reuse preallocated native/direct memory. Do not log, call Flutter, access the filesystem/network, allocate per block, or invoke platform APIs from inside the C++ processing function. The generated-tone path and global OEM-effect path are separate; success in one does not prove success in the other.

## Known platform limit

Android does not provide ordinary third-party applications a guaranteed, unrestricted API to inject custom arbitrary DSP into every other app's audio stream. If session-0 effects are unavailable or ineffective on the target phone, a truly universal Wavelet-style custom DSP requires a different integration model, such as OEM/system privileges or device-specific integration. CORE-EQ must report that limitation rather than pretending the app-owned C++ chain is system-wide.
