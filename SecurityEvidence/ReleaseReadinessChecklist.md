# OperatorKit Release Readiness Checklist

**Purpose:** This checklist MUST be completed and signed off by a human reviewer before ANY TestFlight submission. Incomplete or missing evidence is a hard block.

**Version:** 2.0  
**Last Updated:** 2026-01-29

---

## SUBMISSION BLOCKED UNTIL ALL ITEMS PASS

```
┌─────────────────────────────────────────────────────────────────┐
│  ⛔ DO NOT SUBMIT TO TESTFLIGHT IF ANY ITEM IS UNCHECKED ⛔     │
│                                                                 │
│  This checklist requires HUMAN VERIFICATION.                    │
│  Auto-generated passes are NOT accepted.                        │
│  Each item must have corresponding evidence in /SecurityEvidence│
└─────────────────────────────────────────────────────────────────┘
```

---

## Pre-Submission Metadata

| Field | Value |
|-------|-------|
| Build Number | __________________ |
| Version | __________________ |
| Git Commit SHA | __________________ |
| Archive Date | __________________ |
| Reviewer Name | __________________ |
| Review Date | __________________ |

---

## Section 1: Build Guardrails

**FAIL if any guardrail script is missing or disabled.**

### 1.1 Forbidden Symbols Guardrail

| Check | Status | Evidence Location |
|-------|--------|-------------------|
| [ ] `[Guardrail] Check Forbidden Symbols` build phase exists | ⬜ PASS / ⬜ FAIL | Xcode Project > Build Phases |
| [ ] Script scans for: URLSession, CFNetwork, NSURLConnection, Socket, nw_, NSURL | ⬜ PASS / ⬜ FAIL | `Scripts/check_forbidden_symbols.sh` |
| [ ] Script exits with non-zero on violation | ⬜ PASS / ⬜ FAIL | Script source inspection |
| [ ] Build log shows "No forbidden network symbols detected" | ⬜ PASS / ⬜ FAIL | `BuildProof/build_*.log` |

**HARD FAIL CONDITIONS:**
- Guardrail build phase is missing
- Guardrail is commented out or disabled
- Build log does not contain guardrail output
- Any forbidden symbol is detected

### 1.2 Forbidden Entitlements Guardrail

| Check | Status | Evidence Location |
|-------|--------|-------------------|
| [ ] `[Guardrail] Check Forbidden Entitlements` build phase exists | ⬜ PASS / ⬜ FAIL | Xcode Project > Build Phases |
| [ ] Script scans for: com.apple.security.network, com.apple.developer.networking | ⬜ PASS / ⬜ FAIL | `Scripts/check_forbidden_entitlements.sh` |
| [ ] Script exits with non-zero on violation | ⬜ PASS / ⬜ FAIL | Script source inspection |
| [ ] Build log shows "No forbidden network entitlements detected" | ⬜ PASS / ⬜ FAIL | `BuildProof/build_*.log` |

**HARD FAIL CONDITIONS:**
- Guardrail build phase is missing
- Any network entitlement is present
- Build log missing entitlement check output

### 1.3 Build Integrity

| Check | Status | Evidence Location |
|-------|--------|-------------------|
| [ ] Clean build completed without errors | ⬜ PASS / ⬜ FAIL | `BuildProof/clean_*.log` |
| [ ] Release build completed without errors | ⬜ PASS / ⬜ FAIL | `BuildProof/build_*.log` |
| [ ] Archive created successfully | ⬜ PASS / ⬜ FAIL | `BuildProof/archive_*.log` |
| [ ] Binary hash recorded | ⬜ PASS / ⬜ FAIL | `BuildProof/binary_hash.txt` |
| [ ] Archive manifest generated | ⬜ PASS / ⬜ FAIL | `BuildProof/archive_manifest.txt` |

**HARD FAIL CONDITIONS:**
- Build exits with non-zero status
- Archive creation fails
- Binary hash file is missing or empty

---

## Section 2: Network Proof

**FAIL if network capability exists OUTSIDE the documented Sync exception.**

```
┌─────────────────────────────────────────────────────────────────┐
│  ⚠️  IMPORTANT: SCOPED AIR-GAP CLAIM                            │
│                                                                 │
│  OperatorKit Core Verification Mode is fully air-gapped.        │
│  The Sync module (/Sync/) is a DOCUMENTED EXCEPTION:            │
│  - OFF by default                                               │
│  - User-initiated only                                          │
│  - Metadata-only uploads                                        │
│                                                                 │
│  Network symbols in /Sync/ are EXPECTED and NOT a violation.    │
└─────────────────────────────────────────────────────────────────┘
```

