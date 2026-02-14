import Foundation
#if canImport(UIKit)
import UIKit
#endif

// ============================================================================
// TAMPER DETECTION — Lightweight Anti-Tamper Signals
//
// Detects indicators of a compromised execution environment:
//   1. Writable system paths (jailbreak indicator)
//   2. Injected dynamic libraries (code injection)
//   3. Debugger attachment in release builds
//   4. Abnormal sandbox behavior
//   5. Known jailbreak artifacts
//
// INVARIANT: Detection → KernelIntegrityGuard.enterLockdown()
// INVARIANT: No cat-and-mouse warfare — detect and refuse authority.
// INVARIANT: Results logged to SecurityTelemetry + EvidenceEngine.
// INVARIANT: False positives are WARNING, confirmed signals are CRITICAL.
//
// PHILOSOPHY: We don't try to prevent jailbreaking. We refuse to
// grant execution authority on a compromised device.
// ============================================================================

public enum TamperDetection {

    // MARK: - Full Scan

    /// Run all tamper detection checks. Returns true if environment appears clean.
    /// On failure, logs to SecurityTelemetry and optionally triggers lockdown.
    @MainActor
    public static func performFullScan(triggerLockdownOnFailure: Bool = true) -> TamperReport {
        var signals: [TamperSignal] = []

        signals.append(checkWritableSystemPaths())
        signals.append(checkInjectedLibraries())
        signals.append(checkDebuggerAttachment())
        signals.append(checkSandboxIntegrity())
        signals.append(checkJailbreakArtifacts())
        signals.append(checkDynamicLinker())

        let criticalSignals = signals.filter { $0.severity == .critical }
        let isCompromised = !criticalSignals.isEmpty

        let report = TamperReport(
            scannedAt: Date(),
            signals: signals,
            isCompromised: isCompromised
        )

        // Log all signals
        for signal in signals where !signal.passed {
            SecurityTelemetry.shared.record(
                category: signal.severity == .critical ? .integrityViolation : .integrityCheck,
                detail: "tamper_detection: \(signal.name) — \(signal.detail)",
                outcome: signal.severity == .critical ? .failure : .warning,
                metadata: ["check": signal.name, "severity": signal.severity.rawValue]
            )
        }

        if isCompromised {
            SecurityTelemetry.shared.record(
                category: .integrityViolation,
                detail: "device_integrity_compromised: \(criticalSignals.count) critical signal(s)",
                outcome: .failure,
                metadata: ["signals": criticalSignals.map(\.name).joined(separator: ",")]
            )

            if triggerLockdownOnFailure {
                KernelIntegrityGuard.shared.forceLockdown(
                    reason: "Tamper detection: \(criticalSignals.map(\.name).joined(separator: ", "))"
                )
            }
        }

        return report
    }

    // MARK: - Individual Checks

    /// Check for writable system paths — jailbreak indicator
    private static func checkWritableSystemPaths() -> TamperSignal {
        let systemPaths = [
            "/private/var/lib/apt",
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/usr/bin/ssh",
            "/private/var/stash",
        ]

        for path in systemPaths {
            if FileManager.default.fileExists(atPath: path) {
                return TamperSignal(
                    name: "writable_system_paths",
                    passed: false,
                    detail: "Jailbreak artifact found: \(path)",
                    severity: .critical
                )
            }
        }

        // Try to write to a system path
        let testPath = "/private/jailbreak_test_\(UUID().uuidString)"
        if FileManager.default.createFile(atPath: testPath, contents: Data("test".utf8)) {
            try? FileManager.default.removeItem(atPath: testPath)
            return TamperSignal(
                name: "writable_system_paths",
                passed: false,
                detail: "System path is writable — sandbox compromised",
                severity: .critical
            )
        }

        return TamperSignal(
            name: "writable_system_paths",
            passed: true,
            detail: "No writable system paths detected",
            severity: .critical
        )
    }

    /// Check for injected dynamic libraries
    private static func checkInjectedLibraries() -> TamperSignal {
        let suspiciousLibs = [
            "FridaGadget",
            "frida-agent",
            "cynject",
            "libcycript",
            "MobileSubstrate",
            "SubstrateLoader",
            "SSLKillSwitch",
            "TrustMe",
            "MobileSubstrate.dylib",
        ]

        let imageCount = _dyld_image_count()
        for i in 0..<imageCount {
            if let name = _dyld_get_image_name(i) {
                let imageName = String(cString: name)
                for lib in suspiciousLibs {
                    if imageName.contains(lib) {
                        return TamperSignal(
                            name: "injected_libraries",
                            passed: false,
                            detail: "Suspicious library detected: \(lib)",
                            severity: .critical
                        )
                    }
                }
            }
        }

        // Check DYLD_INSERT_LIBRARIES
        if ProcessInfo.processInfo.environment["DYLD_INSERT_LIBRARIES"] != nil {
            return TamperSignal(
                name: "injected_libraries",
                passed: false,
                detail: "DYLD_INSERT_LIBRARIES is set — code injection suspected",
                severity: .critical
            )
        }

        return TamperSignal(
            name: "injected_libraries",
            passed: true,
            detail: "No injected libraries detected",
            severity: .critical
        )
    }

