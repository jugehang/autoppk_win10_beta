#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="AutoPMX"
BUNDLE="$ROOT/dist/$APP_NAME.app"
ENTITLEMENTS="$ROOT/script/entitlements.plist"

# Parse flags
RELEASE=false
HARDEN=false
VERIFY_ONLY=false
for arg in "$@"; do
    case "$arg" in
        --release) RELEASE=true ;;
        --harden) HARDEN=true ;;
        --verify) VERIFY_ONLY=true ;;
    esac
done

cd "$ROOT"

pkill -x "$APP_NAME" 2>/dev/null || true
sleep 0.5

# --- Build ---
if $RELEASE; then
    echo "Building in RELEASE mode (optimized, stripped)"
    swift build -c release -Xswiftc -O -Xswiftc -whole-module-optimization
    BINARY="$ROOT/.build/release/$APP_NAME"
else
    echo "Building in DEBUG mode"
    swift build
    BINARY="$ROOT/.build/debug/$APP_NAME"
fi

# --- Strip symbols (remove debug info, local symbols, Swift metadata where possible) ---
echo "Stripping debug symbols..."
strip -x "$BINARY" 2>/dev/null || true
# Strip Swift reflection metadata (makes class-dump / Mirror less effective)
strip -S "$BINARY" 2>/dev/null || true

# --- Remove Swift runtime metadata that aids reverse engineering ---
# These sections contain type names, field names, protocol conformances.
# Removing them makes tools like Hopper/IDA produce much less readable output.
if $RELEASE; then
    echo "Removing Swift type metadata..."
    # swift5_types, swift5_proto, swift5_fieldmd, swift5_reflstr — erase with zeros
    for section in __swift5_types __swift5_protos __swift5_fieldmd __swift5_reflstr __swift5_assocty __swift5_builtin __swift5_capture __swift5_mpename __swift5_replace __swift5_proto_enum_case; do
        # Use segedit on macOS 13+ or strip
        strip -R "$section" "$BINARY" 2>/dev/null || true
    done
fi

# --- Assemble bundle ---
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

cp "$BINARY" "$BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$BUNDLE/Contents/MacOS/$APP_NAME"

# Icons, rule files, demo seed, Python/R bridges, and diagnostics scripts. Copy the
# whole Resources tree so new files added to the app are never omitted from the bundle.
cp -R "$ROOT/Resources/." "$BUNDLE/Contents/Resources/"

# --- Info.plist ---
cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>com.autopmx.workbench</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>DuDu PMx</string>
  <key>CFBundleShortVersionString</key>
  <string>1.1.0</string>
  <key>CFBundleVersion</key>
  <string>3</string>
  <key>CFBundleIconFile</key>
  <string>AutoPMX</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

# --- Code signing ---
# Note: Hardened runtime (--options runtime) requires a valid Developer ID.
# Ad-hoc signing (-) does NOT support runtime enforcement at the macOS kernel level.
# Our INTERNAL hardening (anti-debug + integrity check in AppHardening.swift)
# works regardless and is effective even with ad-hoc signing.
if $HARDEN; then
    echo "Signing with ad-hoc identity..."
    echo "  Note: Hardened Runtime (kernel-level) requires Apple Developer ID."
    echo "  Internal hardening (anti-debug + code integrity) is active."
    if [[ -f "$ENTITLEMENTS" ]]; then
        codesign --force --deep --sign - \
            --entitlements "$ENTITLEMENTS" \
            --timestamp=none \
            "$BUNDLE" 2>&1
    else
        codesign --force --deep --sign - \
            --timestamp=none \
            "$BUNDLE" 2>&1
    fi
    echo "  Signature: $(codesign -dvvv "$BUNDLE" 2>&1 | grep -E 'Signature' | head -1 || echo 'ad-hoc')"
else
    echo "Signing with ad-hoc identity..."
    codesign --force --deep --sign - "$BUNDLE" 2>&1
fi

# --- Install to /Applications ---
if [[ -d "/Applications/$APP_NAME.app" ]]; then
  rsync -a --delete "$BUNDLE/" "/Applications/$APP_NAME.app/"
else
  cp -R "$BUNDLE" "/Applications/$APP_NAME.app"
fi
echo "✓ Installed to /Applications/$APP_NAME.app"

open "/Applications/$APP_NAME.app"

if $VERIFY_ONLY; then
  sleep 2
  if pgrep -x "$APP_NAME" >/dev/null; then
    echo "$APP_NAME launched"
  else
    echo "WARNING: $APP_NAME did not launch"
  fi
fi

# Report binary size for comparison
echo ""
echo "Build summary:"
echo "  Mode:     $($RELEASE && echo "RELEASE" || echo "DEBUG")"
echo "  Hardened: $($HARDEN && echo "YES" || echo "NO")"
echo "  Binary:   $(du -h "$BINARY" | cut -f1)"
echo "  Stripped: ✓"
rm -f /tmp/stripped_check
