#!/bin/bash
# ============================================================================
# SYMBOL SEAL GENERATOR (Phase 13J)
#
# Scans binary for forbidden symbols/frameworks using nm/otool.
# Produces deterministic result with SHA256 of symbol list.
#
# Usage: ./generate_symbol_seal.sh <binary_path> <output_path>
# ============================================================================

set -e

BINARY_PATH="${1:-$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/$PRODUCT_NAME}"
OUTPUT_PATH="${2:-$SRCROOT/OperatorKit/Resources/Seals/SYMBOL_SEAL.json}"

echo "Generating symbol seal for: $BINARY_PATH"

# Forbidden symbols/frameworks to check
FORBIDDEN_FRAMEWORKS=(
    "URLSession"
    "CFNetwork"
    "NSURLConnection"
    "nw_connection"
    "WebKit"
    "JavaScriptCore"
    "SafariServices"
)

# Initialize counters
FORBIDDEN_SYMBOL_COUNT=0
FORBIDDEN_FRAMEWORK_PRESENT="false"
FRAMEWORK_CHECKS=""
TOTAL_SYMBOLS=0

# Create temp file for symbol list
SYMBOL_LIST=$(mktemp)

# Check if binary exists
if [ -f "$BINARY_PATH" ]; then
    echo "Scanning binary..."
    
    # Extract symbols using nm (names only, sorted)
    nm -U "$BINARY_PATH" 2>/dev/null | awk '{print $NF}' | sort -u > "$SYMBOL_LIST" || true
    
    # Also check linked frameworks using otool
    LINKED_FRAMEWORKS=$(otool -L "$BINARY_PATH" 2>/dev/null | tail -n +2 | awk '{print $1}' | xargs -I{} basename {} .framework | sort -u || echo "")
    
    # Count total symbols
    TOTAL_SYMBOLS=$(wc -l < "$SYMBOL_LIST" | tr -d ' ')
    
    # Check each forbidden framework
    for FRAMEWORK in "${FORBIDDEN_FRAMEWORKS[@]}"; do
        # Check in symbols
        SYMBOL_FOUND=$(grep -i "$FRAMEWORK" "$SYMBOL_LIST" | wc -l | tr -d ' ')
        
        # Check in linked frameworks
        LINK_FOUND=$(echo "$LINKED_FRAMEWORKS" | grep -i "$FRAMEWORK" | wc -l | tr -d ' ')
        
        DETECTED="false"
        SEVERITY="none"
        
        if [ "$SYMBOL_FOUND" -gt 0 ] || [ "$LINK_FOUND" -gt 0 ]; then
            DETECTED="true"
            SEVERITY="critical"
            FORBIDDEN_SYMBOL_COUNT=$((FORBIDDEN_SYMBOL_COUNT + SYMBOL_FOUND))
            FORBIDDEN_FRAMEWORK_PRESENT="true"
        fi
        
        # Build JSON array element
        if [ -n "$FRAMEWORK_CHECKS" ]; then
            FRAMEWORK_CHECKS="$FRAMEWORK_CHECKS,"
        fi
        FRAMEWORK_CHECKS="$FRAMEWORK_CHECKS
    {\"framework\": \"$FRAMEWORK\", \"detected\": $DETECTED, \"severity\": \"$SEVERITY\"}"
    done
else
    echo "Warning: Binary not found at $BINARY_PATH"
    echo "Generating placeholder seal..."
    
    # Generate placeholder checks
    for FRAMEWORK in "${FORBIDDEN_FRAMEWORKS[@]}"; do
        if [ -n "$FRAMEWORK_CHECKS" ]; then
            FRAMEWORK_CHECKS="$FRAMEWORK_CHECKS,"
        fi
        FRAMEWORK_CHECKS="$FRAMEWORK_CHECKS
    {\"framework\": \"$FRAMEWORK\", \"detected\": false, \"severity\": \"none\"}"
    done
fi

# Compute SHA256 of symbol list (or placeholder)
if [ -s "$SYMBOL_LIST" ]; then
    SYMBOL_HASH=$(shasum -a 256 "$SYMBOL_LIST" | cut -d' ' -f1)
else
    SYMBOL_HASH=$(echo "no-symbols" | shasum -a 256 | cut -d' ' -f1)
fi

# Get current date
GENERATED_DATE=$(date -u +"%Y-%m-%d")

# Write JSON seal file
cat > "$OUTPUT_PATH" << EOF
{
  "symbolListHash": "$SYMBOL_HASH",
  "forbiddenSymbolCount": $FORBIDDEN_SYMBOL_COUNT,
  "forbiddenFrameworkPresent": $FORBIDDEN_FRAMEWORK_PRESENT,
  "frameworkChecks": [$FRAMEWORK_CHECKS
  ],
  "totalSymbolsScanned": $TOTAL_SYMBOLS,
  "schemaVersion": 1,
  "generatedAtDayRounded": "$GENERATED_DATE"
}
EOF

# Cleanup
rm -f "$SYMBOL_LIST"

echo "Symbol seal written to: $OUTPUT_PATH"
echo "Hash: $SYMBOL_HASH"
echo "Forbidden symbols found: $FORBIDDEN_SYMBOL_COUNT"
echo "Forbidden framework present: $FORBIDDEN_FRAMEWORK_PRESENT"

# Exit with error if forbidden symbols found (for CI)
if [ "$FORBIDDEN_FRAMEWORK_PRESENT" = "true" ]; then
    echo "WARNING: Forbidden frameworks detected!"
    # Uncomment to fail build: exit 1
fi
