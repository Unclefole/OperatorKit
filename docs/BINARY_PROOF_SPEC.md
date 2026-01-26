# BINARY PROOF SPECIFICATION

**Document Purpose**: Defines the Binary Proof feature for Mach-O / dyld framework inspection.

**Phase**: 13G  
**Classification**: Security Proof Surface  
**Status**: IMPLEMENTED

---

## Overview

Binary Proof provides verifiable evidence about which frameworks are linked in the app binary at runtime. This goes beyond source code scanning (Phase 13F) to prove absence of WebKit/JavaScriptCore at the Mach-O level.

---

## Technical Approach

### dyld APIs Used

Binary Proof uses only public dyld APIs:

```swift
// Count of loaded images
_dyld_image_count() -> UInt32

// Get image name by index
_dyld_get_image_name(UInt32) -> UnsafePointer<CChar>?
```

These are public, documented APIs available in the Darwin/dyld headers.

### What Is NOT Used

- ❌ Private APIs
- ❌ Shell tools (otool, nm, etc.)
- ❌ Disk reads outside sandbox
- ❌ Network requests
- ❌ File writes

---

## Inspection Process

1. **Enumerate Images**: Call `_dyld_image_count()` to get total loaded images
2. **Extract Names**: For each image, call `_dyld_get_image_name(i)`
3. **Sanitize**: Extract framework name only (e.g., "WebKit" from "/System/Library/Frameworks/WebKit.framework/WebKit")
4. **Check Sensitive**: Compare against sensitive framework list
5. **Determine Status**: PASS/WARN/FAIL based on presence of critical frameworks

---

## Sensitive Frameworks

The following frameworks trigger special attention:

| Framework | If Present | Reason |
|-----------|------------|--------|
| WebKit | FAIL | Enables web content rendering, JavaScript execution |
| JavaScriptCore | FAIL | Enables JavaScript execution |
| SafariServices | WARN | May be used for auth flows (review required) |
| WebKitLegacy | FAIL | Legacy web rendering |
| StoreKitWeb | WARN | Web-based store features |

---

## Status Determination

| Status | Condition |
|--------|-----------|
| PASS | No sensitive frameworks linked |
| WARN | SafariServices or similar present (review required) |
| FAIL | WebKit or JavaScriptCore linked |
| DISABLED | Feature flag is off |

---

## Export Packet

The Binary Proof Packet contains:

```json
{
  "schemaVersion": 1,
  "createdAtDayRounded": "2026-01-24",
  "appVersion": "1.0.0",
  "buildNumber": "123",
  "overallStatus": "PASS",
  "frameworkCount": 45,
  "linkedFrameworks": ["UIKit", "Foundation", "SwiftUI", ...],
  "sensitiveFrameworkChecks": [
    {"framework": "WebKit", "isPresent": false},
    {"framework": "JavaScriptCore", "isPresent": false},
    ...
  ],
  "proofNotes": ["No sensitive web frameworks detected"]
}
```

### What Is Included

- ✅ Sanitized framework identifiers
- ✅ Sensitive framework presence checks
- ✅ Day-rounded timestamp
- ✅ App version and build number
- ✅ Overall status

### What Is NOT Included

- ❌ Full filesystem paths
- ❌ User content (drafts, emails, etc.)
- ❌ Device identifiers
- ❌ Personal data
- ❌ Any forbidden keys (body, subject, content, etc.)

---

## Determinism

Results are deterministic for a given build:
- Framework set is stable (same app = same frameworks)
- Framework list is sorted alphabetically
- No timing-dependent data

---

## Constraints

1. **Read-Only**: No toggles, no "fix" buttons, no behavior changes
2. **Offline**: Works in Airplane Mode
3. **No Writes**: Does not write to disk
4. **User-Initiated Export**: Export only via explicit ShareSheet action
5. **Feature-Flagged**: Gated by `BinaryProofFeatureFlag`

---

## Verification

Users and auditors can verify by:

1. Opening the Binary Proof screen
2. Reviewing the sensitive framework checks
3. Optionally exporting the proof packet
4. Cross-referencing with `otool -L` on the app binary (for developers)

---

## Limitations

This feature does NOT:

- ❌ Scan disk for hidden binaries
- ❌ Monitor runtime loading (just snapshot)
- ❌ Guarantee no vulnerabilities exist
- ❌ Replace professional security audits

It provides evidence, not absolute guarantees.

---

## Document Metadata

| Field | Value |
|-------|-------|
| Created | Phase 13G |
| Classification | Security Proof |
| APIs Used | dyld (public) |
| Deterministic | Yes |
| Offline-Capable | Yes |

---

*Binary Proof provides auditable evidence about linked frameworks, not marketing claims.*
