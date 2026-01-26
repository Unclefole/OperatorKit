# INTERPRETATION LOCKS

**Document Purpose**: Explicitly eliminate residual misinterpretation risks identified in Phase 12B by documenting the risky phrasing, wrong inference, and locked interpretation.

**Phase**: 12C  
**Classification**: Interpretation Lock  
**Source**: EXTERNAL_REVIEW_DRY_RUN.md § Residual Confusion Register

---

## Methodology

For each known misinterpretation:
1. Quote the risky phrasing
2. Explain the likely wrong inference
3. Show the locked interpretation

No new hypothetical risks are introduced. This document addresses only the 8 items from Phase 12B.

---

## Lock #1: "SwiftData" Developer Jargon

**Location**: APP_REVIEW_PACKET.md Data Access Table

**Risky Phrasing**: "Event metadata saved in Memory (SwiftData)"

**Wrong Inference**: Reviewer may not know what SwiftData is, leading to uncertainty about where data goes.

**Locked Interpretation**: SwiftData is Apple's local database framework. "Memory (SwiftData)" means "stored locally on your device using Apple's database."

**Resolution**: Term is technically accurate. No change required — Apple reviewers understand SwiftData.

**Severity**: LOW  
**Action**: None (developer audience)

---

## Lock #2: Code File Names in Documentation

**Location**: APP_REVIEW_PACKET.md Safety Gates Table

**Risky Phrasing**: "Enforcement Location: `ApprovalGate.swift`"

**Wrong Inference**: Reviewer may not understand code references.

**Locked Interpretation**: Code file names are provided for verifiability. Reviewers can optionally inspect source. The behavior description is what matters.

**Resolution**: File references enable audit, not confusion. No change required.

**Severity**: LOW  
**Action**: None (enables verification)

---

## Lock #3: Supabase Security Posture

**Location**: ADVERSARIAL_REVIEW.md Section 2.1

**Risky Phrasing**: "Optional sync goes to user-controlled Supabase instance"

**Wrong Inference**: Enterprise reviewer may question Supabase security without explicit posture documentation.

