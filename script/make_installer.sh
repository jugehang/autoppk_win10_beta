#!/bin/zsh
# AutoPMX DMG Installer Builder (canonical, release + hardened)
#
# What it does:
#   1. Builds a RELEASE, optimized, stripped, ad-hoc-signed binary (internal hardening active).
#   2. Assembles a fully-resourced .app bundle (copies ALL of Resources/ so nothing is missed).
#   3. Generates a branded DMG background image.
#   4. Sets the drag-to-Applications icon layout via AppleScript.
#   5. Encrypts the DMG with AES-256 (password below).
#
# Usage:  bash script/make_installer.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="AutoPMX"
PASSWORD="zbdd666"

# --- Installer package naming -------------------------------------------------
# Format: <PKG_PREFIX>_<APP_VERSION>_<BETA_TAG>.dmg  e.g. DuPMx_1.1_1.1.dmg
# - APP_VERSION : R&D version, set once (default 1.1). Change rarely.
# - BETA_TAG    : internal-test codename, change per beta build (e.g. 0.8).
#   → For a new internal test you normally ONLY edit BETA_TAG below.
PKG_PREFIX="DuPMx"
APP_VERSION="1.1"
BETA_TAG="1.1"
DMG_NAME="${PKG_PREFIX}_${APP_VERSION}_${BETA_TAG}"

WORK="$ROOT/.build/dmginst"
DMG_OUT="$ROOT/${DMG_NAME}.dmg"
ENTITLEMENTS="$ROOT/script/entitlements.plist"
STAGING="$WORK/staging"

echo "===== AutoPMX DMG Installer Builder ====="

# ---------------------------------------------------------------------------
# Step 1: Build RELEASE binary (optimized + stripped + hardened)
# ---------------------------------------------------------------------------
echo "[1] Building RELEASE binary (optimized, stripped, hardened)..."
swift build -c release -Xswiftc -O -Xswiftc -whole-module-optimization
BINARY="$ROOT/.build/release/$APP_NAME"
strip -x "$BINARY" 2>/dev/null || true
strip -S "$BINARY" 2>/dev/null || true
# strip Swift reflection metadata that aids reverse engineering
for section in __swift5_types __swift5_protos __swift5_fieldmd __swift5_reflstr __swift5_assocty __swift5_builtin __swift5_capture __swift5_mpename __swift5_replace __swift5_proto_enum_case; do
    strip -R "$section" "$BINARY" 2>/dev/null || true
done
echo "     Binary: $(du -h "$BINARY" | cut -f1)"

# ---------------------------------------------------------------------------
# Step 2: Clean + staging dirs
# ---------------------------------------------------------------------------
echo "[2] Cleaning..."
rm -rf "$WORK" "$DMG_OUT"
mkdir -p "$STAGING/$APP_NAME.app/Contents/MacOS"
mkdir -p "$STAGING/$APP_NAME.app/Contents/Resources"
mkdir -p "$STAGING/.background"

# ---------------------------------------------------------------------------
# Step 3: Assemble .app bundle
# ---------------------------------------------------------------------------
echo "[3] Assembling .app bundle..."
cp "$BINARY" "$STAGING/$APP_NAME.app/Contents/MacOS/$APP_NAME"
chmod +x "$STAGING/$APP_NAME.app/Contents/MacOS/$APP_NAME"

# Copy the ENTIRE Resources folder so the bundled app is self-contained and
# nothing (rules, python/R scripts, demo seed) is accidentally omitted.
if [[ -d "$ROOT/Resources" ]]; then
    # copy contents (including hidden dotfiles) without clobbering the MacOS dir
    tar -C "$ROOT/Resources" -cf - . | tar -C "$STAGING/$APP_NAME.app/Contents/Resources" -xf -
fi
echo "     Resources: $(du -sh "$STAGING/$APP_NAME.app/Contents/Resources" | cut -f1)"

# Info.plist (hardened-runtime marker + display name)
cat > "$STAGING/$APP_NAME.app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>com.autopmx.workbench</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>DuDu PMx</string>
  <key>CFBundleIconFile</key><string>AutoPMX</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>3</string>
  <key>CFBundleShortVersionString</key><string>1.1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc code signing (internal hardening in AppHardening.swift is active regardless).
# Kernel-level Hardened Runtime requires an Apple Developer ID.
echo "     Signing (ad-hoc, internal hardening active)..."
if [[ -f "$ENTITLEMENTS" ]]; then
    codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" --timestamp=none \
        "$STAGING/$APP_NAME.app" 2>&1 || echo "     (sign warning ignored)"
else
    codesign --force --deep --sign - --timestamp=none \
        "$STAGING/$APP_NAME.app" 2>&1 || echo "     (sign warning ignored)"
fi

# Applications symlink for the drag-to-install layout
ln -s /Applications "$STAGING/Applications"

# ---------------------------------------------------------------------------
# Step 4: Generate branded DMG background image
# ---------------------------------------------------------------------------
echo "[4] Creating DMG background..."
BG_PATH="$STAGING/.background/bg.png"
if python3 -c "import PIL" 2>/dev/null; then
    python3 - "$BG_PATH" <<'PYEOF'
