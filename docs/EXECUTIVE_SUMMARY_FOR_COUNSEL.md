# EXECUTIVE SUMMARY FOR COUNSEL

**Document Type**: Legal/Compliance Summary  
**Audience**: General Counsel, Privacy Officers, Compliance Teams  
**Reading Time**: 3 minutes  
**Phase**: L3

---

## What OperatorKit Does

OperatorKit is a productivity application for iPhone and iPad. Users select context (emails, calendar events, notes) and the app drafts responses or actions. The user reviews each draft and explicitly approves before anything executes.

---

## What Data Stays on Device

| Data Type | Storage Location | Leaves Device? |
|-----------|------------------|----------------|
| User drafts | Device only | Never |
| Email content | Device only | Never |
| Calendar events | Device only | Never |
| AI model processing | Device only | Never |
| Audit metadata | Device only | Never (counts only) |
| App settings | Device only | Optional sync (user-initiated) |

**Key Point**: The app does not transmit user-authored content to any server. There is no "cloud brain" or remote AI processing.

---

## What Cannot Happen

The following capabilities are architecturally absent from OperatorKit:

| Capability | Status | Verification |
|------------|--------|--------------|
| Web browser embedded | ❌ Not present | WebKit not linked (Binary Proof) |
| JavaScript execution | ❌ Not present | JavaScriptCore not linked (Binary Proof) |
| Background data collection | ❌ Not present | No BGTaskScheduler usage |
| Automatic execution | ❌ Not present | Approval Gate enforces user action |
| Silent network calls | ❌ Not present | Zero-network certification |

---

## What "Approval-Gated" Means

1. **Draft-First**: The app creates a draft, not an action
2. **User Review**: The draft is displayed for user review
3. **Explicit Approval**: User must tap a confirmation button
4. **Two-Key Confirmation**: Destructive actions require additional confirmation
5. **No Bypass**: There is no code path that executes without user action

This is enforced in `ApprovalGate.swift`, which is a protected module that cannot be modified without breaking automated tests.

---

## What Evidence Is Available

OperatorKit provides verifiable evidence of its security posture:

| Evidence Type | What It Shows | How to Access |
|---------------|---------------|---------------|
| ProofPack Export | JSON bundle with all trust metrics | In-app export |
| Build Seals | SHA256 hashes of entitlements, dependencies, symbols | In-app + CI/CD |
| Binary Proof | List of linked frameworks | In-app |
| Offline Certification | Zero-network verification results | In-app |

**These are not promises. They are auditable artifacts that can be independently verified.**

---

## Liability Framing

### What We Say

> "OperatorKit provides verifiable evidence that its core processing pipeline operates on-device without network connectivity."

### What We Do Not Say

- ❌ "Guaranteed secure"
- ❌ "Unhackable"
- ❌ "Military-grade encryption"
- ❌ "100% safe"

### Recommended Language

> "Designed for on-device operation. Verifiable evidence of zero-network architecture is available within the application and can be independently audited using standard iOS development tools."

---

## Third-Party Dependencies

| Dependency | Purpose | Network Activity |
|------------|---------|------------------|
| Apple Foundation Models | On-device AI | None |
| SwiftData | Local database | None |
| CryptoKit | Local encryption | None |
| Supabase SDK | Optional sync | User-initiated only |

**Note**: Supabase sync is disabled by default. When enabled, it syncs settings and metadata only—never user content.

---

## Questions for Due Diligence

| Question | Answer |
|----------|--------|
| Does the app collect telemetry? | No |
| Does the app phone home? | No (optional sync is user-initiated) |
| Can users export their data? | Yes (local export) |
| Can users delete their data? | Yes (local purge) |
| Is there an admin console? | No (local-first by design) |
| Can the vendor see user content? | No |

---

## Conclusion

OperatorKit is designed with a "local-first, approval-gated" architecture. Verifiable evidence of this architecture is embedded in the application and can be audited without relying on vendor representations.

---

**Document Metadata**

| Field | Value |
|-------|-------|
| Created | Phase L3 |
| Classification | Legal/Compliance |
| Runtime Changes | NONE |
