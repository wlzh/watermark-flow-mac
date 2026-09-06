#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
APP="$ROOT/dist/WatermarkFlow.app"
CONTENTS="$APP/Contents"

cd "$ROOT"
swift build -c release

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$ROOT/.build/release/WatermarkFlow" "$CONTENTS/MacOS/WatermarkFlow"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist"

ICONSET="$(mktemp -d)/AppIcon.iconset"
swift "$ROOT/scripts/generate-icon.swift" "$ICONSET"
iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns"

plutil -lint "$CONTENTS/Info.plist" >/dev/null
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

echo "BUILD_APP=PASS"
echo "APP_PATH=$APP"
echo "APP_VERSION=$VERSION"
