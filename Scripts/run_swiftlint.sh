#!/bin/bash
# ============================================================================
# SWIFTLINT BUILD PHASE SCRIPT
#
# Add this as a "Run Script" build phase in Xcode:
# 1. Select OperatorKit target
# 2. Build Phases → + → New Run Script Phase
# 3. Paste: "${SRCROOT}/Scripts/run_swiftlint.sh"
# 4. Move phase BEFORE "Compile Sources"
#
# RELIABILITY INVARIANT: This script enforces compile-time checks for:
# - Empty button actions (inert UI)
# - Empty tap gestures
# - Untagged TODOs
# ============================================================================

set -e

# Check if SwiftLint is installed
if which swiftlint >/dev/null; then
    echo "🔍 Running SwiftLint reliability checks..."

    # Run SwiftLint with config
    swiftlint lint --config "${SRCROOT}/.swiftlint.yml" --strict

    LINT_RESULT=$?

    if [ $LINT_RESULT -eq 0 ]; then
        echo "✅ SwiftLint: All reliability invariants passed"
    else
        echo "❌ SwiftLint: Reliability violations detected"
        echo ""
        echo "Common fixes:"
        echo "  - Empty Button: Wire navigation or use .disabled(true)"
        echo "  - Empty Gesture: Add handler or remove gesture"
        echo "  - TODO format: Use // TODO: [TAG]: Description"
        exit 1
    fi
else
    echo "⚠️ SwiftLint not installed. Install with: brew install swiftlint"
    echo "   Skipping reliability checks (CI will enforce)"
fi
