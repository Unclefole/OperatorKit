# SYNTHETIC DATA SPECIFICATION

**Phase**: 13I  
**Classification**: Test Infrastructure  
**Status**: ACTIVE

---

## Overview

This specification defines the synthetic data harness used for verifying OperatorKit's routing correctness, distribution coverage, and privacy safety. The synthetic data system is used **exclusively for tests and verification** — no user data, no telemetry, no runtime behavior changes.

---

## Purpose

The synthetic data harness provides:

1. **Distribution Match Verification** — Proves generated test data covers the same intent space as hand-verified examples
2. **Routing Accuracy Auditing** — Validates action routing against known-correct expected outcomes
3. **Privacy Leak Detection** — Ensures no PII, real identifiers, or forbidden content in test fixtures

---

## What Synthetic Data IS

- ✅ Hand-crafted and template-generated test examples
- ✅ Deterministic, reproducible fixtures
- ✅ Content-free (all values are synthetic placeholders)
- ✅ Local-only (loaded from bundle resources)
- ✅ Read-only (no runtime modification)

## What Synthetic Data IS NOT

- ❌ User data
- ❌ Telemetry or analytics
- ❌ Production training data
- ❌ Network-fetched content
- ❌ Real email addresses, phone numbers, or identifiers

---

## Schema Definition

### SyntheticExample

```json
{
  "example_id": "string (unique identifier)",
  "domain": "email | calendar | notes | tasks | documents | general",
  "user_intent": "string (synthetic user request)",
  "selected_context": [
    {
      "context_type": "calendar_event | document_snippet | email_stub | note_stub | contact_card | task_item",
      "context_id": "string",
      "synthetic_content": {
        "synthetic_title": "string (prefixed with [SYNTHETIC])",
        "synthetic_date": "ISO date string",
        "synthetic_participants": ["email@example.com"],
        "synthetic_snippet": "string (prefixed with [SYNTHETIC])",
        "synthetic_location": "string (prefixed with [SYNTHETIC])"
      }
    }
  ],
  "expected_native_outcome": {
    "action_id": "string (e.g., compose_email, create_calendar_event)",
    "draft_fields": {
      "synthetic_recipient": "email@example.com",
      "synthetic_subject": "string",
      "synthetic_body_placeholder": "[SYNTHETIC_BODY_PLACEHOLDER]"
    },
    "should_trigger_safety_gate": "boolean"
  },
  "safety_gate": {
    "requires_approval": "boolean",
    "trigger_reason": "string (optional)",
    "risk_level": "low | standard | elevated | high"
  },
  "schema_version": 1,
  "metadata": {
    "generation_source": "hand_verified | template_generated",
    "tags": ["string"],
    "is_negative_example": "boolean",
    "expected_failure_reason": "string (for negative examples)"
  }
}
```

---

## Generation Rules

### Content Constraints

1. **All user-facing text MUST be prefixed with `[SYNTHETIC]`**
2. **Email addresses MUST use allowed domains only**:
   - `example.com`
   - `test.com`
   - `synthetic.local`
   - `placeholder.dev`
   - `acme.example`
   - `corp.example`

3. **Forbidden field names** (must never appear):
   - `ssn`, `socialSecurityNumber`, `taxId`, `driverLicense`
   - `password`, `pin`, `secretKey`, `apiKey`, `token`
   - `creditCard`, `cardNumber`, `cvv`, `bankAccount`
   - `realEmail`, `personalEmail`, `homePhone`, `mobilePhone`

4. **Forbidden content patterns** (must never appear):
   - Real email addresses (not in allowed domains)
   - US phone numbers: `\d{3}[-.]?\d{3}[-.]?\d{4}`
   - SSN patterns: `\d{3}-\d{2}-\d{4}`
   - Credit card patterns: `(\d{4}[-\s]?){3}\d{4}`
   - Real firm names (Google, Apple, Microsoft, etc.)

### Domain Coverage

The seed set must cover all domains:
- `email` — Email composition and replies
- `calendar` — Event creation, modification, deletion
- `notes` — Note creation and summaries
- `tasks` — Task and reminder creation
- `documents` — Document queries and summaries
- `general` — Cross-domain queries

---

## Audits

### Audit 1: Distribution Match

**Purpose**: Verify synthetic corpus covers the same intent space as the hand-verified seed set.

