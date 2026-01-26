#!/bin/bash
# ============================================================================
# ENTITLEMENTS SEAL GENERATOR (Phase 13J)
#
# Extracts entitlements from the built app and computes SHA256.
# Run after code signing or at archive time.
#
# Usage: ./generate_entitlements_seal.sh <app_path> <output_path>
# ============================================================================

set -e

APP_PATH="${1:-$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app}"
OUTPUT_PATH="${2:-$SRCROOT/OperatorKit/Resources/Seals/ENTITLEMENTS_SEAL.txt}"

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

echo "Generating entitlements seal for: $APP_PATH"

# Extract entitlements using codesign
ENTITLEMENTS_TMP=$(mktemp)
codesign -d --entitlements :- "$APP_PATH" > "$ENTITLEMENTS_TMP" 2>/dev/null || true

# Check if entitlements were extracted
if [ ! -s "$ENTITLEMENTS_TMP" ]; then
    echo "Warning: No entitlements found, using empty file"
    echo "" > "$ENTITLEMENTS_TMP"
fi

# Compute SHA256 of entitlements
ENTITLEMENTS_HASH=$(shasum -a 256 "$ENTITLEMENTS_TMP" | cut -d' ' -f1)

# Count entitlement keys (rough count of keys in plist)
ENTITLEMENT_COUNT=$(grep -c "<key>" "$ENTITLEMENTS_TMP" 2>/dev/null || echo "0")

# Check for sandbox
SANDBOX_ENABLED=$(grep -q "app-sandbox" "$ENTITLEMENTS_TMP" && echo "true" || echo "false")

# Check for network client
NETWORK_REQUESTED=$(grep -q "network.client" "$ENTITLEMENTS_TMP" && echo "true" || echo "false")

# Get current date (day-rounded)
GENERATED_DATE=$(date -u +"%Y-%m-%d")

# Write seal file
cat > "$OUTPUT_PATH" << EOF
$ENTITLEMENTS_HASH
schemaVersion=1
entitlementCount=$ENTITLEMENT_COUNT
sandboxEnabled=$SANDBOX_ENABLED
networkClientRequested=$NETWORK_REQUESTED
generated=$GENERATED_DATE
EOF

# Cleanup
rm -f "$ENTITLEMENTS_TMP"

echo "Entitlements seal written to: $OUTPUT_PATH"
echo "Hash: $ENTITLEMENTS_HASH"
