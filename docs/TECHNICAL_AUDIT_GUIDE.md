# TECHNICAL AUDIT GUIDE

**Document Type**: Reproduction Steps  
**Audience**: Security Auditors, Penetration Testers, DevSecOps  
**Reading Time**: 15 minutes  
**Phase**: L3

---

## Overview

This guide provides step-by-step reproduction instructions for every proof artifact in OperatorKit. All verifications can be performed independently using standard macOS/iOS development tools.

---

## Prerequisites

- macOS with Xcode installed
- Access to the built `.app` bundle (or IPA extracted)
- Terminal access
- Optional: Source code access for test verification

---

## 1. Entitlements Seal Verification

### What It Proves

The app's code signing entitlements match the sealed hash.

### Extraction Command

```bash
# Extract entitlements from the signed app
codesign -d --entitlements :- /path/to/OperatorKit.app > entitlements.plist

# View entitlements
cat entitlements.plist
```

### Expected Entitlements (Privacy-Focused Build)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <!-- Network client should be ABSENT unless sync enabled -->
</dict>
</plist>
```

### Hash Computation

```bash
# Compute SHA256 of entitlements
shasum -a 256 entitlements.plist

# Compare with Resources/Seals/ENTITLEMENTS_SEAL.txt
cat /path/to/OperatorKit.app/Contents/Resources/Seals/ENTITLEMENTS_SEAL.txt
```

### Key Check

```bash
# Verify no network.client entitlement (unless sync enabled)
grep -c "network.client" entitlements.plist
# Expected: 0 (or 1 if sync is explicitly enabled)
```

---

## 2. Dependency Seal Verification

### What It Proves

The SPM dependencies match the sealed fingerprint.

### Locate Package.resolved

```bash
# Xcode project
cat /path/to/project/OperatorKit.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

# Or standalone SPM
cat /path/to/project/Package.resolved
```

### Normalize and Hash

```bash
# Extract and normalize (using jq for version 2 format)
jq -r '.pins[] | "\(.identity)@\(.state.version // .state.revision)"' Package.resolved | sort > normalized_deps.txt

# Compute SHA256
shasum -a 256 normalized_deps.txt

# Compare with Resources/Seals/DEPENDENCY_SEAL.txt
```

### Manual Inspection

```bash
# List all dependencies
jq -r '.pins[].identity' Package.resolved | sort

# Expected: No unexpected network-related packages
```

---

## 3. Symbol Seal Verification

### What It Proves

The compiled binary contains no forbidden networking symbols.

### Extract Symbols

```bash
# Extract binary path (from .app bundle)
BINARY="/path/to/OperatorKit.app/OperatorKit"

# List all symbols
nm -U "$BINARY" | awk '{print $NF}' | sort -u > symbols.txt

# Count symbols
wc -l symbols.txt
```

### Check for Forbidden Symbols

```bash
# Search for networking symbols
grep -iE "urlsession|cfnetwork|nsurlconnection|nw_connection" symbols.txt

# Expected: No matches (or very few in system frameworks only)
```

### Check Linked Frameworks

```bash
# List linked frameworks
otool -L "$BINARY"

# Check for forbidden frameworks
otool -L "$BINARY" | grep -iE "webkit|javascriptcore|safariservices"

# Expected: No matches
```

### Compute Symbol Hash

```bash
# Hash the symbol list
shasum -a 256 symbols.txt

# Compare with Resources/Seals/SYMBOL_SEAL.json
cat /path/to/OperatorKit.app/Contents/Resources/Seals/SYMBOL_SEAL.json | jq '.symbolListHash'
```

---

## 4. Binary Proof Verification (Mach-O)

### What It Proves

WebKit, JavaScriptCore, and SafariServices are not linked at the Mach-O level.

### List All Linked Frameworks

```bash
otool -L "$BINARY" | tail -n +2 | awk '{print $1}'
```

### Specific Checks

```bash
# WebKit
otool -L "$BINARY" | grep -i webkit
# Expected: No matches

# JavaScriptCore
otool -L "$BINARY" | grep -i javascriptcore
# Expected: No matches

# SafariServices
otool -L "$BINARY" | grep -i safariservices
# Expected: No matches (or only if auth flows use SFSafariViewController)
```

### Dynamic Library Inspection

```bash
# List all dylibs
otool -L "$BINARY" | grep "\.dylib"