### 2.1 Binary Symbol Analysis (SCOPED)

| Check | Status | Evidence Location |
|-------|--------|-------------------|
| [ ] `nm -u` output captured | ⬜ PASS / ⬜ FAIL | `BinaryAnalysis/undefined_symbols.txt` |
| [ ] URLSession symbols: ONLY IN `/Sync/` module | ⬜ PASS / ⬜ FAIL | `BinaryAnalysis/scoped_symbol_audit.txt` |
| [ ] CFNetwork symbols: ONLY via URLSession dependency | ⬜ PASS / ⬜ FAIL | `BinaryAnalysis/scoped_symbol_audit.txt` |
| [ ] NSURLConnection symbols: NONE FOUND | ⬜ PASS / ⬜ FAIL | `BinaryAnalysis/forbidden_symbols_scan.txt` |
| [ ] Socket symbols: NONE FOUND | ⬜ PASS / ⬜ FAIL | `BinaryAnalysis/forbidden_symbols_scan.txt` |
| [ ] nw_ symbols: NONE FOUND | ⬜ PASS / ⬜ FAIL | `BinaryAnalysis/forbidden_symbols_scan.txt` |
| [ ] Core modules (ExecutionEngine, ApprovalGate, ModelRouter): ZERO network imports | ⬜ PASS / ⬜ FAIL | Code review / grep |

**HARD FAIL CONDITIONS:**
- URLSession usage found OUTSIDE `/Sync/` directory
- Network imports in ExecutionEngine, ApprovalGate, ModelRouter, DraftGenerator, or ContextAssembler
- Symbol analysis files are missing
- NSURLConnection or raw Socket usage anywhere

### 2.2 Framework Dependency Analysis (SCOPED)

| Check | Status | Evidence Location |
|-------|--------|-------------------|
| [ ] `otool -L` output captured | ⬜ PASS / ⬜ FAIL | `BinaryAnalysis/linked_libraries.txt` |
| [ ] CFNetwork.framework: ALLOWED (via URLSession for Sync) | ⬜ EXPECTED / ⬜ N/A | `BinaryAnalysis/framework_scan.txt` |
| [ ] Network.framework: NOT LINKED directly | ⬜ PASS / ⬜ FAIL | `BinaryAnalysis/framework_scan.txt` |
| [ ] NetworkExtension.framework: NOT LINKED | ⬜ PASS / ⬜ FAIL | `BinaryAnalysis/framework_scan.txt` |
| [ ] WebKit.framework: NOT LINKED | ⬜ PASS / ⬜ FAIL | `BinaryAnalysis/framework_scan.txt` |

**HARD FAIL CONDITIONS:**
- NetworkExtension.framework linked (VPN/filtering capability)
- WebKit.framework linked (web content loading)
- Direct Network.framework linking (beyond URLSession dependency)

### 2.3 Entitlements Analysis

| Check | Status | Evidence Location |
|-------|--------|-------------------|
| [ ] Entitlements extracted via codesign | ⬜ PASS / ⬜ FAIL | `BinaryAnalysis/entitlements.plist` |
| [ ] com.apple.security.network.client: NOT PRESENT | ⬜ PASS / ⬜ FAIL | `BinaryAnalysis/entitlements_scan.txt` |
| [ ] com.apple.security.network.server: NOT PRESENT | ⬜ PASS / ⬜ FAIL | `BinaryAnalysis/entitlements_scan.txt` |
| [ ] com.apple.developer.networking.*: NOT PRESENT | ⬜ PASS / ⬜ FAIL | `BinaryAnalysis/entitlements_scan.txt` |

**HARD FAIL CONDITIONS:**
- Any network entitlement is present
- Entitlements file cannot be extracted

### 2.4 Sync Module Exception Verification

**The Sync module is the ONLY permitted network code. Verify its constraints:**

