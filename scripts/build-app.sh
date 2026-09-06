#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
APP="$ROOT/dist/WatermarkFlow.app"
CONTENTS="$APP/Contents"

cd "$ROOT"
swift build -c release --triple arm64-apple-macosx13.0
swift build -c release --triple x86_64-apple-macosx13.0

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
lipo -create \
    "$ROOT/.build/arm64-apple-macosx/release/WatermarkFlow" \
    "$ROOT/.build/x86_64-apple-macosx/release/WatermarkFlow" \
    -output "$CONTENTS/MacOS/WatermarkFlow"
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
echo "APP_ARCHITECTURES=$(lipo -archs "$CONTENTS/MacOS/WatermarkFlow")"
