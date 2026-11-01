#!/usr/bin/env bash
# Regenerates the app icon from a source image.
#   ./Scripts/make-icon.sh [source]        # default: Design/logo.ai
#   ./Scripts/make-icon.sh logo.ai out/    # write elsewhere, leaving the app alone
set -euo pipefail

cd "$(dirname "$0")/.."

SOURCE="${1:-Design/logo.ai}"
ICONSET="${2:-Sources/Larp/Resources/Assets.xcassets/AppIcon.appiconset}"

[ -f "$SOURCE" ] || { echo "error: no such file: $SOURCE" >&2; exit 1; }
mkdir -p "$ICONSET"

MASTER=$(mktemp -t larp-icon).png
trap 'rm -f "$MASTER"' EXIT
xcrun swift Scripts/make-icon.swift "$SOURCE" "$MASTER" 1024 "${MODE:-fill}"

# macOS wants each size at 1x and 2x.
for size in 16 32 128 256 512; do
    sips -s format png -z "$size" "$size" "$MASTER" --out "$ICONSET/icon_${size}.png" >/dev/null
    sips -s format png -z "$((size * 2))" "$((size * 2))" "$MASTER" --out "$ICONSET/icon_${size}@2x.png" >/dev/null
done

python3 - "$ICONSET" <<'PY'
import json, sys, pathlib
images = [
    {"idiom": "mac", "size": f"{s}x{s}", "scale": scale,
     "filename": f"icon_{s}.png" if scale == "1x" else f"icon_{s}@2x.png"}
    for s in (16, 32, 128, 256, 512) for scale in ("1x", "2x")
]
out = pathlib.Path(sys.argv[1]) / "Contents.json"
out.write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
PY

echo "Wrote $(ls "$ICONSET"/*.png | wc -l | tr -d ' ') icons to $ICONSET"
echo "Run ./Scripts/bootstrap.sh if this is the first time the icons appear."
