# Headphone EQ diagnostic

## Field report

The owner reported that the generated test tone stopped during a Bluetooth headphone test, bypass behavior was unclear, and bass boost was not noticeable on music played in a separate music app.

## Important distinction: separate player vs CORE-EQ player

CORE-EQ does **not** capture or process audio from another app. If music is playing in Spotify or a separate music player, CORE-EQ's EQ controls cannot change that stream. The generated test tone is a separate app-owned output path and is not a proxy for external-app processing.

The Android build now also has an in-app local-file playback path using Media3. Only a file selected and played in CORE-EQ passes through the Media3 DSP processor. This is the path that must be used to validate audible EQ changes.

## Current processing route

For CORE-EQ's own local-file player, Media3 sends supported PCM16 mono/stereo audio (22.05–96 kHz) through the native C++ DSP chain. The current chain includes the 10-band EQ, output gain, bypass, output peak limiter, and optional mid/side widening. Bass boost is applied as an offset to the three lowest EQ bands. The generated test tone uses its own AudioTrack and native DSP session.

The player exposes input/output peak and RMS, signal-difference RMS, processed frame count, sample rate, and channel count. Difference RMS reports the total sample difference, not an EQ-only measurement. A non-zero value does not prove that the EQ curve is audible or desirable.

## Correct Bluetooth/local-file validation

1. Stop the generated test tone.
2. Connect the Bluetooth headphones and wait until Android reports them as the active media output.
3. Open **LOCAL PLAYBACK / DSP PATH** inside CORE-EQ and choose a local music file. Do not use Spotify or another app for this test.
4. Start playback at a low, comfortable volume. Confirm the position advances and sample rate/channel count appear.
5. Set output gain to 0 dB, disable limiter and spatial widening, and leave bypass off.
6. Choose a track with clear bass content. Raise only 32 Hz and 64 Hz to +6 dB. Keep all other EQ bands at 0 dB.
7. Listen to the same short segment, then enable bypass without changing device volume. Compare active vs bypass. Repeat the comparison once.
8. Check the diagnostics: processed frames should increase during playback; bypass should drive difference RMS to zero after the next processed blocks; active EQ should generally produce a non-zero difference when the source has energy in the boosted bands.
9. Repeat with the phone speaker or wired headphones to isolate Bluetooth routing from the DSP path.
10. Record device model, Android version, Bluetooth codec if visible, track format, and whether the EQ difference is audible.

Do not max every control. Large boosts can cause clipping or limiter attenuation, making comparisons less useful and potentially unsafe for hearing.

## Interpreting outcomes

- **No sound from generated tone:** investigate AudioTrack startup, audio focus, device route, and the Android playback error/status.
- **Tone works, but external music is unchanged:** expected; external-app audio is outside CORE-EQ's current scope.
- **CORE-EQ local file plays, but processed frames remain at zero:** inspect Media3 processor attachment/configuration and status propagation.
- **Processed frames increase and bypass difference RMS is zero, but active EQ is not audible:** inspect EQ coefficient/center-frequency behavior, gain mapping, source spectral content, output level, and headphone/app DSP settings.
- **Local file works on speaker but not Bluetooth:** investigate Android route changes, Bluetooth device profile/codec, and Media3/AudioTrack behavior separately from DSP correctness.

## Known limits

- The generated tone supports 32, 64, 125, 250, 440, and 1000 Hz; 440 Hz remains the default.
- The generated tone is not a frequency-response sweep or a substitute for local music playback.
- The visual field is animated artwork driven by generated-tone peak status, not a live FFT spectrum analyzer.
- No system-wide equalizer, microphone capture, or arbitrary other-app audio processing is implemented.
- Automated CI cannot establish audible quality or Bluetooth routing on physical devices.

## Result template

| Field | Result |
|---|---|
| Device / Android version | |
| CORE-EQ version / commit | |
| Track format (sample rate / channels) | |
| Output route / Bluetooth device | |
| Generated tone start and stop | |
| CORE-EQ local file playback | |
| Processed frames increasing | |
| Bypass comparison | |
| Active EQ comparison | |
| Difference RMS behavior | |
| Speaker vs Bluetooth result | |
| Notes / errors | |
