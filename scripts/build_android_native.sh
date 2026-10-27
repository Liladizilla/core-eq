#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"

if [[ -n "${ANDROID_NDK_HOME:-}" && -f "${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake" ]]; then
  NDK_DIR="$ANDROID_NDK_HOME"
elif [[ -n "$ANDROID_SDK_ROOT" && -d "$ANDROID_SDK_ROOT/ndk" ]]; then
  NDK_DIR="$(find "$ANDROID_SDK_ROOT/ndk" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)"
else
  echo "Android NDK not found. Set ANDROID_NDK_HOME or ANDROID_SDK_ROOT/ANDROID_HOME." >&2
  exit 2
fi

TOOLCHAIN="$NDK_DIR/build/cmake/android.toolchain.cmake"
if [[ ! -f "$TOOLCHAIN" ]]; then
  echo "Android NDK CMake toolchain not found: $TOOLCHAIN" >&2
  exit 2
fi

OUT_DIR="$ROOT_DIR/android/app/src/main/jniLibs"
BUILD_ROOT="${CORE_EQ_ANDROID_BUILD_DIR:-$ROOT_DIR/build/android-native}"
API_LEVEL="${CORE_EQ_ANDROID_API_LEVEL:-23}"

build_abi() {
  local abi="$1"
  local build_dir="$BUILD_ROOT/$abi"
  echo "Building CORE-EQ native library for $abi (Android API $API_LEVEL)"
  cmake -S "$ROOT_DIR/native/dsp" -B "$build_dir" \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DANDROID_ABI="$abi" \
    -DANDROID_PLATFORM="android-$API_LEVEL" \
    -DANDROID_STL=c++_static \
    -DCORE_EQ_BUILD_TESTS=OFF \
    -DCMAKE_BUILD_TYPE=Release
  cmake --build "$build_dir" --config Release --parallel
  local library="$build_dir/libcore_eq.so"
  if [[ ! -f "$library" ]]; then
    echo "Expected native library was not produced: $library" >&2
    exit 3
  fi
  mkdir -p "$OUT_DIR/$abi"
  install -m 0644 "$library" "$OUT_DIR/$abi/libcore_eq.so"
}

build_abi arm64-v8a
build_abi armeabi-v7a
build_abi x86_64

echo "Packaged CORE-EQ libraries:"
find "$OUT_DIR" -mindepth 2 -maxdepth 2 -type f -name 'libcore_eq.so' -print | sort
