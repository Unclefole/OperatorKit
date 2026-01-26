# App Store Submission Checklist

*OperatorKit — Phase 10H*

This checklist ensures OperatorKit is ready for App Store submission.

---

## Pre-Submission Checklist

### 1. Build & Test

- [ ] Build succeeds on all supported architectures
- [ ] All unit tests pass
- [ ] All invariant tests pass
- [ ] No linter errors or warnings
- [ ] TestFlight build distributed and tested

### 2. App Store Connect

- [ ] App created in App Store Connect
- [ ] Bundle ID matches project
- [ ] Provisioning profiles configured
- [ ] Screenshots uploaded (all sizes)
- [ ] App preview video (optional)

### 3. Metadata

- [ ] App name: "OperatorKit"
- [ ] Subtitle: "On-device productivity"
- [ ] Description filled (see `PricingCopy.swift`)
- [ ] Keywords set
- [ ] Categories set (Productivity, Utilities)
- [ ] Age rating completed
- [ ] Copyright notice added

### 4. Privacy

- [ ] Privacy Policy URL provided
- [ ] Privacy Nutrition Labels completed
- [ ] Data collection declaration (minimal):
  - [ ] Usage Data: No
  - [ ] Identifiers: No
  - [ ] Purchases: Yes (handled by Apple)
  - [ ] Diagnostics: No (local only)

---

## Subscription Checklist

### 5. In-App Purchase Configuration

- [ ] **Pro Monthly** created: `com.operatorkit.pro.monthly`
- [ ] **Pro Annual** created: `com.operatorkit.pro.annual`
- [ ] **Team Monthly** created: `com.operatorkit.team.monthly`
- [ ] **Team Annual** created: `com.operatorkit.team.annual`
- [ ] Subscription group created
- [ ] Pricing set for all territories
- [ ] Localized display names

### 6. Subscription Disclosures

- [ ] Auto-renewal terms disclosed in app
- [ ] Terms of Service linked
- [ ] Privacy Policy linked
- [ ] "Restore Purchases" accessible
- [ ] Subscription management link works

### 7. Free Tier Validation

- [ ] App is functional without purchase
- [ ] Free tier limits clearly communicated
- [ ] No forced paywall on launch
- [ ] Paywall can be dismissed

---

## Review Notes

### 8. For App Review Team

Include in "Notes for Review":

```
OperatorKit is a productivity app that processes user requests on-device
using Apple's Foundation Models API. All processing happens locally.

SUBSCRIPTION TIERS:
- Free: 25 executions/week, 10 saved items
- Pro: Unlimited usage, optional cloud sync
- Team: Team governance features

TEST ACCOUNTS:
- No test account required (app works without sign-in)

HOW TO TEST SUBSCRIPTION:
1. Launch app
2. Tap "Pricing" from Settings
3. Select any subscription
4. Complete purchase in sandbox

PRIVACY:
- On-device processing only
- No user content transmitted
- Optional cloud sync is metadata-only
```

### 9. Paywall Review

Reviewers will check:

| Requirement | Status |
|-------------|--------|
| Paywall can be dismissed | ✅ "Not Now" button |
| Free tier is functional | ✅ 25 executions/week |
| Restore purchases available | ✅ Always visible |
| Terms/Privacy linked | ✅ In footer |
| Auto-renewal disclosed | ✅ Required text included |

---

## Safety Guarantees

### 10. Claims Verification

Verify these claims before submission:

| Claim | Verification |
|-------|--------------|
| On-device processing | Foundation Models API used |
| No tracking | No analytics SDKs imported |
| No ads | No ad SDKs imported |
| User approval required | ApprovalGate enforced |
| Data stays on device | No content transmission |

### 11. Test Files to Run

```bash
# Run all invariant tests
xcodebuild test -scheme OperatorKit -testPlan InvariantTests

# Key test files:
# - MonetizationEnforcementInvariantTests.swift
# - CommercialReadinessTests.swift
# - SyncInvariantTests.swift
```

---

## Post-Submission

### 12. After Approval

- [ ] Update version in codebase
- [ ] Tag release in git
- [ ] Update CHANGELOG.md
- [ ] Prepare release notes
- [ ] Monitor crash reports

### 13. Common Rejection Reasons

| Reason | Prevention |
|--------|------------|
| Forced paywall | "Not Now" always available |
| No restore option | Restore button visible |
| Missing terms | Links in paywall footer |
| Unclear subscription | Auto-renewal text included |
| Broken free tier | Test without subscription |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Phase 10H | Initial checklist |

---

*This checklist is referenced by `APP_REVIEW_PACKET.md`*