**Locked Interpretation**: 
- Sync is disabled by default
- User must explicitly enable
- Supabase is a user-controlled account (not OperatorKit's servers)
- Only settings/metadata sync — never content
- Enterprise can choose not to enable sync

**Resolution**: Existing copy states "user-controlled" and "disabled by default." Enterprise-specific security documentation is out of scope for v1 (organizational, not architectural).

**Severity**: MEDIUM  
**Action**: None (organizational concern, not product ambiguity)

---

## Lock #4: No Admin Console

**Location**: ADVERSARIAL_REVIEW.md Section 2.3

**Risky Phrasing**: "There is no admin console"

**Wrong Inference**: Enterprise reviewer may expect centralized admin visibility.

**Locked Interpretation**:
- OperatorKit is local-first by design
- No admin console is intentional, not a gap
- Each device operates independently
- Team governance shares procedures, not content visibility

**Resolution**: This is a feature, not a limitation. Explicitly stated in ADVERSARIAL_REVIEW.md.

**Severity**: LOW  
**Action**: None (intentional design)

---

## Lock #5: "On-Device" vs "Cloud" Distinction

**Location**: OnboardingView Page 1

**Risky Phrasing**: "Your on-device productivity assistant"

**Wrong Inference**: User may not immediately understand what "on-device" excludes.

**Locked Interpretation**:
- "On-device" means processing happens locally
- Clarified on Page 2: "Everything runs on your device"
- Clarified on Page 3: "Network: Only for optional cloud sync"

**Resolution**: Sequential onboarding addresses this. No single-screen change needed.

**Severity**: LOW  
**Action**: None (addressed by flow)

---

## Lock #6: "Safety Model" Jargon

**Location**: OnboardingView Page 2

**Risky Phrasing**: Page titled "Safety Model" (internal structure reference)

**Wrong Inference**: User may not understand "safety model" as a concept.

**Locked Interpretation**:
- Title is "You're Always in Control"
- Subtitle is "Nothing happens without your approval"
- "Safety Model" does not appear in user-facing text

**Resolution**: The page title and subtitle are user-friendly. "Safety Model" is code/doc only.

**Severity**: LOW  
**Action**: None (not user-facing)

---

## Lock #7: "Drafted Outcomes" Term

**Location**: PricingView, Free tier description

**Risky Phrasing**: "25 Drafted Outcomes / week"

**Wrong Inference**: User may not know what a "Drafted Outcome" is.

**Locked Interpretation**:
- A "Drafted Outcome" is a prepared result (email, event, reminder) ready for review
- Defined in TERMINOLOGY_CANON.md
- Context makes meaning clear: "Draft emails", "Create calendar events", "Set reminders"

**Resolution**: Term is now canonically defined. In-context usage makes meaning clear.

**Severity**: MEDIUM  
**Action**: Term defined in TERMINOLOGY_CANON.md

---

## Lock #8: "Execution Engine" Naming

**Location**: Internal code, visible in developer documentation

**Risky Phrasing**: "ExecutionEngine.swift"

**Wrong Inference**: "Execution Engine" may imply autonomous execution.

**Locked Interpretation**:
- ExecutionEngine only runs after ApprovalGate.canExecute() returns true
- "Execution" in this context means "carrying out a user-approved action"
- The engine does not decide — it implements approved requests

**Resolution**: Internal naming. External documentation uses "approved execution."

**Severity**: LOW  
**Action**: None (internal naming)

---

## Summary Table

| # | Issue | Severity | Resolution |
|---|-------|----------|------------|
| 1 | SwiftData jargon | LOW | None — developer audience |
| 2 | Code file names | LOW | None — enables verification |
| 3 | Supabase posture | MEDIUM | None — organizational concern |
| 4 | No admin console | LOW | None — intentional design |
| 5 | On-device clarity | LOW | None — addressed by flow |
| 6 | Safety Model jargon | LOW | None — not user-facing |
| 7 | Drafted Outcomes | MEDIUM | Defined in TERMINOLOGY_CANON.md |
| 8 | Execution Engine | LOW | None — internal naming |

**Total Issues**: 8  
**Requiring Copy Change**: 0  
**Requiring Definition**: 1 (now complete)  
**Requiring No Action**: 7

---

---

## Lock #9: "Procedure Sharing" Does NOT Mean "Shared Drafts"

**Location**: Team tier description, ProcedureSharingView

**Risky Phrasing**: "Procedure Sharing"

**Wrong Inference**: User may interpret "sharing" as sharing drafts, emails, or personal content.

**Locked Interpretation**:
- "Procedure" means workflow template (logic only)
- "Sharing" means distributing templates locally
- Procedures contain: intent structure, prompt scaffolding, constraints
- Procedures explicitly exclude: user text, drafts, memory, outputs, identifiers
- See: `docs/PROCEDURE_SHARING_SPEC.md`

**Canonical Definition**: "Procedures share logic, never data."

**Severity**: MEDIUM  
**Action**: Added Phase 13B — Interpretation explicitly locked

---

## Lock #10: "Sovereign Export" Does NOT Mean "Data Backup"

**Location**: SovereignExportView, Export flow

**Risky Phrasing**: "Sovereign Export"

**Wrong Inference**: User may interpret "export" as backing up their emails, drafts, or personal data.

**Locked Interpretation**:
- "Sovereign Export" exports configuration and metadata only
- It is NOT a data backup
- Contents: procedure templates, policy flags, tier, aggregate counts
- Explicitly excludes: drafts, emails, calendar events, memory, personal data
- See: `docs/SOVEREIGN_EXPORT_SPEC.md`

**Canonical Definition**: "Sovereign Export enables user ownership without data exfiltration."

**Severity**: MEDIUM  
**Action**: Added Phase 13C — Interpretation explicitly locked

---

## Lock #11: "Regression Firewall" Does NOT Mean "Monitoring or Telemetry"

**Location**: RegressionFirewallDashboardView, Trust Dashboard

**Risky Phrasing**: "Regression Firewall", "Verification"

**Wrong Inference**: User may interpret "firewall" as a monitoring system that tracks their activity or sends telemetry.

**Locked Interpretation**:
- "Regression Firewall" is a read-only verification surface
- It runs on-demand when user opens the dashboard
- It does NOT monitor, log, or track user activity
- It does NOT send any data anywhere
- It verifies safety guarantees are intact, nothing more
- See: `docs/REGRESSION_FIREWALL_SPEC.md`

**Canonical Definition**: "Trust-by-Construction, made inspectable."

**Severity**: MEDIUM  
**Action**: Added Phase 13D — Interpretation explicitly locked

---

## Lock #12: "Audit Vault" Does NOT Store User Content

**Location**: AuditVaultDashboardView, TrustDashboardView

**Risky Phrasing**: "Audit Vault", "Lineage Tracking", "Edit History"

**Wrong Inference**: User may interpret "Audit Vault" as storing their emails, drafts, or personal content.

**Locked Interpretation**:
- "Audit Vault" stores only hashes, enums, counts, and day-rounded timestamps
- It tracks provenance and edit counts, NOT content
- It NEVER stores: drafts, emails, text, recipients, titles, descriptions, PII
- Lineage shows: "Outcome type X, edited N times, Procedure hash Y, Context slot Z"
- See: `Features/AuditVault/*`

**Canonical Definition**: "Zero-content provenance - hashes and counts only."

**Severity**: MEDIUM  
**Action**: Added Phase 13E — Interpretation explicitly locked

---

## Lock #13: "Security Manifest" Is NOT a Marketing Claim

**Location**: SecurityManifestView, TrustDashboardView, docs/SECURITY_MANIFEST.md

**Risky Phrasing**: "100% WebKit-Free", "0% JavaScript", "Security Manifest"

**Wrong Inference**: User may interpret "Security Manifest" as a marketing promise or blanket security guarantee.

**Locked Interpretation**:
- "Security Manifest" is an auditable, test-backed declaration
- It declares specific, verifiable technical facts (no WebKit, no JS)
- It is NOT a promise that the app has no bugs or security issues
- It is NOT a replacement for professional security audits
- Claims are enforced by automated tests that fail CI if violated
- See: `docs/SECURITY_MANIFEST.md`, `SecurityManifestInvariantTests.swift`

**Canonical Definition**: "Auditable technical declaration, not a marketing promise."

**Severity**: MEDIUM  
**Action**: Added Phase 13F — Interpretation explicitly locked

---

## Lock #14: "Binary Proof" Is NOT Monitoring or User Data Scanning

**Location**: BinaryProofView, TrustDashboardView, docs/BINARY_PROOF_SPEC.md

**Risky Phrasing**: "Binary Proof", "Framework Inspection", "Mach-O Analysis"

**Wrong Inference**: User may interpret "Binary Proof" as a monitoring system that scans their data or tracks app usage.

**Locked Interpretation**:
- "Binary Proof" inspects only the app's own linked frameworks
- It uses public dyld APIs to enumerate loaded images
- It does NOT monitor user activity
- It does NOT scan user data, files, or content
- It does NOT write to disk or send data anywhere
- It provides a one-time snapshot of framework linkage
- See: `docs/BINARY_PROOF_SPEC.md`

**Canonical Definition**: "Read-only binary inspection, not monitoring."

**Severity**: MEDIUM  
**Action**: Added Phase 13G — Interpretation explicitly locked

---

## Lock #15: "Proof Pack" Is NOT Telemetry, Monitoring, or Analytics

**Location**: ProofPackView, TrustDashboardView, docs/PROOF_PACK_SPEC.md

**Risky Phrasing**: "Proof Pack", "Evidence Bundle", "Trust Export"

**Wrong Inference**: User may interpret "Proof Pack" as telemetry, usage analytics, or diagnostic reporting.

**Locked Interpretation**:
- "Proof Pack" is a verification artifact for auditors and enterprises
- It bundles ONLY metadata already visible in Trust Surfaces
- It contains NO user data, NO drafts, NO identifiers, NO paths
- It is exported ONLY when user explicitly taps "Export"
- It is NOT automatically generated or sent anywhere
- It is NOT telemetry, monitoring, diagnostics, or analytics
- See: `docs/PROOF_PACK_SPEC.md`

**Canonical Definition**: "Verification artifact, not telemetry."

**Severity**: HIGH  
**Action**: Added Phase 13H — Interpretation explicitly locked

---

## Lock #16: "Offline Certification" Is Verification, NOT Enforcement

**Location**: OfflineCertificationView, TrustDashboardView, docs/OFFLINE_CERTIFICATION_SPEC.md

**Risky Phrasing**: "Offline Certification", "Zero-Network", "Airplane Mode"

**Wrong Inference**: User may interpret "Offline Certification" as enforcement that blocks network or forces airplane mode.

**Locked Interpretation**:
- "Offline Certification" VERIFIES the app can run offline
- It does NOT enforce offline mode
- It does NOT block network
- It does NOT force airplane mode
- It is user-initiated verification only
- It certifies pipeline ARCHITECTURE, not runtime state
- See: `docs/OFFLINE_CERTIFICATION_SPEC.md`

**Canonical Definition**: "Verification of offline capability, not enforcement."

**Severity**: HIGH  
**Action**: Added Phase 13I — Interpretation explicitly locked

---

## Lock #17: "Build Seals" Are Proof Artifacts, NOT Telemetry

**Location**: BuildSealsView, TrustDashboardView, docs/ENTITLEMENTS_PROOF_SPEC.md, docs/DEPENDENCY_PROOF_SPEC.md, docs/SYMBOL_PROOF_SPEC.md

**Risky Phrasing**: "Build Seals", "Entitlements Seal", "Dependency Seal", "Symbol Seal"

**Wrong Inference**: User may interpret "seals" as tracking, reporting, or sending build information to external parties.

**Locked Interpretation**:
- "Build Seals" are CRYPTOGRAPHIC PROOFS generated at build time
- They are NOT telemetry, analytics, or reporting
- They are NOT sent anywhere — stored in bundle resources only
- They contain ONLY metadata: hashes, counts, booleans
- They VERIFY source integrity without runtime enforcement
- They are REPRODUCIBLE by auditors using standard tools (codesign, nm, otool)
- They complete the trust chain: source → tests → runtime → binary → build seals
- See: `docs/ENTITLEMENTS_PROOF_SPEC.md`, `docs/DEPENDENCY_PROOF_SPEC.md`, `docs/SYMBOL_PROOF_SPEC.md`

**Canonical Definition**: "Build-time proof artifacts, not telemetry. Auditor-reproducible verification."

**Severity**: HIGH  
**Action**: Added Phase 13J — Interpretation explicitly locked

---

## Lock #18: "Security Manifest (UI)" Is Declarative, NOT Enforcement

**Location**: SecurityManifestUIView, TrustDashboardView

**Risky Phrasing**: "Security Manifest", "Security Posture", "Verified Claims"

**Wrong Inference**: User may interpret "Security Manifest" as an enforcement mechanism, firewall, or active protection system.

**Locked Interpretation**:
- The Security Manifest is a DECLARATIVE SURFACE that reflects existing proof artifacts
- It performs NO validation beyond reading existing proofs
- It performs NO enforcement — it cannot block, allow, or modify behavior
- It performs NO telemetry — nothing is sent anywhere
- It is READ-ONLY — no buttons, no toggles, no actions
- Every displayed claim maps to a specific proof source (Binary Proof, Build Seals, Offline Certification, ProofPack)
- It exists so users can SEE what the app can and cannot do — not to control it

**Canonical Definition**: "Declarative proof display, not enforcement. Read-only reflection of existing artifacts."

**Severity**: HIGH  
**Action**: Added Phase L1 — Interpretation explicitly locked

---

## Lock #19: "First-Launch Trust Calibration" Is a Ceremony, NOT Enforcement

**Location**: LaunchTrustCalibrationView, LaunchTrustCalibrationModifier

**Risky Phrasing**: "Trust Calibration", "System Verified", "Verification ceremony"

**Wrong Inference**: User may interpret "Trust Calibration" as a security gate that validates the app, or that the app won't run if calibration fails.

**Locked Interpretation**:
- Trust Calibration is a ONE-TIME, USER-VISIBLE CEREMONY
- It DISPLAYS verification results — it does NOT enforce them
- The app runs REGARDLESS of pass/fail results
- It performs NO enforcement, NO revalidation, NO telemetry
- It has NO security authority — it cannot block or allow anything
- It reads EXISTING proof artifacts — no new computation
- It runs ONCE on first launch, never again (unless reinstalled)
- It is purely UX — to build user trust by showing proof
- A "failed" step means the proof showed a negative result, NOT that the app is blocked

**Canonical Definition**: "One-time UX ceremony that displays existing proof. No enforcement, no security authority."

**Severity**: HIGH  
**Action**: Added Phase L2 — Interpretation explicitly locked

---

## Document Metadata

| Field | Value |
|-------|-------|
| Created | Phase 12C |
| Updated | Phase L2 |
| Classification | Interpretation Lock |
| Copy Changes | 0 |
| New Definitions | 1 |
| Behavior Changes | None |

---

*All identified misinterpretations are now locked. No new risks were introduced.*
