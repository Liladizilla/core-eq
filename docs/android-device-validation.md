# Android device validation

This checklist is for validating CORE-EQ on a physical Android device. CI can compile the native library and APK, but it cannot verify audible output, Bluetooth routing, device volume behavior, or OEM audio policy.

## Safety and scope

- Start at a low device volume and keep the generated test signal at its default 6% amplitude.
- Do not wear headphones while first starting or changing test tones. Confirm the device speaker output at low volume first.
- The generated test tone and local-file player are app-owned audio paths. They do not process Spotify, browsers, or arbitrary other apps.
- Stop the tone/player before disconnecting or changing the output route.
- Record device model, Android version, output route, and test result for every run.

## 1. Generated test tone

1. Install the release APK on the device.
2. Open CORE-EQ and locate **ANDROID AUDIO TEST**.
3. Keep test level at 6%, device volume low, and select 440 Hz.
4. Start the tone. Confirm sound is audible and the UI reports the selected frequency.
5. Stop the tone. Confirm sound stops promptly.
6. Repeat at 64 Hz and 125 Hz. These low-frequency tests may be less audible on small phone speakers; use suitable headphones only after the low-volume speaker check.
7. Repeat with wired headphones and Bluetooth headphones. Record whether sound starts, remains stable, and stops cleanly.
8. Switch Bluetooth output while the tone is stopped, then restart. Do not assume Android will migrate an active AudioTrack correctly between routes.

## 2. DSP control sanity

Use the generated tone at low level. Change one control at a time:

1. Select 64 Hz. Set the 32 Hz and 64 Hz bands to +6 dB; compare against both bands at 0 dB.
2. Set bypass on. The generated-tone path should bypass EQ, limiter, and spatial processing. Toggle bypass off and confirm processing returns.
3. Enable/disable limiter and spatial processing separately. Spatial widening is only relevant to stereo playback; a mono test tone cannot demonstrate stereo width.
4. Stop the tone before changing test frequency or output route.

The generated-tone status currently exposes peak level and format metadata, not RMS or a measured frequency-response curve. Do not use its peak meter alone as proof that a particular EQ band is working.

## 3. Local-file Media3 playback

1. Choose a locally stored music file in **LOCAL PLAYBACK / DSP PATH**.
2. Start playback and confirm position advances and the reported sample rate/channel count are plausible.
3. With a stereo track playing, disable limiter and spatial processing, set output gain to 0 dB, and choose a clearly audible EQ test:
   - For bass: raise 32 Hz and 64 Hz by +6 dB.
   - For midrange: raise 500 Hz by +6 dB.
   - For treble: raise 4 kHz by +6 dB.
4. Compare each setting with bypass enabled and disabled. Keep device volume unchanged.
5. Watch IN RMS, OUT RMS, and Δ RMS. With bypass enabled, Δ RMS should settle at zero for processed blocks. With an active EQ curve and signal energy in the affected band, Δ RMS should generally become non-zero.
6. Repeat on the device speaker, wired headphones, and Bluetooth headphones.

**Interpretation:** Δ RMS measures total sample difference between input and output. It can reflect EQ, output gain, limiter, and spatial processing; it does not isolate EQ contribution. A non-zero value proves samples changed, not that the audible result is desirable.

## 4. Reliability checks

- Play a local file for at least 10 minutes.
- Pause, resume, seek, and stop repeatedly.
- Change EQ bands while playing and listen for clicks, dropouts, or stale settings.
- Lock/unlock the device and briefly background/foreground the app.
- Disconnect/reconnect Bluetooth while playback is stopped, then start again.
- Confirm no audio continues after Stop or after leaving the test-tone screen.
- Record crashes, audio dropouts, unexpected volume changes, or UI state that disagrees with audible playback.

## 5. Result template

| Field | Result |
|---|---|
| Device / model | |
| Android version | |
| CORE-EQ APK version / commit | |
| Output route | Speaker / wired / Bluetooth |
| Test tone start / stop | Pass / Fail |
| 64 Hz and 125 Hz audible | Pass / Fail / Inconclusive |
| Bypass comparison | Pass / Fail / Inconclusive |
| EQ changes audible | Pass / Fail / Inconclusive |
| RMS / Δ RMS behavior | |
| 10-minute playback | Pass / Fail |
| Notes / logs | |

Do not mark the release as device-validated until the checks above have been completed on physical hardware.