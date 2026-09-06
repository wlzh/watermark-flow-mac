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
WEBSITE="$(plutil -extract Website raw "$APP/Contents/Info.plist")"
codesign --verify --deep --strict "$APP"

test "$VERSION" = "$(tr -d '[:space:]' < "$ROOT/VERSION")"
test "$AUTHOR" = "X @wlzh"
test "$WEBSITE" = "https://869hr.uk"

echo "TEST_ALL=PASS"
echo "VERIFIED_VERSION=$VERSION"
echo "VERIFIED_AUTHOR=$AUTHOR"
echo "VERIFIED_WEBSITE=$WEBSITE"
