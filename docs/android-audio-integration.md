# Android audio integration: constraints and decision gates

## Current truth

CORE-EQ's Android audio plugin generates its own test tone, passes those samples through the native DSP, and writes the result to Android output. This proves a narrow DSP-to-output path only. It does not attach to Spotify, browsers, or arbitrary app playback, and it is not evidence of system-wide equalization.

Do not label the app a working system-wide equalizer until a supported integration path has been implemented and verified on real devices.

## Integration options

| Path | What it can do | Hard limits | Product role |
| --- | --- | --- | --- |
| In-app player using AudioTrack/AudioTrack-like output | CORE-EQ owns decoded PCM and can process every frame before output | Only audio played inside CORE-EQ; requires a player/decoder and routing work | Most reliable first production path |
| Android audio-effect/session attachment | May attach an effect to a compatible audio session on some device builds | Availability and behavior depend on Android version, OEM, effect implementation, session ownership, and whether the source app exposes a compatible session. Not a universal third-party system-wide hook | Optional capability, detected and reported at runtime; never assume availability |
| Playback capture via MediaProjection | Captures eligible playback after explicit user consent and can feed captured PCM to processing | Source apps can disallow capture; consent and foreground-service lifecycle apply; capture-to-output creates a loopback route with extra latency, resampling/buffering risks, and possible feedback | Experimental compatibility path only, not the default equalizer architecture |
| Root / privileged / OEM integration | May enable deeper system audio routing on supported builds | Requires privileges or platform integration ordinary Play-distributed apps do not have | Out of scope for the ordinary app build unless a separate privileged build is explicitly approved |
| iOS system-wide interception | Not available to ordinary third-party apps | iOS does not let an app intercept arbitrary other apps' output | iOS must remain player-centric and/or use an AUv3 effect |

## Current in-app player implementation

A Media3/ExoPlayer local-file path is now being added alongside the generated-tone diagnostic. It routes decoded stereo PCM16 at supported sample rates through the native C++ processor before Android output. The Flutter panel selects a local audio file and exposes play, pause, stop, seek, and status. EQ band, output gain, and bypass settings are forwarded to this player pipeline.

This is an in-app player, not a system-wide equalizer. PCM formats outside the processor's supported range may bypass the custom processor or fail to play through this EQ path; validate common MP3/AAC/FLAC/WAV files and report unsupported formats clearly before advertising broad codec compatibility. Bluetooth and physical-device output still require hardware testing.

## Recommended sequence

1. **Keep the test-tone path honest.** Keep the UI disclosure that it is a generated signal and does not process other apps.
2. **Validate the reference player.** Confirm local file selection, decode/output, EQ audibility, bypass, pause, seek, route changes, audio focus, and teardown on a physical Android device.
3. **Define one streaming DSP contract.** The render call must accept caller-owned interleaved PCM, process bounded frame counts, avoid allocations and blocking operations, and expose explicit sample-rate/channel/format requirements. Keep UI/platform code outside the render loop.
4. **Probe optional session effects.** If investigating session attachment, query capabilities and report unavailable/unsupported states instead of silently falling back or claiming universal support.
5. **Treat playback capture as a separate experiment.** Prototype capture consent, allowed-source behavior, route-back handling, latency, audio focus, foreground-service behavior, and feedback prevention independently before considering it a product feature.
6. **Add device evidence before marketing claims.** Record device model, Android version, source app, route, sample rate, measured round-trip latency, and test outcome. A generated tone test does not count as a source-app integration test.

## Acceptance gates

### Reference player

- Decoded PCM is sent through the same native DSP used by the test harness.
- Bypass produces a null/identity processing result within documented numeric tolerance.
- EQ changes measurably change a deterministic test signal's response.
- Start, pause, seek, route change, audio focus loss, and teardown are tested.
- Processing is not performed on the UI thread.
- No per-buffer allocations or blocking locks occur in the native render path.
- Physical-device tests cover speaker, wired output where available, and Bluetooth.

### Optional external-audio compatibility

- The user is told exactly which mechanism is being used and its limitations.
- Permission denial, source-app capture restrictions, unsupported effects, and service restarts are handled explicitly.
- The feature never reports success merely because a capture or effect object was created.
- Latency and stability are measured on each claimed supported configuration.
- No app is advertised as supported until its output is demonstrably processed end-to-end.

## Implementation boundary

The current generated-tone Android plugin is a useful smoke-test harness. Keep it as a diagnostic mode while the reference-player path is built. Do not repurpose its status label or generated samples to imply external-app audio is being modified.
