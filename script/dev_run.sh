#!/bin/bash
# Dev build + install + launch. Always replaces /Applications/AutoPMX.app.
# Usage: bash script/dev_run.sh [--release|--debug]

set -e
cd "$(dirname "$0")/.."

BUILD_FLAG="-c release"
if [ "$1" = "--debug" ]; then
  BUILD_FLAG="-c debug"
fi

echo "▶ Building ${BUILD_FLAG}..."
swift build $BUILD_FLAG $SWIFT_OPTS 2>&1 | tail -3

BINARY=".build/${BUILD_FLAG#-c }/AutoPMX"
if [ ! -f "$BINARY" ]; then
  echo "❌ Binary not found at $BINARY"
  exit 1
fi
echo "▶ Binary: $BINARY ($(stat -f%z "$BINARY" | awk '{printf "%.1f MB", $0/1024/1024}'))"

echo "▶ Installing to /Applications/AutoPMX.app..."
pkill -x AutoPMX 2>/dev/null || true
sleep 0.5
cp "$BINARY" /Applications/AutoPMX.app/Contents/MacOS/AutoPMX
codesign --force --sign - /Applications/AutoPMX.app 2>&1 | grep -v "replacing" || true

echo "▶ Launching..."
open /Applications/AutoPMX.app
echo "✅ Done. Run: $(swift build $BUILD_FLAG 2>&1 | grep 'Build complete' || true)"
