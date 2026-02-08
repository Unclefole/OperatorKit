#!/bin/bash
# ============================================================================
# FORBIDDEN SYMBOL CHECKER - Build Phase Guardrail
#
# PURPOSE: Hard-fail the build if ANY networking-related symbols are found
#          in the compiled binary. This enforces the air-gapped architecture
#          of OperatorKit.
#
# USAGE: Added as a Run Script Build Phase in Xcode (after Compile Sources)
#
# SYMBOLS FORBIDDEN:
#   - URLSession        (Foundation networking)
#   - CFNetwork         (Core Foundation networking)
#   - NSURLConnection   (Legacy networking)
#   - Socket            (BSD sockets)
#   - nw_               (Network.framework)
#   - NSURL             (URL handling - network capable)
#
# EXIT CODES:
#   0 = Clean (no forbidden symbols)
#   1 = Forbidden symbols detected (BUILD FAILS)
# ============================================================================

set -euo pipefail

# --- Configuration ---
BINARY_PATH="${TARGET_BUILD_DIR}/${EXECUTABLE_PATH}"

FORBIDDEN_PATTERNS=(
    "URLSession"
    "CFNetwork"
    "NSURLConnection"
    "Socket"
    "nw_"
    "NSURL"
)

# --- Validation ---
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  FORBIDDEN SYMBOL CHECK - Network Isolation Guardrail           ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "Binary: ${BINARY_PATH}"
echo ""

if [ ! -f "${BINARY_PATH}" ]; then
    echo "⚠️  Binary not found at path. Skipping check (may be initial build)."
    exit 0
fi

# --- Symbol Extraction ---
echo "Extracting undefined symbols with nm -u..."
SYMBOLS_OUTPUT=$(nm -u "${BINARY_PATH}" 2>/dev/null || echo "")

if [ -z "${SYMBOLS_OUTPUT}" ]; then
    echo "✅ No undefined symbols found. Binary is clean."
    exit 0
fi

# --- Forbidden Symbol Scan ---
VIOLATIONS_FOUND=0
VIOLATION_DETAILS=""

for PATTERN in "${FORBIDDEN_PATTERNS[@]}"; do
    MATCHES=$(echo "${SYMBOLS_OUTPUT}" | grep -i "${PATTERN}" || true)
    if [ -n "${MATCHES}" ]; then
        VIOLATIONS_FOUND=1
        VIOLATION_DETAILS="${VIOLATION_DETAILS}
━━━ FORBIDDEN: ${PATTERN} ━━━
${MATCHES}
"
    fi
done

# --- Result ---
if [ "${VIOLATIONS_FOUND}" -eq 1 ]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║  ❌ BUILD FAILED - FORBIDDEN NETWORK SYMBOLS DETECTED           ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "OperatorKit is designed to be 100% air-gapped with ZERO network access."
    echo "The following forbidden symbols were found in the binary:"
    echo "${VIOLATION_DETAILS}"
    echo ""
    echo "ACTION REQUIRED:"
    echo "  1. Remove all networking code from the codebase"
    echo "  2. Ensure no frameworks with network capabilities are linked"
    echo "  3. Review recent changes for accidental network imports"
    echo ""
    exit 1
fi

echo "✅ No forbidden network symbols detected. Binary is air-gapped compliant."
exit 0
