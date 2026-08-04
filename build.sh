#!/bin/sh
# AutoPMX build helper.
# The sandbox shell ships with a stripped PATH, so swift/codesign and other
# Xcode/CLT tools aren't found. We restore a sane PATH here and delegate to
# `swift build` — no absolute tool paths needed by the caller.
#
# Usage:
#   ./build.sh            # debug build
#   ./build.sh release    # optimized build
#   ./build.sh <any swift args...>

# Restore common system + Xcode Command Line Tools paths.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/Library/Developer/CommandLineTools/usr/bin:/Applications/Xcode.app/Contents/Developer/usr/bin:$PATH"

# If the user passed "release" as the first arg, map it to the release config.
if [ "$1" = "release" ]; then
    shift
    set -- --configuration release "$@"
fi

cd "$(dirname "$0")" || exit 1

# Sync the LLM rule/knowledge files into the SwiftPM resource directory so the
# built app bundles them. Without this, rule loading depends on an external
# PopPK_Agent directory existing on disk. Source of truth stays at ./Resources.
RULE_FILES="poppk_rules.json poppk_model_library.md PopPK_Expert_Audit_Report.md NONMEM_RULE_KNOWLEDGE_AUDIT_20260512.md"
for rf in $RULE_FILES; do
    if [ -f "Resources/$rf" ]; then
        cp -f "Resources/$rf" "Sources/AutoPMX/Resources/$rf"
    fi
done

exec swift build "$@"
