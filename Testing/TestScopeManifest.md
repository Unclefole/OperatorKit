# TEST SCOPE MANIFEST

**Document Purpose**: Enumerates all allowed test categories and explicitly forbids new categories after Phase 12D.

**Phase**: 12D  
**Classification**: Test Freeze  
**Status**: FROZEN

---

## Test Scope Rules

1. **No new test categories** may be added after Phase 12D
2. Existing tests may be **re-run** or **parameterized**
3. All tests must use **synthetic data only**
4. Tests must be **deterministic and reproducible**

---

## Allowed Test Categories

### Category 1: Safety Invariants

| Test File | Purpose |
|-----------|---------|
| `SafetyInvariantsTests.swift` | Core safety guarantees |
| `ExecutionInvariantsTests.swift` | Execution boundary enforcement |
| `ApprovalInvariantsTests.swift` | Approval gate enforcement |

### Category 2: Content-Free Validation

| Test File | Purpose |
|-----------|---------|
| `ForbiddenKeyTests.swift` | No user content in exports |
| `ContentFreeModelTests.swift` | Models contain no content fields |
| `ExportScannerTests.swift` | Export packets are clean |

### Category 3: Firewall Tests

| Test File | Purpose |
|-----------|---------|
| `ModuleFirewallTests.swift` | Core modules untouched |
| `NetworkFirewallTests.swift` | No unauthorized networking |
| `PermissionFirewallTests.swift` | No unauthorized permissions |

### Category 4: Copy & Language Tests

| Test File | Purpose |
|-----------|---------|
| `BannedWordTests.swift` | No banned words in copy |
| `AppStoreCopyTests.swift` | Store copy compliance |
| `TerminologyCanonTests.swift` | Terminology consistency |
| `InterpretationLockTests.swift` | Interpretation locks valid |

### Category 5: Documentation Tests

| Test File | Purpose |
|-----------|---------|
| `DocIntegrityTests.swift` | Required docs exist |
| `ClaimRegistryTests.swift` | Claims are registered |
| `SafetyContractTests.swift` | Safety contract valid |

### Category 6: Monetization Tests

| Test File | Purpose |
|-----------|---------|
| `PricingRegistryTests.swift` | Pricing is consistent |
| `TierQuotaTests.swift` | Tier limits enforced |
| `ConversionLedgerTests.swift` | Conversion tracking valid |

### Category 7: Growth & Sales Tests

| Test File | Purpose |
|-----------|---------|
| `GrowthEngineInvariantTests.swift` | Growth features safe |
| `SalesPackagingAndPlaybookTests.swift` | Sales kit valid |
| `PipelineModelTests.swift` | Pipeline is content-free |

### Category 8: Review & Audit Tests

| Test File | Purpose |
|-----------|---------|
| `AdversarialReadinessTests.swift` | Adversarial review ready |
| `ExternalReviewDryRunTests.swift` | Review dry-run valid |
| `EnterpriseReadinessTests.swift` | Enterprise packet valid |

### Category 9: Release Seal Tests

| Test File | Purpose |
|-----------|---------|
| `ReleaseCandidateSealTests.swift` | RC seals enforced |
| `LaunchHardeningInvariantTests.swift` | Launch hardening valid |

---

## Forbidden Test Categories

The following test categories are **explicitly forbidden** after Phase 12D:

| Category | Reason |
|----------|--------|
| Integration tests with real services | No real user data |
| End-to-end tests with actual execution | No runtime changes |
| Performance benchmarks | Out of scope |
| UI automation tests | Out of scope |
| Network request tests | No new networking |
| Analytics validation | No analytics |

---

## Synthetic Data Requirements

All test inputs must:

1. Be generated from `SyntheticFixtures.swift`
2. Be clearly labeled as synthetic
3. Use deterministic seeds
4. Never resemble real user content
5. Never include real names, emails, dates, or meetings

---

## Test Execution Rules

| Rule | Enforcement |
|------|-------------|
| All tests must pass | CI required |
| No flaky tests allowed | Deterministic seeds |
| No network calls | Firewall tests |
| No file system side effects | Sandbox enforcement |
| No real user data | Synthetic fixtures only |

---

## Document Metadata

| Field | Value |
|-------|-------|
| Created | Phase 12D |
| Classification | Test Freeze |
| New Categories Allowed | ❌ No |
| Parameterization Allowed | ✅ Yes |
| Synthetic Data Only | ✅ Yes |

---

*This manifest freezes the test scope. No new test categories may be added after Phase 12D.*
