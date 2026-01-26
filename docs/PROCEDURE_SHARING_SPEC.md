# PROCEDURE SHARING SPECIFICATION

**Document Purpose**: Canonical specification for Procedure Sharing feature.

**Phase**: 13B  
**Classification**: Feature Specification  
**Status**: Implemented

---

## Definition

A **Procedure** is:
- A named workflow template
- Consisting of: intent structure, prompt scaffolding, policy constraints, output type
- Containing **NO**: user text, context, memory, drafts, outputs, identifiers

**Procedures share logic, never data.**

---

## Data Model

### ProcedureTemplate

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Unique identifier (deterministic) |
| name | String | Display name (validated, max 100 chars) |
| category | ProcedureCategory | Organization category (enum) |
| intentSkeleton | IntentSkeleton | Intent structure (no user content) |
| constraints | ProcedureConstraints | Policy constraints |
| outputType | ProcedureOutputType | Output type identifier (enum) |
| createdAtDayRounded | String | Day-rounded creation date |
| schemaVersion | Int | Schema version |

### IntentSkeleton

| Field | Type | Description |
|-------|------|-------------|
| intentType | String | Intent type identifier |
| requiredContextTypes | [String] | Required context type IDs |
| promptScaffold | String | Template with placeholders |

### ProcedureConstraints

| Field | Type | Description |
|-------|------|-------------|
| maxOutputLength | Int? | Optional max length |
| requiresApproval | Bool | Always true (enforced) |
| allowedDaysOfWeek | [Int]? | Optional day restrictions |
| maxExecutionsPerDay | Int? | Optional daily limit |

---

## Forbidden Content

### Forbidden Keys

The following keys must **never** appear in procedure serialization:

```
body, subject, content, draft, prompt, context,
email, recipient, attendees, title, description,
message, text, name, address, company, domain,
phone, note, notes, memory, output, result,
userText, userInput, userData, personalData
```

### Forbidden Patterns

The following patterns must **never** appear in procedure data:

```
@gmail.com, @yahoo.com, @outlook.com, @icloud.com,
Dear , Hi , Hello , Meeting with,
555-, (555), +1,
Street, Avenue, Road
```

---

## Storage

### Local-Only

- Storage: UserDefaults
- Key: `com.operatorkit.procedures.v1`
- Max count: 50 procedures
- No syncing
- No cloud storage
- No network access

### Operations

All operations require explicit confirmation:

| Operation | Confirmation Required |
|-----------|----------------------|
| Add | Yes |
| Remove | Yes |
| Clear All | Yes |
| Import | Yes |
| Export | No (read-only) |

---

## Import / Export

### Export

- Produces local JSON file
- Logic-only payload
- No encryption keys transmitted
- Validates before export

### Import

- Requires user confirmation
- Validates against forbidden keys
- Rejects invalid content
- Local file picker only
- No network paths

---

## Safety Guards

### Runtime Assertions

```swift
procedure.intentSkeleton.assertNoUserContent()
```

### Validation

Every procedure is validated:
1. Name not empty, max 100 chars
2. No forbidden patterns in name
3. No forbidden patterns in prompt scaffold
4. No forbidden keys in serialization
5. Context types are enum-like (no spaces, no @)

### UI Warnings

All UI surfaces display:
> "Procedures contain logic only. No data is shared."

---

## Feature Flag

| Flag | Value |
|------|-------|
| Name | `ProcedureSharingFeatureFlag.isEnabled` |
| DEBUG default | true |
| RELEASE default | false |

All entry points are gated by this flag.

---

## Constraints (Absolute)

| Constraint | Enforced |
|------------|----------|
| No user content | ✅ Validation + assertions |
| No networking | ✅ No URLSession imports |
| No background tasks | ✅ No BGTaskScheduler |
| No cloud sync | ✅ Local UserDefaults only |
| No execution | ✅ Apply → prefill only |
| User confirmation | ✅ All mutations require confirm |
| Max count | ✅ 50 procedures enforced |
| Feature flag | ✅ All surfaces gated |

---

## Applying a Procedure

When a user applies a procedure:

1. Procedure is read (no modification)
2. Intent input is prefilled with scaffold
3. User reviews and edits
4. User must approve execution separately

**Applying a procedure does NOT execute.**

---

## Document Metadata

| Field | Value |
|-------|-------|
| Created | Phase 13B |
| Classification | Feature Specification |
| Runtime Behavior Changed | No |
| Execution Modified | No |
| Data Sharing Introduced | No |

---

*Procedures share logic, never data.*
