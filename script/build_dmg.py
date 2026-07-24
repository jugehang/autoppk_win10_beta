#!/usr/bin/env python3
"""AutoPMX DMG Installer Builder"""

import os, subprocess, shutil
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.expanduser("/Users/grahamju/AutoPMX_clean")
WORK = os.path.join(ROOT, ".build/dmginst")
DMG = os.path.join(ROOT, "AutoPMX_Installer.dmg")
PASSWORD = "jugehang520"
APP = "AutoPMX"

# 1. Clean
print("[1] Cleaning...")
if os.path.exists(WORK): shutil.rmtree(WORK)
if os.path.exists(DMG): os.remove(DMG)

staging = os.path.join(WORK, "staging")
app_cont = os.path.join(staging, f"{APP}.app/Contents")
os.makedirs(os.path.join(app_cont, "MacOS"))
os.makedirs(os.path.join(app_cont, "Resources"))
bg_dir = os.path.join(staging, ".background")
os.makedirs(bg_dir)

# 2. Copy binary + resources
print("[2] Copying app...")
shutil.copy2(os.path.join(ROOT, ".build/debug", APP), os.path.join(app_cont, "MacOS", APP))
os.chmod(os.path.join(app_cont, "MacOS", APP), 0o755)

resource_files = [
    "AutoPMX.icns", "DuDuPMxButton.png", "DuDuPMxSource.png",
    "Help.html",
    # Rule libraries
    "poppk_rules.json", "poppk_model_library.md",
    "PopPK_Expert_Audit_Report.md", "NONMEM_RULE_KNOWLEDGE_AUDIT_20260512.md",
    # Core scripts (Python + R)
    "autopmx_cli.py", "autopmx_ga.py", "Auto_diagnostics.py",
    "gof_audit_agent.py", "gof_plot_script.R",
    "individual_plot_script.R", "individual plot.R",
    "LST_script.R", "model fit agent_lst_pk parameters.py",
    "model_eval_mod41.R", "model_generator.py",
    "mod_validator.py", "pk parameters script.R",
    "pop_agent.py", "poppk_model_templates.py",
    "pydarwin_optimizer.py", "vpc_audit_agent.py",
    "vpc_plot_script.R", "vpc_plot_script.R.py",
    "workbench_core.py", "audit_tasks.py", "autompmx_workbench.py",
    # CT analysis
    "dose_normalized_ct_plot.R",
]
for f in resource_files:
    src = os.path.join(ROOT, "Resources", f)
    if os.path.exists(src): shutil.copy2(src, os.path.join(app_cont, "Resources", f))

# 3. Info.plist
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
  <key>CFBundleVersion</key><string>1.1</string>
  <key>CFBundleShortVersionString</key><string>1.1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>"""
with open(os.path.join(app_cont, "Info.plist"), "w") as f: f.write(plist)

# 4. Ad-hoc codesign to prevent Gatekeeper damage
print("[3.5] Code-signing app...")
codesign = subprocess.run([
    "codesign", "--force", "--deep", "--sign", "-",
    os.path.join(staging, f"{APP}.app")
], capture_output=True, text=True)
if codesign.returncode == 0:
    print("     Signed OK")
else:
    print(f"     Sign warning: {codesign.stderr.strip()}")

# 5. Applications symlink
os.symlink("/Applications", os.path.join(staging, "Applications"))

# 5. Background image
print("[3] Creating background image...")
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
draw.text((330, 85), "AI Pharmacometrics Workbench  \u00b7  v1.1", fill=(140, 165, 210), font=f_sm, anchor="mt")
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

# 6. Create encrypted DMG with printf (NO trailing newline)
print("[4] Creating encrypted DMG...")
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

# 7. Clean
print("[5] Cleaning...")
shutil.rmtree(WORK)

size_mb = os.path.getsize(DMG) / (1024 * 1024)
print(f"""
============================================
  \u2705 Installer ready!
  \U0001f4e6 {DMG}
  \U0001f4cf {size_mb:.1f} MB
  \U0001f511 Password: jugehang520
============================================

How to install:
  1. Double-click AutoPMX_Installer.dmg
  2. Enter password: jugehang520
  3. Drag AutoPMX.app \u2192 Applications
  4. If macOS says "damaged", open Terminal and run:
     xattr -cr /Applications/AutoPMX.app
  5. Done!
""")
