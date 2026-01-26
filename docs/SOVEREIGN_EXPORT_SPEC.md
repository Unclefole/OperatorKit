# SOVEREIGN EXPORT SPECIFICATION

**Document Purpose**: Canonical specification for Sovereign Export feature.

**Phase**: 13C  
**Classification**: Feature Specification  
**Status**: Implemented

---

## Definition

A **Sovereign Export** is:
- A user-owned encrypted archive
- Containing **only**: Procedure templates, policy state, entitlement metadata, audit counts
- Containing **NO**: Drafts, memory text, outputs, identifiers, context, user-generated content

**Sovereign Export enables user ownership without data exfiltration.**

---

## Data Model

### SovereignExportBundle

| Field | Type | Description |
|-------|------|-------------|
| schemaVersion | Int | Schema version |
| exportedAtDayRounded | String | Day-rounded export date |
| appVersion | String | App version at export |
| procedures | [ExportedProcedure] | Logic-only procedure templates |
| policySummary | ExportedPolicySummary | Policy flags and limits |
| entitlementState | ExportedEntitlementState | Tier and flags |
| auditCounts | ExportedAuditCounts | Aggregate counts only |

### Forbidden Keys

The following keys must **never** appear in the bundle:

```
body, subject, content, draft, prompt, context,
email, recipient, attendees, title, description,
message, text, address, company, domain, phone,
note, notes, memory, output, result, userData,
userText, userInput, personalData, identifier,
deviceId, userId, accountId, sessionId
```

---

## Encryption

### Algorithm

- **Cipher**: AES-256-GCM
- **Key Derivation**: HKDF-SHA256
- **Nonce**: Random 12 bytes per export
- **Tag**: 16 bytes (authentication)

### Key Management

| Aspect | Implementation |
|--------|----------------|
| Key Source | User passphrase |
| Key Derivation | HKDF with static salt |
| Key Storage | **None** (ephemeral) |
| Passphrase Storage | **None** |

### File Format

```
[Header: 6 bytes "OKSOV1"]
[Nonce: 12 bytes]
[Ciphertext: variable]
[Tag: 16 bytes]
```

---

## Export Flow

1. User taps "Export Configuration"
2. Warning displayed: "Logic only. No data."
3. User enters passphrase (min 8 chars)
4. User confirms passphrase
5. Bundle is built (logic + metadata only)
6. Bundle is validated
7. Bundle is encrypted
8. User saves file via system picker
9. Passphrase is cleared from memory

### No Plaintext on Disk

- Bundle is JSON-encoded in memory
- Encrypted before any file write
- Passphrase never persisted

---

## Import Flow

1. User taps "Import Configuration"
2. User selects .oksov file
3. User enters passphrase
4. File is decrypted
5. Bundle is validated
6. Summary is displayed
7. User confirms import
8. Procedures are imported
9. Passphrase is cleared from memory

### Validation Before Apply

- Schema version checked
- Forbidden keys scanned
- Forbidden patterns checked
- User must explicitly confirm

### Reversible

- Import can be cancelled at any step
- Existing data is not overwritten without confirmation
- Imported procedures can be individually deleted

---

## What Is Exported

| Category | Contents | User Content? |
|----------|----------|---------------|
| Procedures | Templates, scaffolds, constraints | ❌ No |
| Policy | Flags, limits, days | ❌ No |
| Entitlement | Tier, lifetime flag, seats | ❌ No |
| Audit | Aggregate counts only | ❌ No |

## What Is NEVER Exported

| Category | Reason |
|----------|--------|
| Drafted emails | User content |
| Calendar events | User content |
| Reminders | User content |
| Memory text | User content |
| Context | User content |
| Identifiers | Privacy |
| Device IDs | Privacy |

---

## Security Properties

| Property | Guarantee |
|----------|-----------|
| Confidentiality | AES-256-GCM encryption |
| Integrity | GCM authentication tag |
| No Key Storage | Passphrase never persisted |
| No Plaintext | Encrypted before disk write |
| No Network | Entirely local operation |
| User Control | User owns file, chooses storage |

---

## Feature Flag

| Flag | Value |
|------|-------|
| Name | `SovereignExportFeatureFlag.isEnabled` |
| DEBUG default | true |
| RELEASE default | false |

All entry points are gated by this flag.

---

## Constraints (Absolute)

| Constraint | Enforced |
|------------|----------|
| No user content | ✅ Forbidden keys validation |
| No networking | ✅ No URLSession imports |
| No background tasks | ✅ User-initiated only |
| No key storage | ✅ Ephemeral keys |
| No plaintext on disk | ✅ Encrypt before write |
| User confirmation | ✅ Required for import |
| Feature flag | ✅ All surfaces gated |

---

## Document Metadata

| Field | Value |
|-------|-------|
| Created | Phase 13C |
| Classification | Feature Specification |
| Runtime Behavior Changed | No |
| Execution Modified | No |
| Data Exfiltration | No |

---

*Sovereign Export enables user ownership without data exfiltration.*
