# Headphone EQ diagnostic

## Field report (2026-10-28)

The owner tested with the generated test tone stopped, Bluetooth headphones connected, bypass changes unclear, and no noticeable bass-boost effect on music from another player.

## What the code currently proves

The Android plugin at `packages/core_eq_audio/android/src/main/kotlin/dev/coreeq/audio/CoreEqAudioPlugin.kt` creates its own `AudioTrack` and synthesizes a 440 Hz sine wave. Each block is passed to `nativeProcess` before being written to that track. The plugin explicitly states that it does not capture microphone or other-app audio. The Flutter audio facade also describes itself as generated-test-tone-only.

Therefore, the current repository does not contain a route that takes PCM from a separate music player and passes those samples through CORE-EQ's DSP. The owner's audible observation is real as a report, but it is not yet evidence that CORE-EQ processed the other app's signal. Possible explanations include Android/OEM audio effects, headphone app processing, a separate system equalizer, or an earlier test where the generated tone was still active.

## Why the existing 440 Hz test is weak for bass validation

A 440 Hz sine wave is not a useful direct check of the 32 Hz, 64 Hz, and 125 Hz controls. The existing tone panel is useful for verifying that Android output and the DSP worker run, but it is not a comprehensive frequency-response test.

## Next engineering work

1. Add selectable low-frequency test signals (for example 60 Hz, 100 Hz, and 440 Hz) and expose the selected frequency in status/UI.
2. Add native DSP response tests that feed steady sine waves at each EQ band's center frequency and compare RMS output with flat/bypass output after smoothing settles.
3. Keep the test tone labeled as an app-generated signal, separate from any claim about external-player processing.
4. Investigate any future cross-app path as a separate Android integration project, with explicit API/device limitations and a measurable capture/process/output route. Do not try to silently capture another app's audio.
5. For field verification, disable any OEM sound effects and headphone-app EQ, compare the same music segment at matched loudness, and test with CORE-EQ's generated tone stopped. Do not max every gain control; clipping protection can hide differences and high levels can damage hearing.

## Acceptance criteria for the tone feature

- Selected tone frequency is validated against a fixed safe list.
- Frequency selection persists across stop/start and is reflected in UI status.
- Tests demonstrate a measurable change when the matching EQ band is boosted and return to baseline in bypass.
- Existing default 440 Hz behavior remains the default.
- UI text makes clear that this test does not process Spotify or other apps.
