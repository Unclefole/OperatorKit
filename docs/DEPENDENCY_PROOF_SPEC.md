# DEPENDENCY PROOF SPECIFICATION

**Phase**: 13J  
**Classification**: Build Seal  
**Status**: ACTIVE

---

## Overview

The Dependency Seal provides a cryptographic fingerprint of all SPM dependencies at build time. This allows auditors to verify that the distributed binary was built with known, vetted dependencies.

---

## What Is Sealed

The Dependency Seal captures:

| Field | Description |
|-------|-------------|
| `dependencyHash` | SHA256 of the normalized dependency list |
| `dependencyCount` | Count of direct dependencies |
| `transitiveDependencyCount` | Count of all dependencies (including transitive) |
| `lockfilePresent` | Whether Package.resolved was found |
| `schemaVersion` | Schema version for forward compatibility |
| `generatedAtDayRounded` | Generation date (day-rounded, no time) |

---

## Generation Process

### Build Script

Location: `Scripts/generate_dependency_seal.sh`

```bash
# Parse Package.resolved
# Extract: identity@version for each package
# Sort alphabetically for determinism
# Compute SHA256 of the sorted list
```

### Normalized Format

Each dependency is formatted as:

```
<package-identity>@<version>
```

Sorted alphabetically, one per line.

### When to Run

- During CI/CD build process
- Before creating release archives
- After `swift package resolve`

---

## Reproduction Instructions

Auditors can verify the seal by:

1. **Locate Package.resolved**:
   ```bash
   # Xcode project
   cat OperatorKit.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
   
   # Or standalone SPM
   cat Package.resolved
   ```

2. **Extract and normalize dependencies**:
   ```bash
   # Using jq (for version 2 format)
   jq -r '.pins[] | "\(.identity)@\(.state.version // .state.revision)"' Package.resolved | sort
   ```

3. **Compute SHA256**:
   ```bash
   jq -r '.pins[] | "\(.identity)@\(.state.version // .state.revision)"' Package.resolved | sort | shasum -a 256
   ```

4. **Compare with sealed hash** in `Resources/Seals/DEPENDENCY_SEAL.txt`

---

## Package.resolved Formats

### Version 2 (Modern)

```json
{
  "pins": [
    {
      "identity": "package-name",
      "state": {
        "version": "1.0.0"
      }
    }
  ]
}
```

### Version 1 (Legacy)

```json
{
  "object": {
    "pins": [
      {
        "package": "PackageName",
        "state": {
          "version": "1.0.0"
        }
      }
    ]
  }
}
```

---

## What Is NOT Sealed

- ❌ Package source code
- ❌ Full repository URLs (only identity)
- ❌ Local filesystem paths
- ❌ Authentication tokens

---

## Seal File Format

### Text Format (`DEPENDENCY_SEAL.txt`)

```
<64-character SHA256 hash>
schemaVersion=1
dependencyCount=<count>
transitiveDependencyCount=<count>
lockfilePresent=<true|false>
generated=<YYYY-MM-DD>
```

---

## Constraints

1. **Read-only** — Seal is generated at build time, not runtime
2. **Deterministic** — Same dependencies produce same hash
3. **No source code** — Only package identities and versions
4. **Auditor-reproducible** — Can be verified with Package.resolved

---

## Document Metadata

| Field | Value |
|-------|-------|
| Created | Phase 13J |
| Build Script | `Scripts/generate_dependency_seal.sh` |
| Resource File | `Resources/Seals/DEPENDENCY_SEAL.txt` |
| Runtime Changes | NONE |
