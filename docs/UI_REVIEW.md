# CORE-EQ UI Review Before Mobile Packaging

The desktop UI must be reviewed and approved before production Android APK or iOS packaging is resumed. This is a hard project gate, not a suggestion.

## Run the interface locally on Fedora/Linux

Install Flutter stable and the Linux desktop build dependencies:

```bash
sudo dnf install clang cmake ninja-build pkgconf-pkg-config gtk3-devel mesa-libGL-devel
```

From the repository root, generate the Linux runner if it is not already present, resolve dependencies, and launch the real Flutter UI:

```bash
flutter create --platforms=linux --project-name core_eq .
flutter pub get
flutter devices
flutter run -d linux
```

The `flutter create` command generates platform scaffolding; it does not replace the Dart application screens. Keep local changes backed up before running scaffolding commands in an existing checkout.

## Automated review artifact

The `CORE-EQ Desktop UI Review` workflow builds the Linux desktop application, runs Flutter tests and analysis, launches the built application in a virtual display, and uploads a screenshot plus the runnable Linux bundle as a GitHub Actions artifact. Open the workflow run and download `core-eq-desktop-ui-review`.

## Review checklist

- [ ] Inspect the full interface at a desktop window size and at a narrow size.
- [ ] Check hierarchy, typography, alignment, spacing, contrast, and legibility.
- [ ] Verify the visualizer and spectrum mode are clearly marked as demo animation.
- [ ] Verify engine state, latency, meters, and bypass labels do not imply live audio processing.
- [ ] Exercise module selection, mode switching, intensity control, and master bypass.
- [ ] Identify any clipped, inaccessible, misleading, or nonfunctional controls.
- [ ] Fix issues and obtain explicit UI approval before production mobile packaging.

## Current limitation

The visualizer is procedural demo animation. Meter readings are placeholder values. The module selector, intensity, mode and bypass are local presentation state; they do not yet configure the native DSP engine or affect device audio. The native C++ engine and FFI boundary are separate from the UI until a later, tested integration phase.
