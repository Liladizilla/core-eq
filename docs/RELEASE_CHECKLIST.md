# Release readiness

## Android

- [x] Release APK builds in GitHub Actions.
- [x] Native DSP tests, Flutter tests, and Flutter analysis passed in the APK workflow.
- [x] APK artifact uploaded for device testing.
- [x] Manually installed and opened on a physical Android phone; current UI screenshot supplied by the project owner.
- [ ] Confirm the exact tested commit is the release commit.
- [ ] Verify DSP behavior and audio routing on the target device beyond the generated test tone.
- [ ] Configure a production signing key through GitHub Actions secrets or the release environment. Never commit keystores or passwords.
- [ ] Build a signed APK/AAB and test it before creating a public Play Store release.
- [ ] Finish Play Console data safety, content rating, privacy policy, support contact, icon, and screenshot assets.

The CI artifact is for testing and is not the same as a production-signed Play Store release.

## iOS

- [ ] Add and maintain the iOS Flutter target.
- [ ] Build and package the native DSP for supported Apple architectures.
- [ ] Implement a supported iOS audio graph (in-app player and/or AUv3 extension); do not claim system-wide audio interception.
- [ ] Configure Apple signing and provisioning through a secured macOS build environment.
- [ ] Build an archive, install on a real iPhone, and verify audio behavior.
- [ ] Complete App Store Connect privacy, age-rating, support, screenshots, and review information.

No iOS release artifact has been produced or verified yet. Store metadata is a draft until the app itself is buildable and tested on iOS.

## Showcase screenshot

Use the owner-supplied screenshot of the running Android app as the primary visual reference. Add the original image as assets/showcase/core-eq-android.jpg and verify that the image is present before linking it from the README. Keep status-bar details and the visible generated-test-tone limitations honest; do not present this screenshot as an iOS capture.
