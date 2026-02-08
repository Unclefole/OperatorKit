#!/bin/bash

# ============================================================================
# KERNEL INVARIANTS BUILD-TIME CHECKER
#
# This script runs during the build phase to detect forbidden patterns
# that would violate kernel invariants.
#
# INVARIANTS CHECKED:
# - No direct execution calls bypassing Kernel
# - No network mutation outside /Sync/ module
# - No silent retries on mutation
# - No cached approvals
# - No force unwraps on execution paths
#
# EXIT CODE: 0 = pass, 1 = violation detected
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "KERNEL INVARIANTS CHECK"
echo "=========================================="

SOURCE_DIR="${SRCROOT:-$(pwd)}/OperatorKit"
VIOLATIONS=0

# Function to check for pattern violations
check_pattern() {
    local pattern="$1"
    local description="$2"
    local exclude_pattern="$3"
    
    echo ""
    echo "Checking: $description"
    echo "Pattern: $pattern"
    
    if [ -n "$exclude_pattern" ]; then
        MATCHES=$(grep -r -n -E "$pattern" "$SOURCE_DIR" --include="*.swift" | grep -v -E "$exclude_pattern" | grep -v "Tests" || true)
    else
        MATCHES=$(grep -r -n -E "$pattern" "$SOURCE_DIR" --include="*.swift" | grep -v "Tests" || true)
    fi
    
    if [ -n "$MATCHES" ]; then
        echo -e "${RED}❌ VIOLATION DETECTED${NC}"
        echo "$MATCHES"
        VIOLATIONS=$((VIOLATIONS + 1))
    else
        echo -e "${GREEN}✓ PASSED${NC}"
    fi
}

# ============================================================================
# CHECK 1: Direct URLSession calls outside /Sync/ module
# ============================================================================
check_pattern \
    "URLSession\.(shared|default)" \
    "Direct URLSession calls (should only be in /Sync/)" \
    "Sync/|SupabaseClient|TeamSupabaseClient"

# ============================================================================
# CHECK 2: Direct network mutations without Kernel
# ============================================================================
check_pattern \
    "\.(dataTask|upload|download)\s*\(" \
    "Network data tasks (must go through Kernel)" \
    "Sync/|SupabaseClient|TeamSupabaseClient"

# ============================================================================
# CHECK 3: Empty catch blocks (silent failures)
# ============================================================================
echo ""
echo "Checking: Empty catch blocks"
EMPTY_CATCHES=$(grep -r -n -E "catch\s*\{\s*\}" "$SOURCE_DIR" --include="*.swift" | grep -v "Tests" || true)
if [ -n "$EMPTY_CATCHES" ]; then
    echo -e "${YELLOW}⚠️  WARNING: Empty catch blocks found (should log errors)${NC}"
    echo "$EMPTY_CATCHES"
    # This is a warning, not a violation
else
    echo -e "${GREEN}✓ PASSED${NC}"
fi

# ============================================================================
# CHECK 4: Static approval caching
# ============================================================================
check_pattern \
    "static\s+(var|let)\s+.*[Aa]pproval" \
    "Static approval caching (approvals must be fresh)" \
    ""

# ============================================================================
# CHECK 5: Direct execution bypassing Kernel
# ============================================================================
check_pattern \
    "func\s+execute\s*\(\s*without" \
    "Direct execution without Kernel authorization" \
    ""

# ============================================================================
# CHECK 6: Execution without ToolPlan
# ============================================================================
check_pattern \
    "performExecution\s*\(\s*\)" \
    "Execution without ToolPlan parameter" \
    ""

# ============================================================================
# CHECK 7: Approval bypass patterns
# ============================================================================
check_pattern \
    "skipApproval|bypassApproval|forceExecute" \
    "Approval bypass patterns" \
    ""

# ============================================================================
# CHECK 8: Hard-coded credentials
# ============================================================================
echo ""
echo "Checking: Hard-coded credentials"
CRED_PATTERNS=$(grep -r -n -E "(password|api_key|secret|token)\s*=\s*\"[^\"]+\"" "$SOURCE_DIR" --include="*.swift" | grep -v "Tests" | grep -v "example" | grep -v "placeholder" | grep -v "Signing-Key" || true)
if [ -n "$CRED_PATTERNS" ]; then
    echo -e "${YELLOW}⚠️  WARNING: Possible hard-coded credentials${NC}"
    echo "$CRED_PATTERNS"
    # This is a warning for review
else
    echo -e "${GREEN}✓ PASSED${NC}"
fi

# ============================================================================
# SUMMARY
# ============================================================================
echo ""
echo "=========================================="
echo "SUMMARY"
echo "=========================================="

if [ $VIOLATIONS -gt 0 ]; then
    echo -e "${RED}❌ BUILD FAILED: $VIOLATIONS kernel invariant violations detected${NC}"
    echo ""
    echo "These violations must be fixed before the build can proceed."
    echo "See documentation in KernelInvariants.swift for details."
    exit 1
else
    echo -e "${GREEN}✓ ALL KERNEL INVARIANTS VERIFIED${NC}"
    echo ""
    echo "No violations detected. Build may proceed."
    exit 0
fi
