# LAUNCH DILIGENCE PACKET

**Document Type**: Master Index  
**Audience**: IT Directors, General Counsel, Security Reviewers  
**Reading Time**: 10 minutes  
**Phase**: L3

---

## What Is OperatorKit?

OperatorKit is an on-device productivity assistant for iOS that drafts emails, calendar events, and task actions based on user-selected context. All processing happens locally using Apple's on-device models. The app operates in a "draft-first, approval-gated" mode—nothing executes without explicit user confirmation.

---

## Threat Model Assumptions

| Assumption | Status |
|------------|--------|
| Device is trusted (not jailbroken) | ✅ Required |
| iOS File Protection is functional | ✅ Required |
| User controls their own device | ✅ Required |
| Network is untrusted | ✅ Assumed |
| Malicious apps on same device | ⚠️ Out of scope (sandbox isolation) |

**Note**: OperatorKit does not attempt to defend against a compromised OS or jailbroken device. It relies on iOS sandbox and file protection as foundational security.

---

## What "Zero-Network" Means

| Scope | Definition |
|-------|------------|
| Core Pipeline | Intent → Draft → Approval → Execution path has zero network calls |
| On-Device Models | Apple Foundation Models, no API calls |
| Optional Sync | User-initiated only, disabled by default, settings/metadata only |
| URLSession Usage | Confined to `Sync/` module only, never in execution path |

**Verification**: See [OFFLINE_CERTIFICATION_SPEC.md](OFFLINE_CERTIFICATION_SPEC.md) and [AIR_GAPPED_PROOF.md](AIR_GAPPED_PROOF.md).

---

## Evidence Artifacts

| Artifact | What It Proves | Location |
|----------|----------------|----------|
| **ProofPack** | Unified trust evidence bundle | In-app: Trust Dashboard → Proof Pack |
| **Build Seals** | Entitlements, dependencies, symbols | In-app: Trust Dashboard → Build Seals |
| **Binary Proof** | No WebKit/JavaScriptCore linked | In-app: Trust Dashboard → Binary Proof |
| **Offline Certification** | Zero-network pipeline verification | In-app: Trust Dashboard → Offline Certification |
| **Security Manifest** | Declarative security posture | In-app: Trust Dashboard → Security Manifest |

---

## How to Generate ProofPack

### From Inside the App

1. Open OperatorKit
2. Navigate to: **Settings** → **Trust Dashboard**
3. Tap **Proof Pack**
4. Tap **Assemble Proof Pack**
5. Tap **Export Proof Pack**
6. Share via AirDrop, Files, or email

### ProofPack Contents

- Release seal verification status
- Security manifest claims (WebKit, JavaScript, etc.)
- Binary proof summary (framework count, sensitive checks)
- Regression firewall results
- Audit vault aggregate counts
- Offline certification status
- Build seals summary
- Feature flag states

**Note**: ProofPack contains metadata only. No user content, drafts, or identifiers.

---

## How to Generate Build Seals

### Automated (CI/CD)

```bash
# Run from project root after building

# 1. Entitlements Seal
./Scripts/generate_entitlements_seal.sh "$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app"

# 2. Dependency Seal
./Scripts/generate_dependency_seal.sh .

# 3. Symbol Seal
./Scripts/generate_symbol_seal.sh "$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/$PRODUCT_NAME"
```

### Manual Verification

See [TECHNICAL_AUDIT_GUIDE.md](TECHNICAL_AUDIT_GUIDE.md) for step-by-step reproduction.

---

## Auditor Checklist

### Quick Verification (5 minutes)

- [ ] Open app → Trust Dashboard → Security Manifest UI
- [ ] Verify all claims show ✅
- [ ] Export ProofPack and review JSON

### Full Verification (30 minutes)

- [ ] Extract entitlements: `codesign -d --entitlements :- <app>`
- [ ] Verify no `com.apple.security.network.client` (unless sync enabled)
- [ ] Run: `nm -U <binary> | grep -i "urlsession\|webkit\|javascript"`
- [ ] Run: `otool -L <binary> | grep -i "webkit\|javascriptcore"`
- [ ] Compare hashes with Build Seals

### Test Suite Verification

- [ ] Run `OperatorKitTests` target
- [ ] Verify `RegressionFirewallInvariantTests` pass
- [ ] Verify `OfflineCertificationInvariantTests` pass
- [ ] Verify `BuildSealsInvariantTests` pass

---

## Document Index

| Document | Purpose |
|----------|---------|
| [EXECUTIVE_SUMMARY_FOR_COUNSEL.md](EXECUTIVE_SUMMARY_FOR_COUNSEL.md) | Plain English summary for legal review |
| [TECHNICAL_AUDIT_GUIDE.md](TECHNICAL_AUDIT_GUIDE.md) | Reproduction steps for all proofs |
| [WEBSITE_SECURITY_PROOF_COPY.md](WEBSITE_SECURITY_PROOF_COPY.md) | Website-ready copy blocks |
| [APP_STORE_PROOF_LANGUAGE.md](APP_STORE_PROOF_LANGUAGE.md) | App Store-safe language |
| [AIR_GAPPED_PROOF.md](AIR_GAPPED_PROOF.md) | Air-gapped security verification |
| [OFFLINE_CERTIFICATION_SPEC.md](OFFLINE_CERTIFICATION_SPEC.md) | Offline capability specification |
| [BINARY_PROOF_SPEC.md](BINARY_PROOF_SPEC.md) | Mach-O inspection specification |
| [PROOF_PACK_SPEC.md](PROOF_PACK_SPEC.md) | Unified proof bundle specification |
| [SECURITY_MANIFEST.md](SECURITY_MANIFEST.md) | Security claims specification |

---

## Contact

For security inquiries: [security contact to be added]

---

**Document Metadata**

| Field | Value |
|-------|-------|
| Created | Phase L3 |
| Classification | Diligence |
| Runtime Changes | NONE |