import sys
from PIL import Image, ImageDraw, ImageFont
out = sys.argv[1]
img = Image.new("RGB", (660, 480), (28, 28, 30))
draw = ImageDraw.Draw(img)
# top accent gradient
for y in range(160):
    a = 60 * (1 - y / 160) / 255
    for x in range(660):
        o = img.getpixel((x, y))
        img.putpixel((x, y), (int(o[0]*(1-a)+20*a), int(o[1]*(1-a)+100*a), int(o[2]*(1-a)+200*a)))
try:
    f_lg = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 28)
    f_md = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)
    f_sm = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 13)
except Exception:
    f_lg = f_md = f_sm = ImageFont.load_default()
draw.text((330, 50), "DuDu PMx", fill=(255, 255, 255), font=f_lg, anchor="mt")
draw.text((330, 85), "AI Pharmacometrics Workbench  ·  v1.1.0", fill=(140, 165, 210), font=f_sm, anchor="mt")
draw.line([(80, 130), (580, 130)], fill=(70, 75, 85), width=1)
arrow = [(185, 230), (215, 230), (215, 212), (243, 238), (215, 264), (215, 246), (185, 246)]
draw.polygon(arrow, fill=(100, 155, 235))
draw.text((265, 238), "Drag to the Applications folder to install", fill=(210, 215, 225), font=f_md, anchor="lm")
draw.line([(80, 340), (580, 340)], fill=(55, 58, 66), width=1)
draw.text((330, 370), "macOS 13+  ·  SwiftUI  ·  NONMEM 7.4+", fill=(100, 110, 120), font=f_sm, anchor="mt")
draw.text((330, 400), "Changsha Duxact Biotechnology Co., Ltd.", fill=(65, 70, 80), font=f_sm, anchor="mt")
draw.text((330, 430), "© 2025-2026  Graham Ju", fill=(45, 48, 55), font=f_sm, anchor="mt")
img.save(out, "PNG")
print("background written:", out)
PYEOF
else
    echo "     (PIL not available — skipping custom background; layout still applies)"
fi

# ---------------------------------------------------------------------------
# Step 5: Create writable DMG and apply icon layout
# ---------------------------------------------------------------------------
echo "[5] Creating + laying out DMG..."
SIZE=$(( $(du -sm "$STAGING" | awk '{print $1}') + 40 ))
hdiutil create -size ${SIZE}m -fs HFS+ -volname "DuDu PMx" \
    -srcfolder "$STAGING" "$WORK/temp_rw.dmg" -quiet
echo "     Uncompressed: $(ls -lh "$WORK/temp_rw.dmg" | awk '{print $5}')"

LAYOUT_OK=false
ATTACH_OUT=$(hdiutil attach -readwrite -noverify -noautoopen "$WORK/temp_rw.dmg" 2>&1 || true)
if echo "$ATTACH_OUT" | grep -q "Apple_HFS"; then
    DEVICE=$(echo "$ATTACH_OUT" | awk '/Apple_HFS/ {print $1}')
    VOLUME=$(echo "$ATTACH_OUT" | awk '/Apple_HFS/ {print $NF}')
    echo "     Mounted at $VOLUME"
    osascript <<OSA 2>/dev/null || true
tell application "Finder"
    tell disk "DuDu PMx"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 200, 800, 600}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 96
        try
            set background picture of theViewOptions to file ".background:bg.png"
        end try
        set position of item "$APP_NAME.app" of container window to {170, 200}
        set position of item "Applications" of container window to {470, 200}
        update without registering applications
        delay 1
        close
    end tell
end tell
OSA
    echo "     Layout applied"
    hdiutil detach "$DEVICE" -quiet -force 2>/dev/null || true
    LAYOUT_OK=true
else
    echo "     (attach not available, skipping layout)"
fi

# ---------------------------------------------------------------------------
# Step 6: Encrypt to final DMG
# ---------------------------------------------------------------------------
echo "[6] Encrypting DMG (AES-256)..."
if [[ "$LAYOUT_OK" == true ]]; then
    printf "%s" "$PASSWORD" | hdiutil convert "$WORK/temp_rw.dmg" \
        -format UDZO -encryption AES-256 -stdinpass \
        -o "$DMG_OUT" -quiet 2>&1 || true
else
    printf "%s" "$PASSWORD" | hdiutil create \
        -encryption AES-256 -stdinpass \
        -format UDZO -fs HFS+ -volname "DuDu PMx" \
        -srcfolder "$STAGING" "$DMG_OUT" -quiet 2>&1 || true
fi

# ---------------------------------------------------------------------------
# Step 7: Clean
# ---------------------------------------------------------------------------
echo "[7] Cleaning..."
rm -rf "$WORK"

if [[ -f "$DMG_OUT" ]]; then
    echo ""
    echo "============================================"
    echo "  ✅ Installer ready!"
    echo "  📦 $DMG_OUT"
    echo "  📏 $(ls -lh "$DMG_OUT" | awk '{print $5}')"
    echo "  🔑 Password: $PASSWORD"
    echo "  🖥  Layout:   $([ "$LAYOUT_OK" = true ] && echo "✅ complete" || echo "⚠️  basic")"
    echo "============================================"
    echo ""
  echo "How to install:"
  echo "  1. Double-click ${DMG_NAME}.dmg"
  echo "  2. Enter password: $PASSWORD"
    echo "  3. Drag AutoPMX.app → Applications"
    echo "  4. If macOS says 'damaged', run: xattr -cr /Applications/AutoPMX.app"
else
    echo "ERROR: DMG was not created."
    exit 1
fi
