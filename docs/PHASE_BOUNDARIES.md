# Phase Boundaries: Future Development Guidelines

**Purpose:** Prevent accidental erosion of OperatorKit's safety guarantees and product identity.

This document defines what future phases may and may not include.

---

## Product Identity Statement

OperatorKit is:
- **On-device first**: All processing happens locally
- **User-controlled**: Every action requires explicit approval
- **Draft-first**: Outputs are previews until confirmed
- **Transparent**: Users see exactly what data is used
- **Privacy-respecting**: No data leaves the device

Any future development must preserve this identity.

---

## What Phase 8+ May Include

The following are **acceptable** directions for future development:

### Enhanced On-Device Models
- ✅ Better Apple Foundation Models integration (when available)
- ✅ Improved Core ML model accuracy
- ✅ More sophisticated deterministic templates
- ✅ Better confidence calibration

**Constraint:** All models must be on-device. No cloud inference.

### Additional Apple Framework Integration
- ✅ Notes app integration (draft-first, user-selected)
- ✅ Files app integration (user-selected only)
- ✅ Shortcuts integration (user-triggered only)
- ✅ Focus modes awareness (read-only)

**Constraint:** Same approval/two-key rules apply.

### UI/UX Improvements
- ✅ Better accessibility
- ✅ iPad optimization
- ✅ Widgets (display-only, no background execution)
- ✅ Improved onboarding

**Constraint:** No autonomous actions via UI.

### Memory & Audit Enhancements
- ✅ Better search/filtering
- ✅ Export functionality (user-initiated)
- ✅ Tagging/organization

**Constraint:** Audit trail remains immutable.

### Performance Optimization
- ✅ Faster draft generation
- ✅ Lower latency model inference
- ✅ Better caching

**Constraint:** No background optimization tasks.

---

## Explicitly OUT OF SCOPE

The following require a **new safety review** and **Safety Contract amendment**:

### 🚫 Networking
| Feature | Status | Why |
|---------|--------|-----|
| Cloud model inference | FORBIDDEN | Violates on-device guarantee |
| API calls for any purpose | FORBIDDEN | Violates no-network guarantee |
| Sync to servers | FORBIDDEN | Violates privacy guarantee |
| Remote configuration | FORBIDDEN | Violates determinism guarantee |
| Analytics/telemetry | FORBIDDEN | Violates privacy guarantee |

**No exceptions.** If networking is ever required, it's a different product.

### 🚫 Background Agents
| Feature | Status | Why |
|---------|--------|-----|
| Background refresh | FORBIDDEN | Violates no-background guarantee |
| Scheduled tasks | FORBIDDEN | Violates user-control guarantee |
| Background processing | FORBIDDEN | Violates no-background guarantee |
| Silent notifications | FORBIDDEN | Enables background execution |
| Location-triggered actions | FORBIDDEN | Autonomous execution |

**No exceptions.** Background execution violates core product identity.

### 🚫 Autonomous Execution
| Feature | Status | Why |
|---------|--------|-----|
| Auto-send emails | FORBIDDEN | Violates approval guarantee |
| Auto-create events | FORBIDDEN | Violates two-key guarantee |
| Inferred actions | FORBIDDEN | Violates explicit-selection guarantee |
| "Smart" suggestions that execute | FORBIDDEN | Violates draft-first guarantee |
| Time-triggered actions | FORBIDDEN | Autonomous execution |

**No exceptions.** Users must approve every action.

### 🚫 Cloud Models
| Feature | Status | Why |
|---------|--------|-----|
| OpenAI API | FORBIDDEN | Requires network |
| Anthropic API | FORBIDDEN | Requires network |
| Google AI API | FORBIDDEN | Requires network |
| Any cloud LLM | FORBIDDEN | Requires network |
| Hybrid cloud/local | FORBIDDEN | Partial network |

**No exceptions.** On-device means on-device.

### 🚫 Analytics / Telemetry
| Feature | Status | Why |
|---------|--------|-----|
| Usage analytics | FORBIDDEN | Violates privacy |
| Crash reporting to servers | FORBIDDEN | Requires network |
| A/B testing | FORBIDDEN | Requires network |
| Feature flags from server | FORBIDDEN | Requires network |
| User behavior tracking | FORBIDDEN | Violates privacy |

**No exceptions.** We don't collect data.

---

## Experimental Work Guidelines

New features that are uncertain should:

1. **Live in DEBUG only** (`#if DEBUG`)
2. **Be behind feature flags** (local, not remote)
3. **Not touch safety-critical code**
4. **Have explicit removal timeline**
5. **Never ship to TestFlight without review**

### Example: Experimenting with a New Feature

```swift
#if DEBUG
// EXPERIMENTAL: New context source
// Owner: [Name]
// Expiry: [Date]
// Status: [ ] Ready for review [ ] Remove
class ExperimentalContextSource {
    // ...
}
#endif
```

**Rule:** Experimental code must have an owner and expiry date.

---

## Phase Progression Rules

### Impact Declaration Requirement (Phase 8C)

**Every new phase MUST include a completed `PHASE_IMPACT_TEMPLATE.md` before implementation.**

The template requires declaring impact on:
- Execution flow
- Permissions
- Background behavior
- Networking
- Safety guarantees
- User-facing claims

See: `docs/PHASE_IMPACT_TEMPLATE.md`

### Before Starting Any New Phase

1. **Complete the Impact Declaration** using `PHASE_IMPACT_TEMPLATE.md`
2. **Review this document** to ensure work is in-scope
3. **Check Safety Contract** for affected guarantees
4. **Check Claim Registry** for affected claims
5. **Get explicit approval** if work touches safety-critical areas
6. **Document the scope** before starting

### Red Flags That Require Escalation