# Check for suspicious private frameworks
otool -L "$BINARY" | grep "PrivateFrameworks"
# Expected: None
```

---

## 5. Offline Certification Verification

### What It Proves

The Intent → Draft pipeline operates without network connectivity.

### In-App Verification

1. Open OperatorKit
2. Enable Airplane Mode on device
3. Navigate to: Settings → Trust Dashboard → Offline Certification
4. Tap "Verify Offline Status"
5. All checks should pass

### Test Suite Verification

```bash
# Run offline certification tests
xcodebuild test \
  -project OperatorKit.xcodeproj \
  -scheme OperatorKit \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:OperatorKitTests/OfflineCertificationInvariantTests
```

### Manual Network Check

```bash
# Monitor network during app operation (requires Instruments or similar)
# Use Network Link Conditioner to simulate airplane mode
# Verify core pipeline still functions
```

---

## 6. Regression Firewall Verification

### What It Proves

Protected modules (ExecutionEngine, ApprovalGate, ModelRouter) cannot be modified without breaking tests.

### Run Firewall Tests

```bash
xcodebuild test \
  -project OperatorKit.xcodeproj \
  -scheme OperatorKit \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:OperatorKitTests/RegressionFirewallInvariantTests
```

### Source Code Verification

```bash
# Verify protected modules don't import networking
grep -r "URLSession\|Network\|CFNetwork" \
  OperatorKit/Domain/Execution/ExecutionEngine.swift \
  OperatorKit/Domain/Approval/ApprovalGate.swift \
  OperatorKit/Models/ModelRouter.swift

# Expected: No matches
```

---

## 7. Build Seals Test Verification

### Run All Seal Tests

```bash
xcodebuild test \
  -project OperatorKit.xcodeproj \
  -scheme OperatorKit \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:OperatorKitTests/BuildSealsInvariantTests
```

### Expected Results

- All tests pass
- Seals exist and are parseable
- No forbidden keys in seal files
- Hashes are valid SHA256 format

---

## 8. Security Manifest UI Location

### In-App Access

1. Open OperatorKit
2. Navigate to: Settings → Trust Dashboard → Security Manifest
3. Review all claims with their proof sources

### Verification

Each claim should show:
- ✅ or ❌ status
- Proof source (Binary Proof, Build Seals, etc.)
- Factual description (no marketing language)

---

## 9. Trust Calibration Location

### First Launch Only

The Trust Calibration ceremony appears on first launch only. To re-test:

```swift
// In DEBUG mode, reset state:
LaunchTrustCalibrationState.resetForTesting()
```

### What to Verify

- All 7 calibration steps complete
- Each step shows ✅ (in a compliant build)
- "System Verified" appears at completion

---

## 10. ProofPack Export Verification

### Generate ProofPack

1. Open OperatorKit
2. Navigate to: Settings → Trust Dashboard → Proof Pack
3. Tap "Assemble Proof Pack"
4. Tap "Export Proof Pack"
5. Save or share the JSON file

### Verify ProofPack Contents

```bash
# Parse and inspect
cat ProofPack.json | jq '.'

# Check for forbidden keys
cat ProofPack.json | grep -iE "body|subject|content|draft|prompt|email"
# Expected: No matches

# Verify structure
cat ProofPack.json | jq 'keys'
# Expected: schemaVersion, appVersion, buildNumber, releaseSeals, securityManifest, binaryProof, etc.
```

---

## Quick Verification Checklist

```bash
#!/bin/bash
# quick_audit.sh - Run from project root

APP_PATH="$1"
BINARY="$APP_PATH/OperatorKit"

echo "=== OperatorKit Security Audit ==="

echo -e "\n[1] Checking entitlements..."
codesign -d --entitlements :- "$APP_PATH" 2>/dev/null | grep -c "network.client"

echo -e "\n[2] Checking for WebKit..."
otool -L "$BINARY" | grep -ic webkit

echo -e "\n[3] Checking for JavaScriptCore..."
otool -L "$BINARY" | grep -ic javascriptcore

echo -e "\n[4] Checking for SafariServices..."
otool -L "$BINARY" | grep -ic safariservices

echo -e "\n[5] Checking for URLSession in symbols..."
nm -U "$BINARY" 2>/dev/null | grep -ic urlsession

echo -e "\n=== Audit Complete ==="
```

---

## Document Metadata

| Field | Value |
|-------|-------|
| Created | Phase L3 |
| Classification | Technical Audit |
| Runtime Changes | NONE |