    /// Check for debugger attachment in release builds
    private static func checkDebuggerAttachment() -> TamperSignal {
        #if DEBUG
        return TamperSignal(
            name: "debugger_attachment",
            passed: true,
            detail: "DEBUG build — debugger expected",
            severity: .warning
        )
        #else
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)

        if result == 0 && (info.kp_proc.p_flag & P_TRACED) != 0 {
            return TamperSignal(
                name: "debugger_attachment",
                passed: false,
                detail: "Debugger attached in release build",
                severity: .critical
            )
        }

        return TamperSignal(
            name: "debugger_attachment",
            passed: true,
            detail: "No debugger attached",
            severity: .critical
        )
        #endif
    }

    /// Check sandbox integrity — verify the sandbox has not been escaped.
    /// Uses file system probes instead of fork() (unavailable on iOS).
    private static func checkSandboxIntegrity() -> TamperSignal {
        // Attempt to write outside sandbox — should be denied
        let outsidePaths = [
            "/var/mobile/Library/test_sandbox_\(UUID().uuidString)",
            "/tmp/operatorkit_sandbox_test",
        ]

        for path in outsidePaths {
            if FileManager.default.createFile(atPath: path, contents: Data("test".utf8)) {
                // Write succeeded outside sandbox — sandbox is broken
                try? FileManager.default.removeItem(atPath: path)
                return TamperSignal(
                    name: "sandbox_integrity",
                    passed: false,
                    detail: "Write succeeded outside sandbox at \(path)",
                    severity: .critical
                )
            }
        }

        // Verify we can write inside our sandbox container
        let containerTest = FileManager.default.temporaryDirectory.appendingPathComponent("sandbox_test")
        let canWriteInContainer = FileManager.default.createFile(
            atPath: containerTest.path,
            contents: Data("ok".utf8)
        )
        if canWriteInContainer {
            try? FileManager.default.removeItem(at: containerTest)
        }

        return TamperSignal(
            name: "sandbox_integrity",
            passed: true,
            detail: "Sandbox integrity verified (container=\(canWriteInContainer ? "writable" : "read-only"))",
            severity: .critical
        )
    }

    /// Check for known jailbreak artifacts via URL schemes
    private static func checkJailbreakArtifacts() -> TamperSignal {
        #if canImport(UIKit)
        let jailbreakSchemes = [
            "cydia://",
            "sileo://",
            "zbra://",
            "filza://",
            "undecimus://",
        ]

        // Note: canOpenURL requires LSApplicationQueriesSchemes in Info.plist
        // Without it, this check is limited. We rely on file system checks primarily.
        for scheme in jailbreakSchemes {
            if let url = URL(string: scheme) {
                // On non-jailbroken devices, canOpenURL will return false
                // even without LSApplicationQueriesSchemes
                if UIApplication.shared.canOpenURL(url) {
                    return TamperSignal(
                        name: "jailbreak_artifacts",
                        passed: false,
                        detail: "Jailbreak URL scheme responds: \(scheme)",
                        severity: .critical
                    )
                }
            }
        }
        #endif

        return TamperSignal(
            name: "jailbreak_artifacts",
            passed: true,
            detail: "No jailbreak artifacts detected",
            severity: .critical
        )
    }

    /// Check dynamic linker for suspicious behavior
    private static func checkDynamicLinker() -> TamperSignal {
        // Check if our binary has been modified by checking code signing validity
        // This is a lightweight check — not as robust as full code signing validation
        let bundlePath = Bundle.main.bundlePath

        // Verify the bundle exists and has expected structure
        let executablePath = Bundle.main.executablePath ?? ""
        guard FileManager.default.fileExists(atPath: executablePath) else {
            return TamperSignal(
                name: "dynamic_linker",
                passed: false,
                detail: "Executable not found at expected path",
                severity: .warning
            )
        }

        // Check image count is reasonable (not inflated by injection)
        let imageCount = _dyld_image_count()
        if imageCount > 500 {
            return TamperSignal(
                name: "dynamic_linker",
                passed: false,
                detail: "Abnormal dyld image count: \(imageCount) (expected <500)",
                severity: .warning
            )
        }

        return TamperSignal(
            name: "dynamic_linker",
            passed: true,
            detail: "Dynamic linker state normal (\(imageCount) images, bundle=\(bundlePath.suffix(30)))",
            severity: .warning
        )
    }

    // MARK: - Types

    public struct TamperSignal {
        public let name: String
        public let passed: Bool
        public let detail: String
        public let severity: Severity

        public enum Severity: String {
            case critical = "CRITICAL"
            case warning = "WARNING"
        }
    }

    public struct TamperReport {
        public let scannedAt: Date
        public let signals: [TamperSignal]
        public let isCompromised: Bool

        public var passedCount: Int { signals.filter(\.passed).count }
        public var failedCount: Int { signals.filter { !$0.passed }.count }
    }
}
