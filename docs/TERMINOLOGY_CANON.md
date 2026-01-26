# TERMINOLOGY CANON

**Document Purpose**: Single, authoritative vocabulary for OperatorKit. All reviewers, buyers, and users should infer the same system behavior from these terms.

**Phase**: 12C  
**Classification**: Interpretation Lock  
**Rule**: No term may be used in-product with a meaning different from this document.

---

## Canon Rules

1. Each term has exactly one meaning
2. Ambiguous synonyms are forbidden
3. Marketing language is forbidden
4. Future-looking language is forbidden
5. Anthropomorphic language is forbidden

---

## Term Definitions

### Drafted Outcome

**Definition**: A prepared result (email draft, calendar event, reminder) that OperatorKit creates for user review before any action occurs.

**What It Is NOT**:
- Not an "execution" — no action has been taken yet
- Not a "generated response" — implies conversational AI
- Not a "suggestion" — implies the system has opinions
- Not an "output" — too vague

**Where It Appears**:
- Free tier limit: "25 Drafted Outcomes / week"
- PricingPackageRegistry.freeWeeklyLimitLabel
- Onboarding flow
- Pricing screens

**Example Usage**: "You have used 3 of 25 drafted outcomes this week."

---

### Execution

**Definition**: The moment when a user-approved drafted outcome becomes a real action (email opens in Mail, reminder is created, calendar event is added).

**What It Is NOT**:
- Not automatic — requires explicit user approval
- Not autonomous — user controls timing
- Not background — only occurs when app is active
- Not scheduled — happens immediately upon approval

**Where It Appears**:
- ApprovalView: "Approve & Execute"
- ExecutionEngine.swift (internal)
- Audit trail records

**Example Usage**: "Execution requires your approval."

---

### Approval

**Definition**: An explicit, deliberate user action (tap) that grants permission for a specific drafted outcome to become a real action.

**What It Is NOT**:
- Not implicit — requires tap, not silence
- Not blanket — approves one action, not all future actions
- Not revocable mid-action — once approved, action proceeds
- Not automatic — never granted by the system

**Where It Appears**:
- ApprovalGate.swift
- ApprovalView.swift
- Two-key confirmation flows

**Example Usage**: "Your approval is required before any action runs."

---

### Procedure

**Definition**: A template or policy configuration that defines how OperatorKit processes certain request types. Procedures are rules, not content.

**What It Is NOT**:
- Not user content — procedures contain no drafts, emails, or calendar data
- Not personal data — procedures are generic templates
- Not shared memory — procedures do not include user history

**Where It Appears**:
- Team tier features
- PolicyTemplate.swift
- Team governance settings

**Example Usage**: "Teams can share procedures without sharing user content."

---

### Procedure Sharing

**Definition**: The ability for Team tier users to distribute policy templates and processing rules across multiple devices, without sharing drafts, memory, or personal data.

**What It Is NOT**:
- Not draft sharing — drafts remain local
- Not memory sharing — memory stays on-device
- Not content sharing — only rules are shared
- Not real-time collaboration — sharing is manual

**Where It Appears**:
- Team tier description
- TeamArtifacts.swift
- Sales playbook

**Example Usage**: "Team tier enables procedure sharing (templates only, not user content)."

---

### On-Device

**Definition**: Processing that occurs entirely within the user's device, using local compute resources, with no data transmitted to external servers.

**What It Is NOT**:
- Not "local-first" — implies eventual sync, which is opt-in only
- Not "offline-capable" — implies online is preferred
- Not "privacy-focused" — marketing language

**Where It Appears**:
- Onboarding Page 1
- APP_REVIEW_PACKET.md
- ModelRouter.swift

**Example Usage**: "All draft generation is on-device."

---

### Cloud Sync (Opt-In)

**Definition**: An optional feature, disabled by default, that allows users to store settings and metadata (not content) in a user-controlled cloud account.

**What It Is NOT**:
- Not enabled by default — user must explicitly enable
- Not content sync — drafts and memory are not synced
- Not automatic — user initiates sync actions
- Not required — app works fully without it

**Where It Appears**:
- SyncConfiguration.swift
- Pro/Team tier features
- PrivacyControlsView

**Example Usage**: "Cloud sync is opt-in. Your drafts stay on your device."

---

### Lifetime Sovereign

**Definition**: A one-time purchase option ($249) that grants permanent Pro tier access without recurring subscription payments.

**What It Is NOT**:
- Not a subscription — no recurring charges
- Not a higher tier — same features as Pro
- Not transferable — tied to Apple ID
- Not "ownership" of the app — license to use

**Where It Appears**:
- PricingView
- StoreKitProductIDs.lifetimeSovereign
- Sales playbook

**Example Usage**: "Lifetime Sovereign: $249 one-time. No subscription."

---

### Team Governance

**Definition**: Administrative controls for Team tier that allow procedure sharing, aggregate diagnostics, and policy distribution — without access to individual user content.

**What It Is NOT**:
- Not content access — admins cannot see drafts
- Not user monitoring — no activity tracking
- Not execution control — admins cannot trigger actions
- Not centralized management — each device operates independently

**Where It Appears**:
- Team tier description
- TeamSettingsView
- Enterprise readiness exports

**Example Usage**: "Team governance covers procedures and policies, not user content."

---

## Forbidden Synonyms

The following terms must NOT be used as they create ambiguity:

| Forbidden Term | Reason | Use Instead |
|----------------|--------|-------------|
| "AI agent" | Implies autonomy | "draft generator" |
| "Assistant thinks" | Anthropomorphic | (remove entirely) |
| "Smart" | Marketing | "on-device" |
| "Learns" | Implies training | "processes" |
| "Remembers" | Implies personalization | "stores locally" |
| "Automatic" | Implies no approval | "requires approval" |
| "Secure" | Unproven claim | "on-device" |
| "Protected" | Unproven claim | "local storage" |
| "Safe" | Unproven claim | "user-controlled" |
| "Execution" (alone) | Implies autonomy | "approved execution" |

---

## Document Metadata

| Field | Value |
|-------|-------|
| Created | Phase 12C |
| Classification | Interpretation Lock |
| Behavior Changes | None |
| New Concepts | None |
| Scope Expansion | None |

---

*This canon freezes terminology interpretation. No term may be redefined without explicit version bump and migration plan.*
