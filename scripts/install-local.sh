#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_ROOT="${INSTALL_ROOT:-/Applications}"
SOURCE="$ROOT/dist/WatermarkFlow.app"
DESTINATION="$INSTALL_ROOT/WatermarkFlow.app"

"$ROOT/scripts/build-app.sh"
pkill -x WatermarkFlow 2>/dev/null || true
rm -rf "$DESTINATION"
ditto "$SOURCE" "$DESTINATION"
xattr -dr com.apple.quarantine "$DESTINATION" 2>/dev/null || true
codesign --verify --deep --strict "$DESTINATION"
open "$DESTINATION"
sleep 2

if ! pgrep -x WatermarkFlow >/dev/null; then
    echo "INSTALL_PROCESS_CHECK=FAIL" >&2
    exit 1
fi

echo "INSTALL_APP=PASS"
echo "INSTALLED_PATH=$DESTINATION"
echo "RUNNING_PID=$(pgrep -x WatermarkFlow | head -1)"
