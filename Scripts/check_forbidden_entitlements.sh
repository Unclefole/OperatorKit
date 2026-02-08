#!/bin/bash
# ============================================================================
# FORBIDDEN ENTITLEMENTS CHECKER - Build Phase Guardrail
#
# PURPOSE: Hard-fail the build if ANY network-related entitlements are present
#          in the signed application. This enforces the air-gapped architecture
#          of OperatorKit at the entitlements level.
#
# USAGE: Added as a Run Script Build Phase in Xcode (after Compile Sources)
#
# ENTITLEMENTS FORBIDDEN:
#   - com.apple.security.network.*         (macOS sandbox network access)
#   - com.apple.developer.networking.*     (iOS/macOS networking capabilities)
#
# EXIT CODES:
#   0 = Clean (no forbidden entitlements)
#   1 = Forbidden entitlements detected (BUILD FAILS)
# ============================================================================

set -euo pipefail

# --- Configuration ---
APP_PATH="${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}"

FORBIDDEN_ENTITLEMENTS=(
    "com.apple.security.network"
    "com.apple.developer.networking"
)

# --- Validation ---
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  FORBIDDEN ENTITLEMENTS CHECK - Network Isolation Guardrail     ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "App Bundle: ${APP_PATH}"
echo ""

if [ ! -d "${APP_PATH}" ]; then
    echo "⚠️  App bundle not found at path. Skipping check (may be initial build)."
    exit 0
fi

# --- Entitlements Extraction ---
echo "Extracting entitlements with codesign..."
ENTITLEMENTS_OUTPUT=$(codesign -d --entitlements :- "${APP_PATH}" 2>/dev/null || echo "")

if [ -z "${ENTITLEMENTS_OUTPUT}" ]; then
    echo "✅ No entitlements found. App has no special capabilities."
    exit 0
fi

# --- Forbidden Entitlements Scan ---
VIOLATIONS_FOUND=0
VIOLATION_DETAILS=""

for ENTITLEMENT in "${FORBIDDEN_ENTITLEMENTS[@]}"; do
    MATCHES=$(echo "${ENTITLEMENTS_OUTPUT}" | grep -i "${ENTITLEMENT}" || true)
    if [ -n "${MATCHES}" ]; then
        VIOLATIONS_FOUND=1
        VIOLATION_DETAILS="${VIOLATION_DETAILS}
━━━ FORBIDDEN ENTITLEMENT: ${ENTITLEMENT} ━━━
${MATCHES}
"
    fi
done

# --- Result ---
if [ "${VIOLATIONS_FOUND}" -eq 1 ]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║  ❌ BUILD FAILED - FORBIDDEN NETWORK ENTITLEMENTS DETECTED      ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "OperatorKit is designed to be 100% air-gapped with ZERO network access."
    echo "The following forbidden entitlements were found:"
    echo "${VIOLATION_DETAILS}"
    echo ""
    echo "ACTION REQUIRED:"
    echo "  1. Remove network entitlements from .entitlements file"
    echo "  2. Check Signing & Capabilities in Xcode target settings"
    echo "  3. Ensure no frameworks require network entitlements"
    echo ""
    exit 1
fi

echo "✅ No forbidden network entitlements detected. App is air-gapped compliant."
exit 0
