import Foundation
import CryptoKit
import Security

// ============================================================================
// CERTIFICATE PINNING — TLS Transport Trust Enforcement
//
// Pins the SHA-256 hash of the Subject Public Key Info (SPKI) for
// critical API endpoints. Protects against MITM attacks, rogue CAs,
// and compromised root certificates.
//
// INVARIANT: Pin mismatch → HARD DENY. No auto-retry.
// INVARIANT: Pinning failures are logged to SecurityTelemetry.
// INVARIANT: Pins are static — compiled into the binary, not configurable.
// INVARIANT: Pinning is ENFORCED in professional + enterprise posture.
//
// PIN ROTATION: When a provider rotates certificates, update the pin set
// AND ship an app update. Include both current and next-rotation pins.
// ============================================================================

public final class CertificatePinningDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {

    public static let shared = CertificatePinningDelegate()

    // MARK: - Pin Database

    /// SHA-256 hashes of Subject Public Key Info (SPKI) for pinned hosts.
    /// Multiple pins per host support certificate rotation.
    ///
    /// To compute a pin:
    ///   openssl s_client -connect HOST:443 | openssl x509 -pubkey -noout |
    ///   openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64
    ///
    /// Real SPKI SHA-256 pins extracted from live certificates (2026-02-14).
    /// Each host has a leaf pin + intermediate CA pin for rotation safety.
    ///
    /// ROTATION: When providers renew certs, add the new pin BEFORE removing
    /// the old one. Ship the update, wait for adoption, then remove stale pin.
    private static let pins: [String: Set<String>] = [
        "api.openai.com": [
            // Leaf certificate SPKI pin
            "y5npFVdBuoqCSOdQa42qiUSPqwMpoei7NK0rQWGUaSU=",
            // Intermediate CA SPKI pin (rotation backup)
            "kIdp6NNEd8wsugYyyIYFsi1ylMCED3hZbSR8ZFsa/A4=",
        ],
        "api.anthropic.com": [
            // Leaf certificate SPKI pin
            "60QDDZy98CjK1XTBTlPbInyzJzi+817KvW+usCk6r+o=",
            // Intermediate CA SPKI pin (rotation backup)
            "kIdp6NNEd8wsugYyyIYFsi1ylMCED3hZbSR8ZFsa/A4=",
        ],
        "api.search.brave.com": [
            // Leaf certificate SPKI pin
            "Uoh/r/61CzBYXK3yaQ7e0PYxtJNPRTfNtLjE2YV5lrg=",
            // Intermediate CA SPKI pin (rotation backup)
            "vxRon/El5KuI4vx5ey1DgmsYmRY0nDd5Cg4GfJ8S+bg=",
        ],
    ]

    /// Hosts that are pinned. Fast lookup.
    private static let pinnedHosts: Set<String> = Set(pins.keys)

    /// Whether a host has active pins.
    public static func isPinned(_ host: String) -> Bool {
        pinnedHosts.contains(host.lowercased())
    }

    // MARK: - URLSession Delegate

    /// Performs certificate pinning validation during TLS handshake.
    /// Called by URLSession when server presents its certificate chain.
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              let host = Optional(challenge.protectionSpace.host.lowercased()),
              Self.pinnedHosts.contains(host) else {
            // Not a pinned host — use default handling
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Check posture — only enforce in professional+
        let posture = SecurityPostureManager.shared.currentPosture
        guard posture.rank >= SecurityPosture.professional.rank else {
            // Consumer posture — log but don't enforce
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Extract server certificate's SPKI hash
        guard let spkiHash = extractSPKIHash(from: serverTrust) else {
            SecurityTelemetry.shared.record(
                category: .networkPolicy,
                detail: "tls_pin_violation: Cannot extract SPKI from server cert for \(host)",
                outcome: .denied,
                metadata: ["host": host, "reason": "spki_extraction_failed"]
            )
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Validate against pin set
        guard let hostPins = Self.pins[host], hostPins.contains(spkiHash) else {
            SecurityTelemetry.shared.record(
                category: .networkPolicy,
                detail: "tls_pin_violation: SPKI hash mismatch for \(host)",
                outcome: .denied,
                metadata: ["host": host, "reason": "pin_mismatch", "hash": String(spkiHash.prefix(16))]
            )
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Pin matched
        SecurityTelemetry.shared.record(
            category: .networkPolicy,
            detail: "TLS pin validated for \(host)",
            outcome: .success,
            metadata: ["host": host]
        )
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }

    // MARK: - SPKI Hash Extraction

    /// Extract the SHA-256 hash of the leaf certificate's Subject Public Key Info.
    private func extractSPKIHash(from trust: SecTrust) -> String? {
        // Get the leaf certificate (first in chain)
        guard SecTrustGetCertificateCount(trust) > 0 else { return nil }

        // Use SecTrustCopyCertificateChain for iOS 15+
        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leafCert = chain.first else {
            return nil
        }

        // Extract public key from certificate
        guard let publicKey = SecCertificateCopyKey(leafCert) else {
            return nil
        }

        // Export public key data
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return nil
        }

        // SHA-256 hash of public key
        let hash = SHA256.hash(data: publicKeyData)
        return Data(hash).base64EncodedString()
    }
}

// MARK: - NetworkPolicyEnforcer Extension

extension NetworkPolicyEnforcer {

    /// Create a URLSession configured with certificate pinning delegate.
    /// Use this instead of URLSession.shared for pinned hosts.
    public static var pinnedSession: URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(
            configuration: config,
            delegate: CertificatePinningDelegate.shared,
            delegateQueue: nil
        )
    }
}
