# SYMBOL PROOF SPECIFICATION

**Phase**: 13J  
**Classification**: Build Seal  
**Status**: ACTIVE

---

## Overview

The Symbol Seal provides proof that the compiled binary does not contain forbidden networking/web symbols or frameworks. This is the definitive binary-level verification that OperatorKit cannot make unauthorized network connections.

---

## What Is Sealed

The Symbol Seal captures:

| Field | Description |
|-------|-------------|
| `symbolListHash` | SHA256 of the extracted symbol names (sorted) |
| `forbiddenSymbolCount` | Count of forbidden symbols detected |
| `forbiddenFrameworkPresent` | Boolean if any forbidden framework is linked |
| `frameworkChecks` | Per-framework detection results |
| `totalSymbolsScanned` | Total symbols analyzed |
| `schemaVersion` | Schema version for forward compatibility |
| `generatedAtDayRounded` | Generation date (day-rounded, no time) |

---

## Forbidden Symbols/Frameworks

| Symbol/Framework | Severity | Reason |
|------------------|----------|--------|
| `URLSession` | Critical | Network requests |
| `CFNetwork` | Critical | Low-level networking |
| `NSURLConnection` | Critical | Legacy networking |
| `nw_connection` | Critical | Network.framework |
| `WebKit` | Critical | Web content rendering |
| `JavaScriptCore` | Critical | JavaScript execution |
| `SafariServices` | Warning | Safari integration |

---

## Generation Process

### Build Script

Location: `Scripts/generate_symbol_seal.sh`

```bash
# Extract symbols using nm
nm -U "$BINARY_PATH" | awk '{print $NF}' | sort -u > symbols.txt

# Check linked frameworks using otool
otool -L "$BINARY_PATH" | tail -n +2 | awk '{print $1}'

# Scan for forbidden patterns
grep -i "URLSession\|CFNetwork\|WebKit" symbols.txt

# Compute SHA256 of symbol list
shasum -a 256 symbols.txt
```

### When to Run

- After linking in Xcode build phase
- At archive time for release builds
- During CI/CD before distribution

---

## Reproduction Instructions

Auditors can verify the seal by:

1. **Extract symbols from the binary**:
   ```bash
   nm -U /path/to/OperatorKit.app/OperatorKit | awk '{print $NF}' | sort -u > symbols.txt
   ```

2. **Check for forbidden symbols**:
   ```bash
   grep -iE "URLSession|CFNetwork|NSURLConnection|nw_connection|WebKit|JavaScriptCore|SafariServices" symbols.txt
   ```

3. **Check linked frameworks**:
   ```bash
   otool -L /path/to/OperatorKit.app/OperatorKit | grep -iE "WebKit|JavaScriptCore|SafariServices|Network.framework"
   ```

4. **Compute SHA256**:
   ```bash
   shasum -a 256 symbols.txt
   ```

5. **Compare with sealed hash** in `Resources/Seals/SYMBOL_SEAL.json`

---

## Expected Results

For a compliant build:

```json
{
  "forbiddenSymbolCount": 0,
  "forbiddenFrameworkPresent": false
}
```

---

## What Is NOT Sealed

- ❌ Full filesystem paths
- ❌ Build machine information
- ❌ Debug symbols content
- ❌ User data

---

## Seal File Format

### JSON Format (`SYMBOL_SEAL.json`)

```json
{
  "symbolListHash": "<64-character SHA256>",
  "forbiddenSymbolCount": 0,
  "forbiddenFrameworkPresent": false,
  "frameworkChecks": [
    {"framework": "URLSession", "detected": false, "severity": "none"},
    {"framework": "WebKit", "detected": false, "severity": "none"}
  ],
  "totalSymbolsScanned": 12345,
  "schemaVersion": 1,
  "generatedAtDayRounded": "2026-01-24"
}
```

---

## Framework Check Details

Each framework check includes:

| Field | Description |
|-------|-------------|
| `framework` | Framework identifier (sanitized) |
| `detected` | Whether the framework was found |
| `severity` | `none`, `warning`, or `critical` |

---

## Constraints

1. **Read-only** — Seal is generated at build time, not runtime
2. **Deterministic** — Same binary produces same hash
3. **No paths** — Symbol names only, no filesystem paths
4. **Auditor-reproducible** — Can be verified with nm/otool

---

## CI/CD Integration

The build script can be configured to fail the build if forbidden frameworks are detected:

```bash
# In generate_symbol_seal.sh
if [ "$FORBIDDEN_FRAMEWORK_PRESENT" = "true" ]; then
    echo "ERROR: Forbidden frameworks detected!"
    exit 1
fi
```

---

## Document Metadata

| Field | Value |
|-------|-------|
| Created | Phase 13J |
| Build Script | `Scripts/generate_symbol_seal.sh` |
| Resource File | `Resources/Seals/SYMBOL_SEAL.json` |
| Runtime Changes | NONE |
