#!/usr/bin/env bash
set -euo pipefail

# Apply CORE-EQ branding after flutter create generates the Android runner.
manifest="android/app/src/main/AndroidManifest.xml"
legacy_icon="android/app/src/main/res/drawable/ic_core_eq.xml"
adaptive_icon="android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml"
foreground_icon="android/app/src/main/res/drawable/ic_core_eq_foreground.xml"

if [[ ! -f "$manifest" ]]; then
  echo "Android runner not found. Run: flutter create --platforms=android --project-name core_eq ." >&2
  exit 1
fi

mkdir -p "$(dirname "$legacy_icon")" "$(dirname "$adaptive_icon")"

cat > "$legacy_icon" <<'XML'
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
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

cat > "$foreground_icon" <<'XML'
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#00000000" android:strokeColor="#7CE7DF"
        android:strokeWidth="4.5" android:strokeLineCap="round"
        android:strokeLineJoin="round"
        android:pathData="M16,54h12l6,-17l8,34l9,-46l9,58l8,-40l7,23l6,-12h11" />
    <path android:fillColor="#00000000" android:strokeColor="#7CE7DF"
        android:strokeWidth="1.5" android:strokeAlpha="0.45"
        android:pathData="M20,76h68" />
</vector>
XML

cat > "$adaptive_icon" <<'XML'
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/core_eq_icon_background" />
    <foreground android:drawable="@drawable/ic_core_eq_foreground" />
</adaptive-icon>
XML

colors="android/app/src/main/res/values/core_eq_colors.xml"
cat > "$colors" <<'XML'
<resources>
    <color name="core_eq_icon_background">#090B0E</color>
</resources>
XML

python3 - <<'PY'
from pathlib import Path
import re
path = Path("android/app/src/main/AndroidManifest.xml")
text = path.read_text()
text, count = re.subn(r'android:icon="@(?:mipmap/ic_launcher|drawable/ic_core_eq)"',
                      'android:icon="@mipmap/ic_launcher"', text, count=1)
if count == 0 and 'android:icon="@mipmap/ic_launcher"' not in text:
    raise SystemExit("Could not find the application launcher icon attribute")
path.write_text(text)
PY

test -s "$legacy_icon"
test -s "$foreground_icon"
test -s "$adaptive_icon"
test -s "$colors"
grep -q 'android:icon="@mipmap/ic_launcher"' "$manifest"
echo "CORE-EQ legacy and adaptive launcher icons applied."