**Method**:
1. Extract `user_intent` from seed set examples
2. Extract `user_intent` from generated corpus
3. Compute cosine similarity using `NLEmbedding.sentenceEmbedding`
4. For each generated intent, find maximum similarity to any seed intent
5. Calculate overlap percentage (intents with similarity ≥ 0.75)

**Thresholds**:
| Metric | Threshold | Location |
|--------|-----------|----------|
| Overlap Percentage | ≥ 85% | `EmbeddingAuditConstants.minimumOverlapThreshold` |
| Mean Similarity | ≥ 0.70 | `EmbeddingAuditConstants.minimumMeanSimilarity` |
| Overlap Classification | ≥ 0.75 | `EmbeddingAuditConstants.overlapSimilarityThreshold` |

**Output**: `EmbeddingAuditResult` with overlap %, mean similarity, p95 similarity, unmatched intents.

---

### Audit 2: Routing Accuracy

**Purpose**: Verify action routing matches expected outcomes.

**Method**:
1. For each synthetic example, extract `user_intent` and `selected_context`
2. Simulate/invoke routing logic
3. Compare routed `action_id` with `expected_native_outcome.action_id`
4. Calculate accuracy percentage

**Thresholds**:
| Metric | Threshold | Location |
|--------|-----------|----------|
| Overall Accuracy | ≥ 99.9% | `ActionRoutingAccuracyTests.routingAccuracyThreshold` |
| Per-Domain Accuracy | ≥ 95% | Inline constant |
| Negative Rejection Rate | ≥ 95% | Inline constant |

**Output**: Correct count, failed examples, accuracy percentage.

---

### Audit 3: Privacy Leak Check

**Purpose**: Ensure no PII or forbidden content in fixtures.

**Method**:
1. Load all fixture JSON files
2. Scan for forbidden field names in keys
3. Scan for PII regex patterns in values
4. Verify all email addresses use allowed domains
5. Check for forbidden firm names

**Patterns Checked**:
- Email addresses outside allowed domains
- US phone numbers
- SSN patterns
- Credit card patterns
- Forbidden firm names (Google, Apple, etc.)

**Output**: List of violations by fixture and example.

---

## Fixture Files

| File | Purpose | Count |
|------|---------|-------|
| `SyntheticSeedSet.json` | Hand-verified examples | 100 |
| `SyntheticCorpusSmall.json` | Template-generated examples | 100 |
| `NegativeExamples.json` | Irrelevant/insufficient context cases | 50 |

---

## Constants Reference

All configurable constants are located in source files:

### EmbeddingAuditConstants
```swift
// File: Features/SyntheticData/EmbeddingAudit.swift
minimumOverlapThreshold: Double = 0.85
minimumMeanSimilarity: Double = 0.70
maximumP95Deviation: Double = 0.40
overlapSimilarityThreshold: Double = 0.75
```

### Test Constants
```swift
// File: OperatorKitTests/SyntheticDataInvariantTests.swift
distributionMatchThreshold: Double = 0.85

// File: OperatorKitTests/ActionRoutingAccuracyTests.swift
routingAccuracyThreshold: Double = 0.999
maxRoutingLatencyMs: Double = 100.0
```

---

## Test Files

| Test File | Purpose |
|-----------|---------|
| `SyntheticDataInvariantTests.swift` | Schema validation, PII detection, distribution match |
| `ActionRoutingAccuracyTests.swift` | Routing accuracy, negative example handling |

---

## Constraints (Non-Negotiable)

1. **NO user data** — All content is synthetic placeholders
2. **NO networking** — Fixtures loaded from bundle only
3. **NO telemetry** — No data leaves the device
4. **NO runtime modification** — Read-only test infrastructure
5. **Deterministic results** — Same inputs produce same outputs

---

## Statement of Purpose

> "Synthetic dataset is used for tests/verification; no user data; no telemetry."

This synthetic data harness exists solely to verify OperatorKit's correctness and safety. It does not collect, store, or transmit any real user information.

---

## Document Metadata

| Field | Value |
|-------|-------|
| Created | Phase 13I |
| Classification | Test Infrastructure |
| Test Suite | `SyntheticDataInvariantTests.swift`, `ActionRoutingAccuracyTests.swift` |
| Runtime Changes | NONE |
| Schema Version | 1 |
