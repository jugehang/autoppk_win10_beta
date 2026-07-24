#!/bin/zsh
set +e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="AutoPMX"
PASSWORD="jugehang520"
BINARY="$ROOT/.build/debug/$APP_NAME"
WORK="$ROOT/.build/dmginst"
DMG_OUT="$ROOT/AutoPMX_Installer.dmg"
BG_PNG="$WORK/dmg_bg.png"

echo "===== AutoPMX DMG Installer Builder ====="

# Step 1: Clean
echo "[1] Cleaning..."
rm -rf "$WORK" "$DMG_OUT"
mkdir -p "$WORK/staging/$APP_NAME.app/Contents/MacOS"
mkdir -p "$WORK/staging/$APP_NAME.app/Contents/Resources"
mkdir -p "$WORK/staging/.background"

# Step 2: Bundle
echo "[2] Building .app..."
cp "$BINARY" "$WORK/staging/$APP_NAME.app/Contents/MacOS/$APP_NAME"
chmod +x "$WORK/staging/$APP_NAME.app/Contents/MacOS/$APP_NAME"

for f in AutoPMX.icns DuDuPMxButton.png DuDuPMxSource.png Help.html autopmx_ga.py "pk parameters script.R"; do
    [ -f "$ROOT/Resources/$f" ] && cp "$ROOT/Resources/$f" "$WORK/staging/$APP_NAME.app/Contents/Resources/$f"
done

cat > "$WORK/staging/$APP_NAME.app/Contents/Info.plist" <<PLIST
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
  <key>CFBundleVersion</key><string>1.1</string>
  <key>CFBundleShortVersionString</key><string>1.1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

ln -s /Applications "$WORK/staging/Applications"

# Step 3: Copy background image (if exists)
if [ -f "$BG_PNG" ]; then
    cp "$BG_PNG" "$WORK/staging/.background/bg.png"
    echo "     Background image added"
fi

# Step 4: Create writable DMG first (for layout)
echo "[3] Creating writable DMG..."
SIZE=$(( $(du -sm "$WORK/staging" | awk '{print $1}') + 40 ))
hdiutil create -size ${SIZE}m -fs HFS+ -volname "DuDu PMx" \
    -srcfolder "$WORK/staging" "$WORK/temp_rw.dmg" -quiet
echo "     Uncompressed: $(ls -lh "$WORK/temp_rw.dmg" | awk '{print $5}')"

# Step 5: Try to mount and set layout
echo "[4] Setting DMG layout..."
ATTACH_OUT=$(hdiutil attach -readwrite -noverify -noautoopen "$WORK/temp_rw.dmg" 2>&1)
LAYOUT_OK=false
if echo "$ATTACH_OUT" | grep -q "Apple_HFS"; then
    DEVICE=$(echo "$ATTACH_OUT" | awk '/Apple_HFS/ {print $1}')
    VOLUME=$(echo "$ATTACH_OUT" | awk '/Apple_HFS/ {print $NF}')
    echo "     Mounted at $VOLUME"
    # Apply background + icon layout via AppleScript
    osascript <<OSA 2>/dev/null
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
        set background picture of theViewOptions to file ".background:bg.png"
        set position of item "$APP_NAME.app" of container window to {170, 200}
        set position of item "Applications" of container window to {470, 200}
        update without registering applications
        delay 1
        close
    end tell
end tell
OSA
    echo "     Layout applied"
    hdiutil detach "$DEVICE" -quiet -force 2>/dev/null
    LAYOUT_OK=true
else
    echo "     (attach not available, skipping layout)"
fi

# Step 6: Encrypt
echo "[5] Encrypting DMG..."
if [ "$LAYOUT_OK" = true ]; then
    # Convert the layout-customized DMG
    printf "%s" "$PASSWORD" | hdiutil convert "$WORK/temp_rw.dmg" \
        -format UDZO -encryption AES-256 -stdinpass \
        -o "$DMG_OUT" -quiet 2>&1
else
    # Create encrypted DMG directly from staging (no layout)
    printf "%s" "$PASSWORD" | hdiutil create \
        -encryption AES-256 -stdinpass \
        -format UDZO \
        -fs HFS+ \
        -volname "DuDu PMx" \
        -srcfolder "$WORK/staging" \
        "$DMG_OUT" -quiet 2>&1
fi

# Step 7: Clean
echo "[6] Cleaning..."
rm -rf "$WORK"

echo ""
echo "============================================"
echo "  Installer:  $DMG_OUT"
echo "  Size:       $(ls -lh "$DMG_OUT" | awk '{print $5}')"
echo "  Password:   jugehang520"
echo "  Layout:     $([ "$LAYOUT_OK" = true ] && echo "✅ 完整" || echo "⚠️ 基础")"
echo "============================================"
echo ""
echo "Double-click to open, enter password 'jugehang520', then drag AutoPMX.app to Applications."
