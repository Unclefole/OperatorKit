# OperatorKit Security Evidence Runbook

**Purpose:** This document provides step-by-step instructions for producing verifiable proof of OperatorKit's security claims. It is written for third-party auditors who may have no prior context about the application.

**Version:** 1.0  
**Last Updated:** 2026-01-29

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Audit Environment Setup](#audit-environment-setup)
3. [A. Build Integrity](#a-build-integrity)
4. [B. Binary Analysis](#b-binary-analysis)
5. [C. Network Proof](#c-network-proof)
6. [D. Memory Hygiene](#d-memory-hygiene)
7. [E. Screenshots Required](#e-screenshots-required)
8. [Evidence Checklist](#evidence-checklist)
9. [Appendix: Expected Results](#appendix-expected-results)

---

## Prerequisites

### Required Tools

| Tool | Purpose | Installation |
|------|---------|--------------|
| Xcode 15+ | Build and archive | Mac App Store |
| xcrun | Command-line build tools | `xcode-select --install` |
| nm | Symbol table inspection | Included with Xcode |
| otool | Library dependency analysis | Included with Xcode |
| strings | Binary string extraction | Included with macOS |
| codesign | Entitlements extraction | Included with macOS |
| tcpdump | Network packet capture | Included with macOS |
| lldb | Memory inspection | Included with Xcode |
| shasum | Hash computation | Included with macOS |

### Required Access

- macOS device (Apple Silicon or Intel)
- iOS device or Simulator
- Administrator privileges (for tcpdump)
- Physical access for Airplane Mode testing

---

## Audit Environment Setup

```bash
# 1. Create timestamped audit session directory
AUDIT_DATE=$(date +%Y-%m-%d_%H%M%S)
AUDIT_DIR="SecurityEvidence/AuditSession_${AUDIT_DATE}"
mkdir -p "${AUDIT_DIR}"

# 2. Record environment metadata
echo "Audit Session: ${AUDIT_DATE}" > "${AUDIT_DIR}/session_metadata.txt"
echo "Auditor: $(whoami)" >> "${AUDIT_DIR}/session_metadata.txt"
echo "Machine: $(hostname)" >> "${AUDIT_DIR}/session_metadata.txt"
echo "macOS Version: $(sw_vers -productVersion)" >> "${AUDIT_DIR}/session_metadata.txt"
echo "Xcode Version: $(xcodebuild -version | head -1)" >> "${AUDIT_DIR}/session_metadata.txt"

# 3. Record git state
git rev-parse HEAD >> "${AUDIT_DIR}/session_metadata.txt"
git status >> "${AUDIT_DIR}/session_metadata.txt"
```

---

## A. Build Integrity

**Claim Under Test:** The application binary is reproducible and built from audited source code.

### A.1 Clean Build

```bash
# Navigate to project root
cd /path/to/OperatorKit

# Clean all build artifacts
xcodebuild clean \
  -project OperatorKit.xcodeproj \
  -scheme OperatorKit \
  -configuration Release \
  2>&1 | tee SecurityEvidence/BuildProof/clean_$(date +%Y%m%d_%H%M%S).log
```

**Output Location:** `SecurityEvidence/BuildProof/clean_*.log`

### A.2 Release Build

```bash
# Build for iOS device (Release configuration)
xcodebuild build \
  -project OperatorKit.xcodeproj \
  -scheme OperatorKit \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee SecurityEvidence/BuildProof/build_$(date +%Y%m%d_%H%M%S).log

# Capture exit code
echo "Build exit code: $?" >> SecurityEvidence/BuildProof/build_$(date +%Y%m%d_%H%M%S).log
```

**Output Location:** `SecurityEvidence/BuildProof/build_*.log`

**What This Proves:**
- Source code compiles without errors
- No missing dependencies
- Build-phase guardrails executed (check for "Guardrail" in log)

### A.3 Archive Creation and Hash

```bash
# Create archive
xcodebuild archive \
  -project OperatorKit.xcodeproj \
  -scheme OperatorKit \
  -configuration Release \
  -archivePath SecurityEvidence/BuildProof/OperatorKit.xcarchive \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee SecurityEvidence/BuildProof/archive_$(date +%Y%m%d_%H%M%S).log

# Compute SHA-256 hash of the binary
BINARY_PATH="SecurityEvidence/BuildProof/OperatorKit.xcarchive/Products/Applications/OperatorKit.app/OperatorKit"
shasum -a 256 "${BINARY_PATH}" > SecurityEvidence/BuildProof/binary_hash.txt

# Compute hash of entire archive
find SecurityEvidence/BuildProof/OperatorKit.xcarchive -type f -exec shasum -a 256 {} \; | sort > SecurityEvidence/BuildProof/archive_manifest.txt

# Create single archive hash
shasum -a 256 SecurityEvidence/BuildProof/archive_manifest.txt > SecurityEvidence/BuildProof/archive_hash.txt

cat SecurityEvidence/BuildProof/archive_hash.txt
```

**Output Location:**
- `SecurityEvidence/BuildProof/OperatorKit.xcarchive/`
- `SecurityEvidence/BuildProof/binary_hash.txt`
- `SecurityEvidence/BuildProof/archive_manifest.txt`
- `SecurityEvidence/BuildProof/archive_hash.txt`

**What This Proves:**
- Binary can be uniquely identified by cryptographic hash
- Archive contents are enumerable and verifiable
- Subsequent builds can be compared for reproducibility

---

## B. Binary Analysis

**Claim Under Test:** The compiled binary contains no networking code, frameworks, or capabilities.

### B.1 Strings Inspection

```bash
# Extract all strings from binary
BINARY_PATH="SecurityEvidence/BuildProof/OperatorKit.xcarchive/Products/Applications/OperatorKit.app/OperatorKit"

strings "${BINARY_PATH}" > SecurityEvidence/BinaryAnalysis/all_strings.txt

# Search for network-related strings
grep -iE "(http|https|url|socket|network|wifi|cellular|fetch|request|session|connection|api\.)" \
  SecurityEvidence/BinaryAnalysis/all_strings.txt \
  > SecurityEvidence/BinaryAnalysis/network_strings_grep.txt 2>&1 || true

# Count results
echo "Network-related strings found: $(wc -l < SecurityEvidence/BinaryAnalysis/network_strings_grep.txt | tr -d ' ')" \
  > SecurityEvidence/BinaryAnalysis/strings_summary.txt

cat SecurityEvidence/BinaryAnalysis/strings_summary.txt
```

**Output Location:**
- `SecurityEvidence/BinaryAnalysis/all_strings.txt`
- `SecurityEvidence/BinaryAnalysis/network_strings_grep.txt`
- `SecurityEvidence/BinaryAnalysis/strings_summary.txt`

**What This Proves:**
- No hardcoded URLs, API endpoints, or network-related string literals

### B.2 Symbol Table Analysis (nm -u)

```bash
BINARY_PATH="SecurityEvidence/BuildProof/OperatorKit.xcarchive/Products/Applications/OperatorKit.app/OperatorKit"

# Extract undefined symbols (external dependencies)
nm -u "${BINARY_PATH}" > SecurityEvidence/BinaryAnalysis/undefined_symbols.txt 2>&1

# Search for forbidden networking symbols
FORBIDDEN_SYMBOLS=(
  "URLSession"
  "CFNetwork"
  "NSURLConnection"
  "Socket"
  "nw_"
  "NSURL"
  "NSURLRequest"
  "NSURLResponse"
  "CFSocket"
  "CFHost"
  "CFHTTPMessage"
)

echo "=== Forbidden Symbol Scan ===" > SecurityEvidence/BinaryAnalysis/forbidden_symbols_scan.txt
for SYMBOL in "${FORBIDDEN_SYMBOLS[@]}"; do
  MATCHES=$(grep -i "${SYMBOL}" SecurityEvidence/BinaryAnalysis/undefined_symbols.txt || true)
  if [ -n "${MATCHES}" ]; then
    echo "FOUND: ${SYMBOL}" >> SecurityEvidence/BinaryAnalysis/forbidden_symbols_scan.txt
    echo "${MATCHES}" >> SecurityEvidence/BinaryAnalysis/forbidden_symbols_scan.txt
  else
    echo "CLEAN: ${SYMBOL}" >> SecurityEvidence/BinaryAnalysis/forbidden_symbols_scan.txt
  fi
done

cat SecurityEvidence/BinaryAnalysis/forbidden_symbols_scan.txt
```

**Output Location:**
- `SecurityEvidence/BinaryAnalysis/undefined_symbols.txt`
- `SecurityEvidence/BinaryAnalysis/forbidden_symbols_scan.txt`

**What This Proves:**
- Binary does not link against networking APIs
- No external network library dependencies

### B.3 Library Dependencies (otool -L)

```bash
BINARY_PATH="SecurityEvidence/BuildProof/OperatorKit.xcarchive/Products/Applications/OperatorKit.app/OperatorKit"

# List all linked libraries
otool -L "${BINARY_PATH}" > SecurityEvidence/BinaryAnalysis/linked_libraries.txt

# Check for network-related frameworks
NETWORK_FRAMEWORKS=(
  "CFNetwork"
  "Network.framework"
  "NetworkExtension"
  "WebKit"
  "JavaScriptCore"
  "SafariServices"
  "WebSocket"
)

echo "=== Network Framework Scan ===" > SecurityEvidence/BinaryAnalysis/framework_scan.txt
for FRAMEWORK in "${NETWORK_FRAMEWORKS[@]}"; do
  if grep -qi "${FRAMEWORK}" SecurityEvidence/BinaryAnalysis/linked_libraries.txt; then
    echo "VIOLATION: ${FRAMEWORK} is linked" >> SecurityEvidence/BinaryAnalysis/framework_scan.txt
  else
    echo "CLEAN: ${FRAMEWORK} not linked" >> SecurityEvidence/BinaryAnalysis/framework_scan.txt
  fi
done

cat SecurityEvidence/BinaryAnalysis/framework_scan.txt
```

**Output Location:**
- `SecurityEvidence/BinaryAnalysis/linked_libraries.txt`
- `SecurityEvidence/BinaryAnalysis/framework_scan.txt`

**What This Proves:**
- No network-capable frameworks are linked into the binary
- Application cannot perform network operations at the framework level

### B.4 Entitlements Extraction (codesign)

```bash
APP_PATH="SecurityEvidence/BuildProof/OperatorKit.xcarchive/Products/Applications/OperatorKit.app"

# Extract entitlements (may be empty for ad-hoc signed builds)
codesign -d --entitlements :- "${APP_PATH}" > SecurityEvidence/BinaryAnalysis/entitlements.plist 2>&1 || true

# If signed, check for network entitlements
NETWORK_ENTITLEMENTS=(
  "com.apple.security.network.client"
  "com.apple.security.network.server"
  "com.apple.developer.networking.wifi-info"
  "com.apple.developer.networking.multicast"
  "com.apple.developer.networking.vpn.api"
)

echo "=== Entitlements Network Scan ===" > SecurityEvidence/BinaryAnalysis/entitlements_scan.txt
for ENT in "${NETWORK_ENTITLEMENTS[@]}"; do
  if grep -q "${ENT}" SecurityEvidence/BinaryAnalysis/entitlements.plist 2>/dev/null; then
    echo "VIOLATION: ${ENT}" >> SecurityEvidence/BinaryAnalysis/entitlements_scan.txt
  else
    echo "CLEAN: ${ENT} not present" >> SecurityEvidence/BinaryAnalysis/entitlements_scan.txt
  fi
done

cat SecurityEvidence/BinaryAnalysis/entitlements_scan.txt
```

**Output Location:**
- `SecurityEvidence/BinaryAnalysis/entitlements.plist`
- `SecurityEvidence/BinaryAnalysis/entitlements_scan.txt`

**What This Proves:**
- Application has not requested network entitlements
- App Store / OS-level network restrictions are not bypassed

---

## C. Network Proof

**Claim Under Test:** The application makes zero network connections during operation.

### C.1 Airplane Mode Test (Physical Device)

**Procedure:**

1. Install OperatorKit on physical iOS device
2. Enable Airplane Mode (Settings > Airplane Mode = ON)
3. Disable Wi-Fi and Bluetooth (confirm in Control Center)
4. Launch OperatorKit
5. Navigate through all application screens
6. Perform the following actions:
   - Open Calibration view
   - Create a new draft
   - Review existing content
   - Access settings
   - Run any diagnostic features
7. Observe that all features work without error dialogs

**Evidence Required:**
- Screenshot of Airplane Mode enabled
- Screenshot of OperatorKit functioning
- Screen recording of full test session (optional)

**Output Location:** `SecurityEvidence/Screenshots/airplane_mode_test/`

**What This Proves:**
- Application is fully functional without network connectivity
- No hidden network-dependent features

### C.2 Network Traffic Capture (tcpdump)

**Prerequisites:**
- macOS with iOS Simulator running
- Administrator privileges

```bash
# Identify simulator network interface (usually en0 or bridge100)
ifconfig | grep -A 5 "bridge"

# Start packet capture BEFORE launching app
# Run as root/sudo
sudo tcpdump -i any -w SecurityEvidence/NetworkProof/capture_$(date +%Y%m%d_%H%M%S).pcap \
  host $(ipconfig getifaddr en0) or host localhost &
TCPDUMP_PID=$!

echo "tcpdump started with PID: ${TCPDUMP_PID}"
echo "Now launch OperatorKit in Simulator and perform all operations."
echo "When done, press Enter to stop capture."
read

# Stop capture
sudo kill ${TCPDUMP_PID}

# Analyze capture
tcpdump -r SecurityEvidence/NetworkProof/capture_*.pcap > SecurityEvidence/NetworkProof/capture_readable.txt 2>&1

# Count packets (should be zero or only system noise)
PACKET_COUNT=$(tcpdump -r SecurityEvidence/NetworkProof/capture_*.pcap 2>/dev/null | wc -l | tr -d ' ')
echo "Total packets captured: ${PACKET_COUNT}" > SecurityEvidence/NetworkProof/packet_summary.txt

# Filter for HTTP/HTTPS traffic specifically
tcpdump -r SecurityEvidence/NetworkProof/capture_*.pcap 'tcp port 80 or tcp port 443' \
  > SecurityEvidence/NetworkProof/http_traffic.txt 2>&1 || true

HTTP_PACKETS=$(cat SecurityEvidence/NetworkProof/http_traffic.txt | wc -l | tr -d ' ')
echo "HTTP/HTTPS packets: ${HTTP_PACKETS}" >> SecurityEvidence/NetworkProof/packet_summary.txt

cat SecurityEvidence/NetworkProof/packet_summary.txt
```

**Output Location:**
- `SecurityEvidence/NetworkProof/capture_*.pcap`
- `SecurityEvidence/NetworkProof/capture_readable.txt`
- `SecurityEvidence/NetworkProof/packet_summary.txt`
- `SecurityEvidence/NetworkProof/http_traffic.txt`

**Expected Result:** Zero HTTP/HTTPS packets originating from OperatorKit process.

**What This Proves:**
- No network traffic is generated during application use
- No telemetry, analytics, or data exfiltration

### C.3 Network Link Conditioner Test (Optional)

**Procedure:**

1. Install Network Link Conditioner (Xcode > Additional Tools)
2. Set profile to "100% Loss"
3. Run OperatorKit and verify full functionality
4. Screenshot the Network Link Conditioner settings
5. Screenshot OperatorKit operating normally

**Output Location:** `SecurityEvidence/Screenshots/network_link_conditioner/`

---

## D. Memory Hygiene

**Claim Under Test:** Sensitive data is not persisted in memory longer than necessary and can be verified at runtime.

### D.1 LLDB Heap Inspection

**Prerequisites:**
- Xcode with debugger
- iOS Simulator or device in debug mode

**Procedure:**

```bash
# 1. Launch OperatorKit in Simulator with debugging
xcrun simctl boot "iPhone 17"
xcrun simctl install booted SecurityEvidence/BuildProof/OperatorKit.xcarchive/Products/Applications/OperatorKit.app
xcrun simctl launch --wait-for-debugger booted com.ivacay.OperatorKit &

# 2. Attach lldb
lldb -n OperatorKit
```

**LLDB Commands:**

```lldb
# Attach to process (if not already)
process attach --name OperatorKit

# Continue execution
continue

# --- PERFORM TEST ACTIONS IN APP ---
# Enter known test string in any text field, e.g., "AUDIT_MARKER_12345"

# Pause execution
process interrupt

# Search heap for test marker
memory find --string "AUDIT_MARKER_12345" -- 0x0 0xFFFFFFFFFFFF

# Alternative: Search entire process memory
script
import lldb
target = lldb.debugger.GetSelectedTarget()
process = target.GetProcess()
error = lldb.SBError()
marker = b"AUDIT_MARKER_12345"
found_count = 0
for region in process.GetMemoryRegions():
    # Region analysis
    pass
end

# Record findings
```

**Manual Recording:**

Save lldb session output to: `SecurityEvidence/MemoryProof/lldb_session_$(date +%Y%m%d_%H%M%S).txt`

### D.2 Memory Snapshot Timing

**When to capture memory snapshots:**

| Event | Action | Expected State |
|-------|--------|----------------|
| App Launch | Snapshot after main view loads | No user data in memory |
| After Input | Snapshot after entering test data | Test marker present |
| After Clear | Snapshot after clearing input | Test marker absent |
| After Navigation | Snapshot after leaving screen | Context-specific data cleared |
| App Background | Snapshot 5 seconds after backgrounding | Sensitive data cleared |

**Procedure:**

1. Use Xcode Memory Graph Debugger (Debug > Debug Workflow > View Memory Graph)
2. Export memory graph at each checkpoint
3. Save to `SecurityEvidence/MemoryProof/memory_graph_[checkpoint]_[timestamp].memgraph`

### D.3 Instruments Allocations Check

```bash
# Record allocations trace
xcrun xctrace record \
  --template 'Allocations' \
  --device "iPhone 17 Simulator" \
  --launch com.ivacay.OperatorKit \
  --output SecurityEvidence/MemoryProof/allocations_$(date +%Y%m%d_%H%M%S).trace \
  --time-limit 60s
```

**Output Location:** `SecurityEvidence/MemoryProof/allocations_*.trace`

---

## E. Screenshots Required

**Purpose:** Visual evidence of application state during audit.

### E.1 Calibration Ceremony

Capture screenshots of:
1. Initial calibration prompt
2. Calibration in progress
3. Calibration complete confirmation
4. Trust score display after calibration

**File Naming:** `calibration_[step]_[timestamp].png`

**Output Location:** `SecurityEvidence/Screenshots/calibration/`

### E.2 Trust Dashboard

Capture screenshots of:
1. Trust Dashboard overview
2. Individual trust metrics expanded
3. Any warnings or alerts displayed

**File Naming:** `trust_dashboard_[view]_[timestamp].png`

**Output Location:** `SecurityEvidence/Screenshots/trust_dashboard/`

### E.3 Verification Modules

Capture screenshots of each verification/diagnostic screen:

| Module | Screenshot Required |
|--------|---------------------|
| Privacy Controls | Settings and current state |
| Memory View | Current memory status |
| Diagnostics View | Full diagnostic output |
| Policy Editor | Current policies |
| Quality Report | Latest quality metrics |
| Security Manifest | Full manifest display |
| Launch Readiness | All checklist items |

**File Naming:** `[module_name]_[timestamp].png`

**Output Location:** `SecurityEvidence/Screenshots/modules/`

### E.4 Screenshot Capture Commands

```bash
# Simulator screenshot
xcrun simctl io booted screenshot SecurityEvidence/Screenshots/[name].png

# With timestamp
xcrun simctl io booted screenshot "SecurityEvidence/Screenshots/screen_$(date +%Y%m%d_%H%M%S).png"
```

---

## Evidence Checklist

Use this checklist to verify all evidence has been collected:

### Build Integrity
- [ ] `BuildProof/clean_*.log` - Clean build log
- [ ] `BuildProof/build_*.log` - Release build log
- [ ] `BuildProof/OperatorKit.xcarchive/` - Archive directory
- [ ] `BuildProof/binary_hash.txt` - Binary SHA-256
- [ ] `BuildProof/archive_manifest.txt` - Full archive file list with hashes
- [ ] `BuildProof/archive_hash.txt` - Archive manifest hash

### Binary Analysis
- [ ] `BinaryAnalysis/all_strings.txt` - Complete strings dump
- [ ] `BinaryAnalysis/network_strings_grep.txt` - Network string search results
- [ ] `BinaryAnalysis/strings_summary.txt` - Summary count
- [ ] `BinaryAnalysis/undefined_symbols.txt` - nm -u output
- [ ] `BinaryAnalysis/forbidden_symbols_scan.txt` - Symbol scan results
- [ ] `BinaryAnalysis/linked_libraries.txt` - otool -L output
- [ ] `BinaryAnalysis/framework_scan.txt` - Framework scan results
- [ ] `BinaryAnalysis/entitlements.plist` - Extracted entitlements
- [ ] `BinaryAnalysis/entitlements_scan.txt` - Entitlements scan results

### Network Proof
- [ ] `NetworkProof/capture_*.pcap` - Raw packet capture
- [ ] `NetworkProof/capture_readable.txt` - Human-readable capture
- [ ] `NetworkProof/packet_summary.txt` - Packet count summary
- [ ] `NetworkProof/http_traffic.txt` - HTTP/HTTPS filter results

### Memory Proof
- [ ] `MemoryProof/lldb_session_*.txt` - LLDB session transcript
- [ ] `MemoryProof/allocations_*.trace` - Instruments trace (optional)
- [ ] `MemoryProof/memory_graph_*.memgraph` - Memory graphs (optional)

### Screenshots
- [ ] `Screenshots/calibration/` - Calibration ceremony (minimum 3)
- [ ] `Screenshots/trust_dashboard/` - Trust dashboard views
- [ ] `Screenshots/modules/` - Each verification module
- [ ] `Screenshots/airplane_mode_test/` - Airplane mode evidence

### Session Metadata
- [ ] `AuditSession_*/session_metadata.txt` - Session environment info

---

## Appendix: Expected Results

### A. Build Integrity - Expected

```
Build exit code: 0
** BUILD SUCCEEDED **
```

Build log must contain:
```
[Guardrail] Checking for forbidden network symbols...
No forbidden network symbols detected.

[Guardrail] Checking for forbidden network entitlements...
No forbidden network entitlements detected.
```

### B. Binary Analysis - Expected

**forbidden_symbols_scan.txt:**
```
=== Forbidden Symbol Scan ===
CLEAN: URLSession
CLEAN: CFNetwork
CLEAN: NSURLConnection
CLEAN: Socket
CLEAN: nw_
CLEAN: NSURL
CLEAN: NSURLRequest
CLEAN: NSURLResponse
CLEAN: CFSocket
CLEAN: CFHost
CLEAN: CFHTTPMessage
```

**framework_scan.txt:**
```
=== Network Framework Scan ===
CLEAN: CFNetwork not linked
CLEAN: Network.framework not linked
CLEAN: NetworkExtension not linked
CLEAN: WebKit not linked
CLEAN: JavaScriptCore not linked
CLEAN: SafariServices not linked
CLEAN: WebSocket not linked
```

**entitlements_scan.txt:**
```
=== Entitlements Network Scan ===
CLEAN: com.apple.security.network.client not present
CLEAN: com.apple.security.network.server not present
CLEAN: com.apple.developer.networking.wifi-info not present
CLEAN: com.apple.developer.networking.multicast not present
CLEAN: com.apple.developer.networking.vpn.api not present
```

### C. Network Proof - Expected

**packet_summary.txt:**
```
Total packets captured: [varies - system noise only]
HTTP/HTTPS packets: 0
```

Any HTTP/HTTPS packets indicate a violation.

### D. Memory Hygiene - Expected

- Test markers should NOT persist after:
  - Clearing input fields
  - Navigating away from screens
  - Backgrounding the application

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-29 | OperatorKit Team | Initial runbook |

---

**End of Runbook**
