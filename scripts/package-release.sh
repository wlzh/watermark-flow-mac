#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
RELEASE_DIR="$ROOT/dist/release"
ARCHIVE="$RELEASE_DIR/WatermarkFlow-v${VERSION}-macos-universal.zip"
CHECKSUM="$RELEASE_DIR/SHA256.txt"

"$ROOT/scripts/build-app.sh"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"
/usr/bin/ditto -c -k --keepParent "$ROOT/dist/WatermarkFlow.app" "$ARCHIVE"
(
    cd "$RELEASE_DIR"
    shasum -a 256 "$(basename "$ARCHIVE")" > "$(basename "$CHECKSUM")"
)

echo "PACKAGE_RELEASE=PASS"
echo "RELEASE_ARCHIVE=$ARCHIVE"
echo "RELEASE_CHECKSUM=$CHECKSUM"