| Check | Status | Evidence Location |
|-------|--------|-------------------|
| [ ] `SyncFeatureFlag.defaultToggleState = false` | ⬜ PASS / ⬜ FAIL | `Sync/NetworkAllowance.swift` |
| [ ] `assertSyncEnabled()` guard present in all network methods | ⬜ PASS / ⬜ FAIL | `Sync/SupabaseClient.swift` |
| [ ] AIR-GAP EXCEPTION header present in SupabaseClient.swift | ⬜ PASS / ⬜ FAIL | Code review |
| [ ] AIR-GAP EXCEPTION header present in TeamSupabaseClient.swift | ⬜ PASS / ⬜ FAIL | Code review |
| [ ] SyncPacketValidator blocks forbidden content keys | ⬜ PASS / ⬜ FAIL | `SyncInvariantTests` |
| [ ] No Sync imports in ExecutionEngine.swift | ⬜ PASS / ⬜ FAIL | `grep "import.*Sync" ExecutionEngine.swift` |
| [ ] No Sync imports in ApprovalGate.swift | ⬜ PASS / ⬜ FAIL | `grep "import.*Sync" ApprovalGate.swift` |

**HARD FAIL CONDITIONS:**
- Sync is ON by default
- `assertSyncEnabled()` guard missing from any public network method
- Sync module imports found in core execution modules
- AIR-GAP EXCEPTION documentation missing

---

### 2.5 Runtime Network Test (Core Features)

| Check | Status | Evidence Location |
|-------|--------|-------------------|
| [ ] Airplane Mode test completed | ⬜ PASS / ⬜ FAIL | `Screenshots/airplane_mode_test/` |
| [ ] Core features fully functional in Airplane Mode | ⬜ PASS / ⬜ FAIL | `Screenshots/airplane_mode_test/` |
| [ ] Draft generation works offline | ⬜ PASS / ⬜ FAIL | Screenshot evidence |
| [ ] Approval flow works offline | ⬜ PASS / ⬜ FAIL | Screenshot evidence |
| [ ] ProofPack export works offline | ⬜ PASS / ⬜ FAIL | Screenshot evidence |
| [ ] tcpdump/PCAP capture performed | ⬜ PASS / ⬜ FAIL | `NetworkProof/capture_*.pcap` |
| [ ] HTTP/HTTPS packets from core features: ZERO | ⬜ PASS / ⬜ FAIL | `NetworkProof/packet_summary.txt` |
| [ ] Sync features show graceful "offline" state | ⬜ PASS / ⬜ FAIL | Screenshot evidence |

**HARD FAIL CONDITIONS:**
- Core features fail in Airplane Mode
- Any HTTP/HTTPS packets originate from non-Sync code paths
- App crashes when Sync is enabled but network unavailable
- Network error dialogs shown for core (non-Sync) features

---

## Section 3: Binary Proof

**FAIL if binary contains unexpected content.**

### 3.1 Strings Analysis

| Check | Status | Evidence Location |
|-------|--------|-------------------|
| [ ] Full strings dump captured | ⬜ PASS / ⬜ FAIL | `BinaryAnalysis/all_strings.txt` |
| [ ] Network-related strings scanned | ⬜ PASS / ⬜ FAIL | `BinaryAnalysis/network_strings_grep.txt` |
| [ ] No hardcoded URLs found | ⬜ PASS / ⬜ FAIL | Manual review of strings |
| [ ] No API endpoints found | ⬜ PASS / ⬜ FAIL | Manual review of strings |
| [ ] No analytics/tracking identifiers | ⬜ PASS / ⬜ FAIL | Manual review of strings |

**HARD FAIL CONDITIONS:**
- Hardcoded HTTP/HTTPS URLs found (excluding Apple system URLs)
- Third-party analytics identifiers present
- API keys or secrets in binary

### 3.2 Code Signature Verification

| Check | Status | Evidence Location |
|-------|--------|-------------------|
| [ ] Code signature valid | ⬜ PASS / ⬜ FAIL | `codesign -v` output |
| [ ] No unexpected embedded frameworks | ⬜ PASS / ⬜ FAIL | `BinaryAnalysis/linked_libraries.txt` |
| [ ] Bundle identifier matches expected | ⬜ PASS / ⬜ FAIL | Info.plist inspection |

**HARD FAIL CONDITIONS:**
- Code signature invalid
- Unexpected frameworks embedded

---

## Section 4: Memory Proof

**FAIL if memory hygiene cannot be verified.**

### 4.1 Memory Analysis (if performed)

| Check | Status | Evidence Location |
|-------|--------|-------------------|
| [ ] LLDB session log captured (optional) | ⬜ PASS / ⬜ SKIP | `MemoryProof/lldb_session_*.txt` |
| [ ] No sensitive data persists after clear | ⬜ PASS / ⬜ SKIP | LLDB session evidence |
| [ ] URLCache is empty | ⬜ PASS / ⬜ FAIL | Case study or manual check |
| [ ] No URL-related UserDefaults keys | ⬜ PASS / ⬜ FAIL | Case study output |

