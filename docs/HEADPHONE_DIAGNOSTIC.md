# Headphone EQ diagnostic

## Field report

The owner reported that the generated test tone stopped during a Bluetooth headphone test, bypass behavior was unclear, and bass boost was not noticeable on music played in a separate music app.

## Processing paths

CORE-EQ has two distinct Android paths:

1. **OEM global output effects (session 0):** the app now probes Android's global output-mix Equalizer and BassBoost effects. When the phone's audio-effect implementation allows a third-party app to attach them, CORE-EQ can enable those effects and control the exposed equalizer bands and bass strength. Android and OEMs do not guarantee this capability. It may be unavailable, may behave differently across routes, and must be tested on the actual phone.
2. **App-owned native DSP:** the generated test tone and the optional Media3 local-file player pass through CORE-EQ's own native C++ DSP. This path does not receive Spotify or arbitrary other-app audio.

The global output-effect panel is the primary external-player test. The app-owned DSP diagnostics are not evidence that an external music app is being processed.

## Global output effect test with Bluetooth headphones

1. Install the exact APK built from the commit under test.
2. Connect the Bluetooth headphones and start music in Spotify or another external player.
3. Open CORE-EQ and inspect **ANDROID OUTPUT EFFECTS**.
4. Check that the output route reports the expected Bluetooth device type.
5. Check whether **GLOBAL EQUALIZER** and **GLOBAL BASS BOOST** are available. If either is unavailable, record the reported capability/error; do not treat app-owned DSP as a workaround.
6. Enable the global equalizer. Raise only the 63 Hz and 125 Hz bands by approximately +6 dB. Keep other bands flat and device volume low.
7. Compare the same music segment with the global equalizer enabled and disabled. Do not change the player volume between comparisons.
8. Enable global bass boost separately and compare again.
9. Repeat with the phone speaker and, if available, wired headphones.
10. Record device model, Android version, headphone model, route type, whether each global effect was available, and whether the changes were audible in the external player.

If the effects report as enabled but the external player's sound does not change, record that as a failed route/device validation. Do not claim system-wide EQ based solely on a successful API call.

## App-owned DSP diagnostic

Use the generated test tone only to check CORE-EQ's own native DSP and AudioTrack lifecycle. Stop it before switching tests or comparing external music. It requests audio focus and may be interrupted by another media app.

For a local-file DSP test, a file selected in the optional Media3 playback implementation is processed by the native DSP chain. This remains a development diagnostic, not the primary product workflow.

## Interpreting outcomes

- **Global Equalizer/BassBoost unavailable:** the device/OEM did not expose a usable session-0 effect. External-app EQ is not available through this path on that device.
- **Global effects enable but external music is unchanged:** the OEM may not apply the effect to the active route or app. Record the device/route as unsupported until verified.
- **Route label does not match the connected headphones:** investigate Android device enumeration and route-change notifications.
- **Generated tone stops:** inspect audio focus, AudioTrack startup, route changes, and the native playback error/status.
- **Local-file playback works but Spotify is unchanged:** expected for the app-owned Media3 path; only the optional global output-effect path can affect external playback.
- **Native update rejected with status 0:** should no longer be reported as a native rejection when Media3 is the rejecting component. The platform channel now distinguishes `MEDIA3_EQ_REJECTED` from `NATIVE_EQ_REJECTED`.

## Known limits

- Session-0 Android audio effects are OEM/device dependent and are not a guaranteed public system-wide DSP facility.
- The session-0 Equalizer exposes the number and range of bands provided by the device. CORE-EQ maps its ten controls to the nearest available hardware-effect bands; this is not the same filter topology as the custom C++ parametric EQ.
- The custom C++ DSP is not inserted into Spotify or other apps.
- The generated tone supports 32, 64, 125, 250, 440, and 1000 Hz; 440 Hz is the default.
- The visual field is animated artwork driven by generated-tone peak status, not a live FFT spectrum analyzer.
- Automated CI cannot establish audible quality or Bluetooth routing on physical devices.

## Result template

| Field | Result |
|---|---|
| Device / Android version | |
| CORE-EQ version / commit | |
| Headphone model | |
| Output route reported by Android | |
| Global Equalizer available / enabled | |
| Global BassBoost available / enabled | |
| External player used | |
| EQ comparison audible | |
| BassBoost comparison audible | |
| Speaker vs Bluetooth result | |
| Generated tone start / stop | |
| Notes / errors | |
