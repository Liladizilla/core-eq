#!/usr/bin/env bash
set -euo pipefail

# CI and local builds generate the Android runner with flutter create. Apply
# CORE-EQ's own vector icon after that scaffold exists so the Flutter placeholder
# is never shipped by this workflow.
manifest="android/app/src/main/AndroidManifest.xml"
icon="android/app/src/main/res/drawable/ic_core_eq.xml"

if [[ ! -f "$manifest" ]]; then
  echo "Android runner not found. Run: flutter create --platforms=android --project-name core_eq ." >&2
  exit 1
fi

mkdir -p "$(dirname "$icon")"
cat > "$icon" <<'XML'
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:fillColor="#090B0E" android:pathData="M0,0h108v108h-108z" />
    <path android:fillColor="#12161B" android:strokeColor="#293139"
        android:strokeWidth="1.5" android:pathData="M18,8h72a10,10 0,0 1,10 10v72a10,10 0,0 1,-10 10h-72a10,10 0,0 1,-10 -10v-72a10,10 0,0 1,10 -10z" />
    <path android:fillColor="#00000000" android:strokeColor="#7CE7DF"
        android:strokeWidth="3.6" android:strokeLineCap="round"
        android:strokeLineJoin="round"
        android:pathData="M20,54h7l5,-15l7,30l8,-41l8,52l7,-36l6,20l5,-10h15" />
    <path android:fillColor="#00000000" android:strokeColor="#7CE7DF"
        android:strokeWidth="1" android:strokeAlpha="0.35"
        android:pathData="M22,72h64" />
</vector>
XML

python3 - <<'PY'
from pathlib import Path
import re
path = Path("android/app/src/main/AndroidManifest.xml")
text = path.read_text()
updated, count = re.subn(r'android:icon="@mipmap/ic_launcher"', 'android:icon="@drawable/ic_core_eq"', text, count=1)
if count != 1:
    raise SystemExit("Expected exactly one default Flutter launcher icon reference in AndroidManifest.xml")
path.write_text(updated)
PY

echo "CORE-EQ launcher icon applied: $icon"