If you find yourself:
- Adding `import Network` or similar → STOP
- Adding `UIBackgroundModes` → STOP
- Removing approval checks → STOP
- Adding automatic execution → STOP
- Implementing server communication → STOP
- Collecting user data → STOP

**Escalate to Principal Engineer before proceeding.**

### Acceptable Phase Work Without Escalation

- UI improvements (no new data access)
- Bug fixes (that don't change behavior)
- Performance improvements (no background work)
- Documentation updates
- Test improvements
- Accessibility enhancements

---

## Decision Tree: Is This Change In-Scope?

```
Does it require network access?
├── Yes → OUT OF SCOPE (stop)
└── No ↓

Does it run in the background?
├── Yes → OUT OF SCOPE (stop)
└── No ↓

Does it execute without user approval?
├── Yes → OUT OF SCOPE (stop)
└── No ↓

Does it access data without user selection?
├── Yes → OUT OF SCOPE (stop)
└── No ↓

Does it modify a Safety Contract guarantee?
├── Yes → Requires Safety Contract Change Approval
└── No → Proceed with normal development
```

---

## Version Planning

| Version | Scope | Safety Review Required |
|---------|-------|------------------------|
| 1.x | Current features, bug fixes, minor enhancements | No (unless touching safety code) |
| 2.0 | Major enhancements within current architecture | Yes |
| 3.0 | Architectural changes (if ever) | Full safety audit |

**Note:** There may never be a need for 2.0 or 3.0. The product may be complete.

---

## Maintenance Mode Guidelines

If OperatorKit enters maintenance mode:

1. **Security fixes only** - critical vulnerabilities
2. **iOS compatibility** - new iOS version support
3. **Bug fixes** - user-facing issues
4. **No new features** without explicit decision to exit maintenance

---

---

## Phase 9C: Integrity & Tamper-Evident Quality Records

**Objective**: Add cryptographic-grade integrity signals to the quality and governance system so that evaluation artifacts, exports, and summaries are tamper-evident, verifiable, and externally auditable — without introducing security claims, blocking behavior, networking, background work, or any execution-path changes.

### What Phase 9C Adds

| Component | Description |
|-----------|-------------|
| `IntegritySeal` | SHA-256 hash of quality metadata sections |
| `IntegrityVerifier` | Read-only verification returning status only |
| `IntegrityStatus` | Valid / Mismatch / Unavailable |
| `EvalRunLineage` | Chronological linking of eval runs |
| `QualitySnapshotSummary` | Debug/TestFlight quality display |
| UI Indicators | Read-only integrity status in Release Readiness view |

### What Phase 9C Does NOT Add

| Explicitly Excluded | Reason |
|--------------------|--------|
| Security claims | Integrity ≠ security |
| Blocking/gating | Advisory only |
| Encryption | Hashing, not encryption |
| Key management | No keys involved |
| Network access | Local only |
| Background tasks | User-initiated only |
| User content hashing | Metadata only |

### Constraints (Absolute)

- ❌ No runtime behavior changes
- ❌ No blocking, gating, or enforcement
- ❌ No networking, cloud, or background tasks
- ❌ No cryptographic key management
- ❌ No user content storage or hashing
- ❌ No security language ("secure", "protected", "encrypted")
- ✅ Metadata-only
- ✅ Advisory / informational only

### Exit Criteria

Phase 9C is complete only when:

- ✅ All tests green
- ✅ No behavior change
- ✅ No new claims beyond integrity
- ✅ No security language
- ✅ Integrity is advisory and local only
- ✅ Export remains content-free
- ✅ App Store behavior unchanged

---

## Phase 9D: External Review Readiness

**Objective**: Create a content-free, exportable, reviewer-friendly evidence bundle that proves OperatorKit's guarantees and governance discipline.

### What Phase 9D Adds

| Component | Description |
|-----------|-------------|
| `ExternalReviewEvidencePacket` | Unified export artifact for reviewers |
| `ExternalReviewEvidenceBuilder` | Soft-failure builder for evidence packet |
| `DocHashRegistry` | SHA-256 hashes of governance documents |
| `DisclaimersRegistry` | App Store-safe disclaimers |
| `ExternalReviewReadinessView` | Read-only reviewer-friendly UI |
| `ReviewerSimulationChecklistView` | Verification checklist with evidence sources |

### What Phase 9D Does NOT Add

| Explicitly Excluded | Reason |
|--------------------|--------|
| Automatic exports | Manual only |
| Network uploads | Local only |
| User content | Metadata only |
| Behavior changes | Read-only UI |
| Security claims | Integrity only |
| Toggles/controls | No behavior modification |

### Evidence Packet Contents

| Section | Purpose |
|---------|---------|
| App Identity | Version, build, release mode |
| Safety Contract | Hash status, update reason |
| Claim Registry | All claims summary |
| Invariant Checks | Runtime verification results |
| Preflight Summary | Build validation status |
| Quality Metrics | Golden cases, pass rates, drift |
| Integrity Status | Tamper-evident verification |
| Reviewer Guidance | Test plan, FAQ |
| Disclaimers | Scope and limitations |

### Export Constraints

- ✅ Manual, user-initiated only
- ✅ Metadata-only content
- ✅ Local storage unless user shares
- ❌ No automatic or background exports
- ❌ No network transmission
- ❌ No user content collection

---

## Related Documents

- `docs/PHASE_IMPACT_TEMPLATE.md` - Required template for new phases
- `docs/SAFETY_CONTRACT.md` - Safety guarantees and change control
- `docs/CLAIM_REGISTRY.md` - User-visible claims tracking
- `docs/RELEASE_APPROVAL.md` - Release approval ritual

---

*This document is part of the OperatorKit governance framework (Phase 9D)*
