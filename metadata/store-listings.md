# CORE-EQ store metadata drafts

These are copy-ready drafts for store-console setup, not a claim that either store submission is complete. Confirm the final package/bundle IDs, screenshots, privacy URL, age ratings, and support contact before submitting.

## Google Play

**App name:** CORE-EQ: Personal Audio  
**Short description:** A 10-band equalizer with on-device test tones and local music playback.  
**Full description:**

CORE-EQ is a hardware-inspired audio control deck built around a 10-band graphic equalizer and a native digital signal processing engine.

Explore frequency shaping from 32 Hz to 16 kHz, adjust output level, and experiment with bass boost, limiter, bypass, and mid/side spatial widening. Android supports both built-in generated test tones and local audio files played inside CORE-EQ.

**Current build scope:** Android processes CORE-EQ's generated test tones and local audio files played inside the app. It does not currently equalize audio from Spotify or other apps, capture microphone input, or provide universal system-wide audio processing. Device compatibility and audio routing can vary; verify audible DSP behavior on each target device.

**Privacy:** audio processing is designed to run on-device. Do not publish a privacy-policy URL until a real policy page is available and reviewed against the final app behavior.

**Release status:** internal/device testing build. Not yet a public Play Store release.

## Apple App Store

**App name:** CORE-EQ: Personal Audio  
**Subtitle:** Precision EQ & Audio Tools  
**Promotional text:** Shape sound with a precision 10-band equalizer and a focused, hardware-inspired audio interface.

**Description:**

CORE-EQ is a precision audio workspace featuring a 10-band equalizer interface, output-level controls, and a native DSP foundation.

Use generated test tones to explore frequency shaping, bypass, limiting, and spatial widening. The current Android build also supports local audio-file playback through CORE-EQ's DSP chain; this iOS description is a product direction, not a claim that the feature is implemented on iOS. The interface is designed for deliberate adjustments, clear feedback, and a restrained dark visual system.

**Current platform status:** an iOS app build, native DSP packaging, and a signed archive have not yet been verified. iOS does not permit ordinary apps to intercept all audio from other apps; any eventual implementation must use a supported in-app player and/or Audio Unit extension model.

**Release status:** metadata draft only. Do not submit until an iOS target is implemented, built, signed, and tested on a real device.

## Shared keywords

equalizer, audio, sound, bass, frequency, DSP, audio tools, 10 band, sound shaping

## Store assets still required

- App icon exported to each store's exact specifications.
- Current-device screenshots, including the supplied working Android screenshot.
- Privacy policy URL and support contact.
- Final package/bundle identifiers and version/build numbers.
- Store-specific content rating, privacy declarations, and review notes.