**HARD FAIL CONDITIONS:**
- URLCache contains cached data
- Sensitive test markers persist after clearing

### 4.2 Security Case Studies (DEBUG builds only)

**Core Case Studies:**

| Check | Status | Evidence Location |
|-------|--------|-------------------|
| [ ] CS-NET-001 (Ghost Packet): PASSED | ⬜ PASS / ⬜ FAIL | `Logs/casestudy_CS-NET-001_*.json` |
| [ ] CS-MEM-001 (Residual Memory): PASSED | ⬜ PASS / ⬜ FAIL | `Logs/casestudy_CS-MEM-001_*.json` |
| [ ] CS-LEAK-001 (Metadata Leakage): PASSED | ⬜ PASS / ⬜ FAIL | `Logs/casestudy_CS-LEAK-001_*.json` |

**Adversarial Stress Test Case Studies:**

| Check | Status | Evidence Location |
|-------|--------|-------------------|
| [ ] CS-NET-002 (Zero Networking): PASSED | ⬜ PASS / ⬜ FAIL | `Logs/casestudy_CS-NET-002_*.json` |
| [ ] CS-LEAK-002 (ProofPack Integrity): PASSED | ⬜ PASS / ⬜ FAIL | `Logs/casestudy_CS-LEAK-002_*.json` |
| [ ] CS-SEAL-001 (Runtime Seal Bypass): PASSED | ⬜ PASS / ⬜ FAIL | `Logs/casestudy_CS-SEAL-001_*.json` |
| [ ] CS-APPROVAL-001 (ApprovalGate Coercion): PASSED | ⬜ PASS / ⬜ FAIL | `Logs/casestudy_CS-APPROVAL-001_*.json` |
| [ ] CS-BUILD-001 (Build System Integrity): PASSED | ⬜ PASS / ⬜ FAIL | `Logs/casestudy_CS-BUILD-001_*.json` |

**Suite Summary:**

| Check | Status | Evidence Location |
|-------|--------|-------------------|
| [ ] All case studies executed | ⬜ PASS / ⬜ FAIL | `Logs/casestudy_suite_*.json` |
| [ ] No case study shows "FAILED" outcome | ⬜ PASS / ⬜ FAIL | `Logs/casestudy_suite_*.json` |
| [ ] Total passed >= 8 | ⬜ PASS / ⬜ FAIL | Suite summary |

**HARD FAIL CONDITIONS:**
- Any security case study returns "FAILED"
- Case study results missing for DEBUG verification build
- CS-NET-002 fails (critical air-gap verification)
- CS-APPROVAL-001 fails (critical access control verification)

---

## Section 5: Screenshot Proof

**FAIL if required screenshots are missing.**

### 5.1 Calibration Evidence

| Check | Status | Evidence Location |
|-------|--------|-------------------|
| [ ] Calibration initial prompt screenshot | ⬜ PASS / ⬜ FAIL | `Screenshots/calibration/` |
| [ ] Calibration in-progress screenshot | ⬜ PASS / ⬜ FAIL | `Screenshots/calibration/` |
| [ ] Calibration complete screenshot | ⬜ PASS / ⬜ FAIL | `Screenshots/calibration/` |

**HARD FAIL CONDITIONS:**
- Calibration screenshots missing
- Screenshots show error states

### 5.2 Trust Dashboard Evidence

| Check | Status | Evidence Location |
|-------|--------|-------------------|
| [ ] Trust Dashboard overview screenshot | ⬜ PASS / ⬜ FAIL | `Screenshots/trust_dashboard/` |
| [ ] Trust metrics visible and non-zero | ⬜ PASS / ⬜ FAIL | Visual inspection |

**HARD FAIL CONDITIONS:**
- Trust Dashboard screenshot missing
- Dashboard shows error or zero trust state

### 5.3 Verification Module Evidence

| Check | Status | Evidence Location |
|-------|--------|-------------------|
| [ ] Privacy Controls screenshot | ⬜ PASS / ⬜ FAIL | `Screenshots/modules/` |
| [ ] Diagnostics View screenshot | ⬜ PASS / ⬜ FAIL | `Screenshots/modules/` |
| [ ] Security Manifest screenshot | ⬜ PASS / ⬜ FAIL | `Screenshots/modules/` |
| [ ] Launch Readiness screenshot | ⬜ PASS / ⬜ FAIL | `Screenshots/modules/` |
| [ ] Quality Report screenshot | ⬜ PASS / ⬜ FAIL | `Screenshots/modules/` |

