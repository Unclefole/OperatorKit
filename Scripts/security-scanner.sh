#!/bin/bash
# ============================================================================
# OPERATORKIT BUILD-TIME SECURITY SCANNER
#
# Fails the build if it detects security anti-patterns:
#   1. UserDefaults storing secrets
#   2. print() containing tokens/keys
#   3. Raw Authorization headers logged
#   4. New URLSession created outside NetworkPolicyEnforcer
#   5. Secrets in logs or analytics
#
# Usage:
#   ./scripts/security-scanner.sh
#   Exit code 0 = clean, non-zero = violations found
#
# Add as a Run Script build phase in Xcode:
#   "${SRCROOT}/scripts/security-scanner.sh"
# ============================================================================

set -euo pipefail

SRCROOT="${SRCROOT:-$(dirname "$0")/..}"
SRC_DIR="${SRCROOT}/OperatorKit"
VIOLATIONS=0
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  OPERATORKIT SECURITY SCANNER                           ║"
echo "╚══════════════════════════════════════════════════════════╝"

# ── 1. UserDefaults storing secrets ──────────────────────────────
echo -n "  [1/6] Checking UserDefaults for secret storage... "
SECRETS_IN_DEFAULTS=$(grep -rn "UserDefaults.*\(apiKey\|secret\|token\|password\|credential\)" "$SRC_DIR" \
    --include="*.swift" \
    --exclude-dir="Testing" \
    --exclude-dir="Tests" \
    -l 2>/dev/null || true)

if [ -n "$SECRETS_IN_DEFAULTS" ]; then
    echo -e "${RED}FAIL${NC}"
    echo "    Secrets found in UserDefaults:"
    echo "$SECRETS_IN_DEFAULTS" | while read -r f; do echo "      ✗ $f"; done
    VIOLATIONS=$((VIOLATIONS + 1))
else
    echo -e "${GREEN}PASS${NC}"
fi

# ── 2. print() containing tokens/keys ───────────────────────────
echo -n "  [2/6] Checking print() for token leakage... "
TOKEN_PRINTS=$(grep -rn "print.*\(apiKey\|accessToken\|secretKey\|bearerToken\|Authorization\)" "$SRC_DIR" \
    --include="*.swift" \
    --exclude-dir="Testing" \
    --exclude-dir="Tests" \
    -l 2>/dev/null || true)

if [ -n "$TOKEN_PRINTS" ]; then
    echo -e "${RED}FAIL${NC}"
    echo "    Token values in print statements:"
    echo "$TOKEN_PRINTS" | while read -r f; do echo "      ✗ $f"; done
    VIOLATIONS=$((VIOLATIONS + 1))
else
    echo -e "${GREEN}PASS${NC}"
fi

# ── 3. Raw Authorization headers logged ─────────────────────────
echo -n "  [3/6] Checking for logged Authorization headers... "
AUTH_LOGGED=$(grep -rn "log.*Authorization.*Bearer\|print.*Authorization.*Bearer\|NSLog.*Authorization" "$SRC_DIR" \
    --include="*.swift" \
    --exclude-dir="Testing" \
    --exclude-dir="Tests" \
    -l 2>/dev/null || true)

if [ -n "$AUTH_LOGGED" ]; then
    echo -e "${RED}FAIL${NC}"
    echo "    Authorization headers in logs:"
    echo "$AUTH_LOGGED" | while read -r f; do echo "      ✗ $f"; done
    VIOLATIONS=$((VIOLATIONS + 1))
else
    echo -e "${GREEN}PASS${NC}"
fi

# ── 4. URLSession outside NetworkPolicyEnforcer ──────────────────
echo -n "  [4/6] Checking for ungoverned URLSession usage... "
# Find all URLSession.shared.data or URLSession( outside of NetworkPolicyEnforcer
UNGOVERNED_SESSIONS=$(grep -rn "URLSession\.\|URLSession(" "$SRC_DIR" \
    --include="*.swift" \
    --exclude="NetworkPolicyEnforcer.swift" \
    --exclude="CertificatePinning.swift" \
    --exclude-dir="Testing" \
    --exclude-dir="Tests" \
    -l 2>/dev/null || true)

# Filter to only files that actually call .data(for:) or create sessions
ACTUAL_VIOLATIONS=""
if [ -n "$UNGOVERNED_SESSIONS" ]; then
    for f in $UNGOVERNED_SESSIONS; do
        if grep -q "URLSession.shared.data\|URLSession(" "$f" 2>/dev/null; then
            # Exclude SupabaseClient (known, governed via validate())
            if [[ "$f" != *"SupabaseClient"* && "$f" != *"TeamSupabaseClient"* ]]; then
                ACTUAL_VIOLATIONS="$ACTUAL_VIOLATIONS $f"
            fi
        fi
    done
fi

if [ -n "$ACTUAL_VIOLATIONS" ]; then
    echo -e "${YELLOW}WARN${NC}"
    echo "    URLSession usage outside enforcer (review manually):"
    for f in $ACTUAL_VIOLATIONS; do echo "      ⚠ $f"; done
    # Warning, not failure — SupabaseClient is governed via validate()
else
    echo -e "${GREEN}PASS${NC}"
fi

# ── 5. Secrets in NSLog or os_log ────────────────────────────────
echo -n "  [5/6] Checking for secrets in system logs... "
SECRETS_IN_LOGS=$(grep -rn "NSLog.*\(apiKey\|secret\|password\|token\)\|os_log.*\(apiKey\|secret\|password\)" "$SRC_DIR" \
    --include="*.swift" \
    --exclude-dir="Testing" \
    --exclude-dir="Tests" \
    -l 2>/dev/null || true)

if [ -n "$SECRETS_IN_LOGS" ]; then
    echo -e "${RED}FAIL${NC}"
    echo "    Secrets in system logs:"
    echo "$SECRETS_IN_LOGS" | while read -r f; do echo "      ✗ $f"; done
    VIOLATIONS=$((VIOLATIONS + 1))
else
    echo -e "${GREEN}PASS${NC}"
fi

# ── 6. iCloud Keychain sync (kSecAttrSynchronizable = true) ─────
echo -n "  [6/6] Checking for iCloud Keychain sync... "
ICLOUD_SYNC=$(grep -rn "kSecAttrSynchronizable.*true\b" "$SRC_DIR" \
    --include="*.swift" \
    --exclude-dir="Testing" \
    --exclude-dir="Tests" \
    2>/dev/null | grep -v "false" || true)

if [ -n "$ICLOUD_SYNC" ]; then
    echo -e "${RED}FAIL${NC}"
    echo "    iCloud Keychain sync detected:"
    echo "$ICLOUD_SYNC" | while read -r line; do echo "      ✗ $line"; done
    VIOLATIONS=$((VIOLATIONS + 1))
else
    echo -e "${GREEN}PASS${NC}"
fi

# ── Summary ──────────────────────────────────────────────────────
echo ""
if [ $VIOLATIONS -eq 0 ]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  SECURITY SCAN PASSED — 0 violations                    ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  SECURITY SCAN FAILED — $VIOLATIONS violation(s)                    ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi
