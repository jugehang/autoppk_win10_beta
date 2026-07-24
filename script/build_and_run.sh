#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="AutoPMX"
BUNDLE="$ROOT/dist/$APP_NAME.app"
BINARY="$ROOT/.build/debug/$APP_NAME"

cd "$ROOT"

pkill -x "$APP_NAME" 2>/dev/null || true
sleep 0.5
swift build

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

cp "$BINARY" "$BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$BUNDLE/Contents/MacOS/$APP_NAME"
if [[ -f "$ROOT/Resources/AutoPMX.icns" ]]; then
  cp "$ROOT/Resources/AutoPMX.icns" "$BUNDLE/Contents/Resources/AutoPMX.icns"
fi
if [[ -f "$ROOT/Resources/DuDuPMxSource.png" ]]; then
  cp "$ROOT/Resources/DuDuPMxSource.png" "$BUNDLE/Contents/Resources/DuDuPMxSource.png"
fi
if [[ -f "$ROOT/Resources/DuDuPMxButton.png" ]]; then
  cp "$ROOT/Resources/DuDuPMxButton.png" "$BUNDLE/Contents/Resources/DuDuPMxButton.png"
fi
if [[ -f "$ROOT/Resources/Help.html" ]]; then
  cp "$ROOT/Resources/Help.html" "$BUNDLE/Contents/Resources/Help.html"
fi
if [[ -f "$ROOT/Resources/autopmx_ga.py" ]]; then
  cp "$ROOT/Resources/autopmx_ga.py" "$BUNDLE/Contents/Resources/autopmx_ga.py"
fi
# Rule library files
for rule in poppk_rules.json poppk_model_library.md PopPK_Expert_Audit_Report.md "NONMEM_RULE_KNOWLEDGE_AUDIT_20260512.md" "pk parameters script.R"; do
  if [[ -f "$ROOT/Resources/$rule" ]]; then
    cp "$ROOT/Resources/$rule" "$BUNDLE/Contents/Resources/$rule"
  fi
done
# Core diagnostic scripts
cp "$ROOT/Resources/dose_normalized_ct_plot.R" "$BUNDLE/Contents/Resources/dose_normalized_ct_plot.R"
for script in autopmx_cli.py Auto_diagnostics.py gof_audit_agent.py gof_plot_script.R \
    "individual_plot_script.R" "individual plot.R" LST_script.R "model fit agent_lst_pk parameters.py" \
    model_eval_mod41.R model_generator.py mod_validator.py pop_agent.py poppk_model_templates.py \
    pydarwin_optimizer.py vpc_audit_agent.py vpc_plot_script.R vpc_plot_script.R.py \
    workbench_core.py audit_tasks.py autompmx_workbench.py; do
  if [[ -f "$ROOT/Resources/$script" ]]; then
    cp "$ROOT/Resources/$script" "$BUNDLE/Contents/Resources/$script"
  fi
done

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
  <key>CFBundleIconFile</key>
  <string>AutoPMX</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

# Install to /Applications first, then open (without -n so it reuses the instance)
if [[ -d "/Applications/$APP_NAME.app" ]]; then
  # Update in-place instead of removing (keeps the same bundle identity)
  rsync -a --delete "$BUNDLE/" "/Applications/$APP_NAME.app/"
else
  cp -R "$BUNDLE" "/Applications/$APP_NAME.app"
fi
echo "✓ Installed to /Applications/$APP_NAME.app"

open "/Applications/$APP_NAME.app"

if [[ "${1:-}" == "--verify" ]]; then
  sleep 2
  pgrep -x "$APP_NAME" >/dev/null
  echo "$APP_NAME launched"
fi
