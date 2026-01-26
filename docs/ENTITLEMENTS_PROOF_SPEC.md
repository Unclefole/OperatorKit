# ENTITLEMENTS PROOF SPECIFICATION

**Phase**: 13J  
**Classification**: Build Seal  
**Status**: ACTIVE

---

## Overview

The Entitlements Seal provides cryptographic proof of the app's code signing entitlements at build time. This allows auditors to verify that the distributed binary has not requested unexpected permissions.

---

## What Is Sealed

The Entitlements Seal captures:

| Field | Description |
|-------|-------------|
| `entitlementsHash` | SHA256 of the extracted entitlements plist |
| `entitlementCount` | Count of entitlement keys in the plist |
| `sandboxEnabled` | Whether App Sandbox is enabled |
| `networkClientRequested` | Whether network client entitlement is requested |
| `schemaVersion` | Schema version for forward compatibility |
| `generatedAtDayRounded` | Generation date (day-rounded, no time) |

---

## Generation Process

### Build Script

Location: `Scripts/generate_entitlements_seal.sh`

```bash
# Extract entitlements from signed app
codesign -d --entitlements :- "$APP_PATH" > entitlements.plist

# Compute SHA256
shasum -a 256 entitlements.plist | cut -d' ' -f1
```

### When to Run

- After code signing in Xcode build phase
- At archive time for release builds
- During CI/CD pipeline before distribution

---

## Reproduction Instructions

Auditors can verify the seal by:

1. **Extract entitlements from the distributed app**:
   ```bash
   codesign -d --entitlements :- /path/to/OperatorKit.app > entitlements.plist
   ```

2. **Compute SHA256**:
   ```bash
   shasum -a 256 entitlements.plist
   ```

3. **Compare with sealed hash** in `Resources/Seals/ENTITLEMENTS_SEAL.txt`

---

## Expected Entitlements

For a privacy-focused app like OperatorKit, expected entitlements should include:

| Entitlement | Expected | Reason |
|-------------|----------|--------|
| `com.apple.security.app-sandbox` | ✅ Yes | Sandbox enforcement |
| `com.apple.security.network.client` | ⚠️ Optional | Only if cloud sync enabled |
| `com.apple.security.files.user-selected.read-write` | ✅ Yes | User-initiated file access |

---

## What Is NOT Sealed

- ❌ User data
- ❌ Runtime state
- ❌ Filesystem paths
- ❌ Device identifiers

---

## Seal File Format

### Text Format (`ENTITLEMENTS_SEAL.txt`)

```
<64-character SHA256 hash>
schemaVersion=1
entitlementCount=<count>
sandboxEnabled=<true|false>
networkClientRequested=<true|false>
generated=<YYYY-MM-DD>
```

---

## Constraints

1. **Read-only** — Seal is generated at build time, not runtime
2. **Deterministic** — Same entitlements produce same hash
3. **No user content** — Only metadata about entitlements
4. **Auditor-reproducible** — Can be verified with standard tools

---

## Document Metadata

| Field | Value |
|-------|-------|
| Created | Phase 13J |
| Build Script | `Scripts/generate_entitlements_seal.sh` |
| Resource File | `Resources/Seals/ENTITLEMENTS_SEAL.txt` |
| Runtime Changes | NONE |