**HARD FAIL CONDITIONS:**
- Any required module screenshot missing
- Screenshots show error states or crashes

---

## Final Verification

### Reviewer Certification

```
I, _________________________ (print name), certify that:

1. I have personally verified each item in this checklist
2. All referenced evidence files exist in /SecurityEvidence/
3. No items are marked FAIL
4. This verification was performed on the EXACT build being submitted
5. I understand that false certification may result in App Store rejection

Signature: _________________________

Date: _________________________

Build Number Verified: _________________________
```

### Secondary Review (Required for Production Releases)

```
Secondary Reviewer: _________________________

Date: _________________________

Signature: _________________________

[ ] I confirm independent verification of critical security items
```

---

## Submission Decision

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  [ ] ALL CHECKS PASSED - APPROVED FOR TESTFLIGHT               │
│                                                                 │
│  [ ] ONE OR MORE CHECKS FAILED - SUBMISSION BLOCKED            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

If blocked, list failing items:

1. _______________________________________________
2. _______________________________________________
3. _______________________________________________

---

## Appendix: Quick Verification Commands

```bash
# Generate all evidence (run from project root)
cd /path/to/OperatorKit

# 1. Build and capture logs
xcodebuild clean -project OperatorKit.xcodeproj -scheme OperatorKit 2>&1 | tee SecurityEvidence/BuildProof/clean_$(date +%Y%m%d).log
xcodebuild build -project OperatorKit.xcodeproj -scheme OperatorKit -configuration Release 2>&1 | tee SecurityEvidence/BuildProof/build_$(date +%Y%m%d).log

# 2. Binary analysis
BINARY="path/to/OperatorKit.app/OperatorKit"
nm -u "$BINARY" > SecurityEvidence/BinaryAnalysis/undefined_symbols.txt
otool -L "$BINARY" > SecurityEvidence/BinaryAnalysis/linked_libraries.txt
strings "$BINARY" > SecurityEvidence/BinaryAnalysis/all_strings.txt

# 3. Hash
shasum -a 256 "$BINARY" > SecurityEvidence/BuildProof/binary_hash.txt

# 4. Scoped symbol audit (verify URLSession ONLY in Sync)
echo "=== SCOPED SYMBOL AUDIT ===" > SecurityEvidence/BinaryAnalysis/scoped_symbol_audit.txt
echo "" >> SecurityEvidence/BinaryAnalysis/scoped_symbol_audit.txt
echo "URLSession usage locations:" >> SecurityEvidence/BinaryAnalysis/scoped_symbol_audit.txt
grep -rn "URLSession" OperatorKit/ --include="*.swift" >> SecurityEvidence/BinaryAnalysis/scoped_symbol_audit.txt
echo "" >> SecurityEvidence/BinaryAnalysis/scoped_symbol_audit.txt
echo "Core modules network import check:" >> SecurityEvidence/BinaryAnalysis/scoped_symbol_audit.txt
grep -l "URLSession\|CFNetwork\|import Network" OperatorKit/Domain/ OperatorKit/Models/ 2>/dev/null || echo "CLEAN: No network imports in core modules"

# 5. Sync module constraint verification
echo "=== SYNC MODULE VERIFICATION ===" >> SecurityEvidence/BinaryAnalysis/scoped_symbol_audit.txt
grep "defaultToggleState" OperatorKit/Sync/NetworkAllowance.swift >> SecurityEvidence/BinaryAnalysis/scoped_symbol_audit.txt
grep "assertSyncEnabled" OperatorKit/Sync/SupabaseClient.swift | wc -l | xargs echo "assertSyncEnabled() calls:" >> SecurityEvidence/BinaryAnalysis/scoped_symbol_audit.txt

# 6. Run security case studies (DEBUG build only)
# In Xcode or via test: SecurityCaseStudies.runAll()
# Expected output: 8 case studies, all PASSED
```

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-29 | OperatorKit Team | Initial checklist |
| 2.0 | 2026-01-29 | OperatorKit Team | Added Sync exception scoping, adversarial case studies (CS-NET-002 through CS-BUILD-001), Sync module verification section |

---

**END OF CHECKLIST**

```
This document must be physically signed or have digital signature.
Unsigned checklists are invalid for submission approval.
```
