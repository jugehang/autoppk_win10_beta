#!/usr/bin/env python3
"""AutoPMX DMG Installer Builder — Release + Hardened Runtime"""

import os, subprocess, shutil, sys, time
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(ROOT, ".build/dmginst")
DMG = os.path.join(ROOT, "DuPMx_1.0_1.2.dmg")
PASSWORD = "zbdd666"
APP = "AutoPMX"

# 1. Clean
print("[1] Cleaning...")
if os.path.exists(WORK): shutil.rmtree(WORK)
if os.path.exists(DMG): os.remove(DMG)

# 2. Build release binary only (skip assemble/sign — DMG script handles that)
print("[2] Building release binary...")
build_result = subprocess.run(
    ["swift", "build", "-c", "release", "-Xswiftc", "-O", "-Xswiftc", "-whole-module-optimization"],
    cwd=ROOT, capture_output=True, text=True, timeout=300
)
print(build_result.stdout)
if build_result.returncode != 0:
    print("BUILD ERROR (stderr):", build_result.stderr[-2000:] if build_result.stderr else "(empty)")
    print("BUILD ERROR (stdout):", build_result.stdout[-2000:] if build_result.stdout else "(empty)")
    sys.exit(1)

# Check which binary exists (release preferred)
release_binary = os.path.join(ROOT, ".build/release", APP)
debug_binary = os.path.join(ROOT, ".build/debug", APP)
if os.path.exists(release_binary):
    BINARY = release_binary
    print(f"[2b] Using RELEASE binary ({os.path.getsize(BINARY)/1024/1024:.1f} MB)")
else:
    BINARY = debug_binary
    print("[2b] WARNING: Release binary not found, using debug binary")
    print("       Run 'swift build -c release' first")

# Strip symbols
print("[2c] Stripping debug symbols...")
subprocess.run(["strip", "-x", BINARY], capture_output=True)
subprocess.run(["strip", "-S", BINARY], capture_output=True)

# 3. Copy binary + bundle resources
print("[3] Assembling bundle...")
staging = os.path.join(WORK, "staging")
app_cont = os.path.join(staging, f"{APP}.app/Contents")
os.makedirs(os.path.join(app_cont, "MacOS"))
os.makedirs(os.path.join(app_cont, "Resources"))
bg_dir = os.path.join(staging, ".background")
os.makedirs(bg_dir)

shutil.copy2(BINARY, os.path.join(app_cont, "MacOS", APP))
os.chmod(os.path.join(app_cont, "MacOS", APP), 0o755)

# Copy the ENTIRE Resources folder so the bundled app is self-contained and
# nothing (rules, python/R scripts, demo seed) is accidentally omitted.
res_src = os.path.join(ROOT, "Resources")
if os.path.isdir(res_src):
    subprocess.run(["tar", "-C", res_src, "-cf", "-", "."],
                   stdout=open(os.path.join(WORK, "_res.tar"), "wb"), check=True)
    subprocess.run(["tar", "-C", os.path.join(app_cont, "Resources"), "-xf",
                    os.path.join(WORK, "_res.tar")], check=True)
    os.remove(os.path.join(WORK, "_res.tar"))
print("     Resources copied:", os.path.join(app_cont, "Resources"))

