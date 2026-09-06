#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/WatermarkFlow.app"

cd "$ROOT"
swift run WatermarkFlowTests
"$ROOT/scripts/build-app.sh"
"$APP/Contents/MacOS/WatermarkFlow" --self-test

VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"
AUTHOR="$(plutil -extract Author raw "$APP/Contents/Info.plist")"
AUTHOR_URL="$(plutil -extract AuthorURL raw "$APP/Contents/Info.plist")"
WEBSITE="$(plutil -extract Website raw "$APP/Contents/Info.plist")"
BUILD="$(plutil -extract CFBundleVersion raw "$APP/Contents/Info.plist")"
ARCHITECTURES="$(lipo -archs "$APP/Contents/MacOS/WatermarkFlow")"
codesign --verify --deep --strict "$APP"

test "$VERSION" = "$(tr -d '[:space:]' < "$ROOT/VERSION")"
test "$AUTHOR" = "X @wlzh"
test "$AUTHOR_URL" = "https://x.com/wlzh"
test "$WEBSITE" = "https://869hr.uk"
test "$BUILD" = "4"
test "$ARCHITECTURES" = "x86_64 arm64" -o "$ARCHITECTURES" = "arm64 x86_64"

echo "TEST_ALL=PASS"
echo "VERIFIED_VERSION=$VERSION"
echo "VERIFIED_AUTHOR=$AUTHOR"
echo "VERIFIED_AUTHOR_URL=$AUTHOR_URL"
echo "VERIFIED_WEBSITE=$WEBSITE"
echo "VERIFIED_BUILD=$BUILD"
echo "VERIFIED_ARCHITECTURES=$ARCHITECTURES"
