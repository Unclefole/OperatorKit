import Foundation
import CryptoKit

// ============================================================================
// ATOMIC FILE WRITER (Hardening Phase)
//
// Provides crash-safe file writes with:
// - Atomic tmp -> final replace
// - Automatic backup before overwrite
// - SHA256 checksum for tamper detection
// - Recovery from corrupted main file via backup
//
// CONSTRAINTS:
// ❌ No networking
// ✅ Local storage only
// ✅ File protection: completeUntilFirstUserAuthentication
// ✅ Non-fatal on failure (log + continue)
//
// See: docs/SAFETY_CONTRACT.md
// ============================================================================

/// Crash-safe file writer with backup and checksum support
public final class AtomicFileWriter {

    // MARK: - Errors

    public enum WriterError: Error {
        case directoryCreationFailed(Error)
        case encodingFailed(Error)
        case writeFailed(Error)
        case checksumWriteFailed(Error)
        case backupFailed(Error)
        case replaceFailed(Error)
    }

    // MARK: - Write

    /// Writes data atomically with backup and checksum
    /// - Parameters:
    ///   - data: Data to write
    ///   - url: Target file URL
    ///   - backupURL: Optional backup location (created before overwrite)
    ///   - checksumURL: Optional checksum file location
    /// - Returns: true if successful, false otherwise (errors are logged)
    @discardableResult
    public static func writeAtomically(
        data: Data,
        to url: URL,
        backupURL: URL? = nil,
        checksumURL: URL? = nil
    ) -> Bool {
        let fileManager = FileManager.default

        // 1. Ensure directory exists
        let directory = url.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [
                    .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
                ]
            )
        } catch {
            logError("AtomicFileWriter: Directory creation failed: \(error)", category: .diagnostics)
            return false
        }

        // 2. Create backup of existing file (if exists and backup URL provided)
        if let backupURL = backupURL, fileManager.fileExists(atPath: url.path) {
            do {
                // Remove old backup if exists
                if fileManager.fileExists(atPath: backupURL.path) {
                    try fileManager.removeItem(at: backupURL)
                }
                try fileManager.copyItem(at: url, to: backupURL)
            } catch {
                logError("AtomicFileWriter: Backup creation failed: \(error)", category: .diagnostics)
                // Continue anyway - backup is optional safety net
            }
        }

        // 3. Write to temp file
        let tempURL = url.appendingPathExtension("tmp")
        do {
            try data.write(
                to: tempURL,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
        } catch {
            logError("AtomicFileWriter: Temp write failed: \(error)", category: .diagnostics)
            return false
        }

        // 4. Replace main file with temp file
        do {
            if fileManager.fileExists(atPath: url.path) {
                _ = try fileManager.replaceItemAt(url, withItemAt: tempURL)
            } else {
                try fileManager.moveItem(at: tempURL, to: url)
            }
        } catch {
            logError("AtomicFileWriter: Replace failed: \(error)", category: .diagnostics)
            // Clean up temp file
            try? fileManager.removeItem(at: tempURL)
            return false
        }

        // 5. Write checksum (if URL provided)
        if let checksumURL = checksumURL {
            let checksum = computeChecksum(data)
            do {
                try checksum.write(
                    to: checksumURL,
                    atomically: true,
                    encoding: .utf8
                )
            } catch {
                logError("AtomicFileWriter: Checksum write failed: \(error)", category: .diagnostics)
                // Continue - checksum is optional tamper detection
            }
        }

        return true
    }

    // MARK: - Read with Recovery

    /// Reads data with automatic recovery from backup if main file is corrupted
    /// - Parameters:
    ///   - url: Main file URL
    ///   - backupURL: Backup file URL to try if main fails
    ///   - checksumURL: Checksum file URL for integrity verification
    /// - Returns: Tuple of (data, wasRecovered) or nil if both files fail
    public static func readWithRecovery(
        from url: URL,
        backupURL: URL?,
        checksumURL: URL?
    ) -> (data: Data, wasRecovered: Bool)? {
        let fileManager = FileManager.default

        // 1. Try reading main file
        if let data = try? Data(contentsOf: url) {
            // Verify checksum if available
            if let checksumURL = checksumURL,
               let storedChecksum = try? String(contentsOf: checksumURL, encoding: .utf8) {
                let computedChecksum = computeChecksum(data)
                if storedChecksum.trimmingCharacters(in: .whitespacesAndNewlines) == computedChecksum {
                    return (data, false)
                } else {
                    logError("AtomicFileWriter: Checksum mismatch, trying backup", category: .diagnostics)
                }
            } else {
                // No checksum to verify, trust the data
                return (data, false)
            }
        }

        // 2. Main file failed or corrupted, try backup
        guard let backupURL = backupURL,
              fileManager.fileExists(atPath: backupURL.path),
              let backupData = try? Data(contentsOf: backupURL) else {
            return nil
        }

        logDebug("AtomicFileWriter: Recovered from backup", category: .diagnostics)

        // 3. Restore backup to main
        do {
            try backupData.write(
                to: url,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )

            // Update checksum for restored data
            if let checksumURL = checksumURL {
                let checksum = computeChecksum(backupData)
                try? checksum.write(to: checksumURL, atomically: true, encoding: .utf8)
            }
        } catch {
            logError("AtomicFileWriter: Failed to restore backup to main: \(error)", category: .diagnostics)
            // Still return the backup data even if we couldn't restore it
        }

        return (backupData, true)
    }

    // MARK: - Checksum

    /// Computes SHA256 checksum of data
    /// - Parameter data: Data to checksum
    /// - Returns: Hex string of SHA256 hash
    public static func computeChecksum(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Verifies data matches expected checksum
    /// - Parameters:
    ///   - data: Data to verify
    ///   - expectedChecksum: Expected SHA256 hex string
    /// - Returns: true if checksums match
    public static func verifyChecksum(_ data: Data, expected expectedChecksum: String) -> Bool {
        let computed = computeChecksum(data)
        return computed == expectedChecksum.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
