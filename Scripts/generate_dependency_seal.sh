#!/bin/bash
# ============================================================================
# DEPENDENCY SEAL GENERATOR (Phase 13J)
#
# Reads Package.resolved and computes deterministic fingerprint.
# Run during CI/build process.
#
# Usage: ./generate_dependency_seal.sh [project_root] [output_path]
# ============================================================================

set -e

PROJECT_ROOT="${1:-$SRCROOT}"
OUTPUT_PATH="${2:-$PROJECT_ROOT/OperatorKit/Resources/Seals/DEPENDENCY_SEAL.txt}"

# Find Package.resolved
RESOLVED_PATH=""
if [ -f "$PROJECT_ROOT/Package.resolved" ]; then
    RESOLVED_PATH="$PROJECT_ROOT/Package.resolved"
elif [ -f "$PROJECT_ROOT/*.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" ]; then
    RESOLVED_PATH=$(ls "$PROJECT_ROOT"/*.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved 2>/dev/null | head -1)
elif [ -f "$PROJECT_ROOT/OperatorKit.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" ]; then
    RESOLVED_PATH="$PROJECT_ROOT/OperatorKit.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
fi

echo "Generating dependency seal..."

LOCKFILE_PRESENT="false"
DEPENDENCY_COUNT=0
TRANSITIVE_COUNT=0
DEPENDENCY_HASH=""

if [ -n "$RESOLVED_PATH" ] && [ -f "$RESOLVED_PATH" ]; then
    LOCKFILE_PRESENT="true"
    echo "Found Package.resolved at: $RESOLVED_PATH"
    
    # Extract package identities and versions, normalize and sort
    NORMALIZED_LIST=$(mktemp)
    
    # Parse JSON and extract package info (simplified parsing)
    # Format: identity@version@revision
    if command -v python3 &> /dev/null; then
        python3 << PYTHON > "$NORMALIZED_LIST"
import json
import sys

try:
    with open("$RESOLVED_PATH", "r") as f:
        data = json.load(f)
    
    pins = []
    
    # Handle different Package.resolved formats
    if "pins" in data:
        # Version 2 format
        for pin in data["pins"]:
            identity = pin.get("identity", "unknown")
            state = pin.get("state", {})
            version = state.get("version", state.get("revision", "unknown"))[:16]
            pins.append(f"{identity}@{version}")
    elif "object" in data and "pins" in data["object"]:
        # Version 1 format
        for pin in data["object"]["pins"]:
            identity = pin.get("package", "unknown")
            state = pin.get("state", {})
            version = state.get("version", state.get("revision", "unknown"))[:16]
            pins.append(f"{identity}@{version}")
    
    # Sort for determinism
    for p in sorted(pins):
        print(p)

except Exception as e:
    print(f"# Error: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON
    else
        # Fallback: just hash the raw file
        cat "$RESOLVED_PATH" | sort > "$NORMALIZED_LIST"
    fi
    
    # Count dependencies
    DEPENDENCY_COUNT=$(wc -l < "$NORMALIZED_LIST" | tr -d ' ')
    TRANSITIVE_COUNT=$DEPENDENCY_COUNT
    
    # Compute SHA256 of normalized list
    DEPENDENCY_HASH=$(shasum -a 256 "$NORMALIZED_LIST" | cut -d' ' -f1)
    
    rm -f "$NORMALIZED_LIST"
else
    echo "Warning: Package.resolved not found"
    # Generate deterministic placeholder hash
    DEPENDENCY_HASH=$(echo "no-dependencies" | shasum -a 256 | cut -d' ' -f1)
fi

# Get current date
GENERATED_DATE=$(date -u +"%Y-%m-%d")

# Write seal file
cat > "$OUTPUT_PATH" << EOF
$DEPENDENCY_HASH
schemaVersion=1
dependencyCount=$DEPENDENCY_COUNT
transitiveDependencyCount=$TRANSITIVE_COUNT
lockfilePresent=$LOCKFILE_PRESENT
generated=$GENERATED_DATE
EOF

echo "Dependency seal written to: $OUTPUT_PATH"
echo "Hash: $DEPENDENCY_HASH"
echo "Dependencies: $DEPENDENCY_COUNT"