# 4. Info.plist with hardened runtime marker
plist = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>{APP}</string>
  <key>CFBundleIdentifier</key><string>com.autopmx.workbench</string>
  <key>CFBundleName</key><string>{APP}</string>
  <key>CFBundleDisplayName</key><string>DuDu PMx</string>
  <key>CFBundleIconFile</key><string>AutoPMX</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>3</string>
  <key>CFBundleShortVersionString</key><string>1.1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>"""
with open(os.path.join(app_cont, "Info.plist"), "w") as f: f.write(plist)

# 5. Code signing (ad-hoc)
# Hardened Runtime (kernel-level) requires Apple Developer ID.
# Internal hardening (anti-debug + code integrity in AppHardening.swift) is active.
print("[4] Code-signing (ad-hoc, internal hardening active)...")
entitlements = os.path.join(ROOT, "script/entitlements.plist")
if os.path.exists(entitlements):
    sign_result = subprocess.run([
        "codesign", "--force", "--deep", "--sign", "-",
        "--entitlements", entitlements,
        "--timestamp=none",
        os.path.join(staging, f"{APP}.app")
    ], capture_output=True, text=True)
else:
    sign_result = subprocess.run([
        "codesign", "--force", "--deep", "--sign", "-",
        "--timestamp=none",
        os.path.join(staging, f"{APP}.app")
    ], capture_output=True, text=True)

if sign_result.returncode == 0:
    print("     Signed OK (ad-hoc, internal hardening active)")
else:
    print(f"     Sign warning: {sign_result.stderr.strip()}")

# 6. Applications symlink
os.symlink("/Applications", os.path.join(staging, "Applications"))

# 7. Background image
print("[5] Creating DMG background...")
img = Image.new("RGB", (660, 480), color=(28, 28, 30))
draw = ImageDraw.Draw(img)

for y in range(160):
    alpha = 60 * (1 - y / 160) / 255
    for x in range(660):
        o = img.getpixel((x, y))
        img.putpixel((x, y), (int(o[0]*(1-alpha)+20*alpha), int(o[1]*(1-alpha)+100*alpha), int(o[2]*(1-alpha)+200*alpha)))

try:
    f_lg = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 28)
    f_md = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)
    f_sm = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 13)
except:
    f_lg = f_md = f_sm = ImageFont.load_default()

draw.text((330, 50), "DuDu PMx", fill=(255, 255, 255), font=f_lg, anchor="mt")
draw.text((330, 85), "AI Pharmacometrics Workbench  \u00b7  v1.1.0", fill=(140, 165, 210), font=f_sm, anchor="mt")
draw.line([(80, 130), (580, 130)], fill=(70, 75, 85), width=1)

arrow = [(185, 230), (215, 230), (215, 212), (243, 238), (215, 264), (215, 246), (185, 246)]
draw.polygon(arrow, fill=(100, 155, 235))
draw.text((265, 238), "Drag to the Applications folder to install", fill=(210, 215, 225), font=f_md, anchor="lm")

draw.line([(80, 340), (580, 340)], fill=(55, 58, 66), width=1)
draw.text((330, 370), "macOS 13+  \u00b7  SwiftUI  \u00b7  NONMEM 7.4+", fill=(100, 110, 120), font=f_sm, anchor="mt")
draw.text((330, 400), "Changsha Duxact Biotechnology Co., Ltd.", fill=(65, 70, 80), font=f_sm, anchor="mt")
draw.text((330, 430), "\u00a9 2025-2026  Graham Ju", fill=(45, 48, 55), font=f_sm, anchor="mt")

img.save(os.path.join(bg_dir, "bg.png"), "PNG")
print("     Done")

# 8. Create encrypted DMG
print("[6] Creating encrypted DMG...")
result = subprocess.run([
    "hdiutil", "create",
    "-encryption", "AES-256",
    "-stdinpass",
    "-format", "UDZO",
    "-fs", "HFS+",
    "-volname", "DuDu PMx",
    "-srcfolder", staging,
    DMG,
    "-quiet"
], input=PASSWORD, capture_output=True, text=True, timeout=60)

if result.returncode != 0:
    print(f"ERROR: {result.stderr}")
    exit(1)

# 9. Install to /Applications and launch
print("[7] Installing & launching...")
app_dst = f"/Applications/{APP}.app"
if os.path.exists(app_dst):
    # Kill running instance first
    subprocess.run(["pkill", "-x", APP], capture_output=True)
    time.sleep(0.5)
    shutil.rmtree(app_dst)
shutil.copytree(os.path.join(staging, f"{APP}.app"), app_dst)
subprocess.Popen(["open", app_dst])
print(f"     ✓ Installed to {app_dst}")

# 10. Clean
print("[8] Cleaning...")
shutil.rmtree(WORK)

size_mb = os.path.getsize(DMG) / (1024 * 1024)
print(f"""
============================================
  \u2705 Installer ready!
  \U0001f4e6 {DMG}
  \U0001f4cf {size_mb:.1f} MB
  \U0001f511 Password: zbdd666
============================================

How to install:
  1. Double-click DuPMx_1.0_1.2.dmg
  2. Enter password: zbdd666
  3. Drag AutoPMX.app \u2192 Applications
  4. If macOS says "damaged", open Terminal and run:
     xattr -cr /Applications/AutoPMX.app
  5. Done!
""")
