import Foundation
import CryptoKit

// ============================================================================
// DATA DIODE — Outbound Referential Tokenization Layer
//
// INVARIANT: ALL data leaving the device passes through this diode.
// INVARIANT: Secrets, PII patterns, and sensitive markers are TOKENIZED
//            (not masked) with referential placeholders BEFORE any cloud
//            request is constructed.
// INVARIANT: Evidence logs store the TOKENIZED version only.
// INVARIANT: Lookup table stays ON-DEVICE ONLY. Never transmitted.
// INVARIANT: After model response, tokens are rehydrated locally.
//
// WHY TOKENIZATION > MASKING:
//   Masking (****1234) allows statistical reconstruction by models.
//   Tokenization ([EMAIL_A]) kills reconstruction — models cannot
//   correlate tokens across requests.
// ============================================================================

enum DataDiode {

    // ── Tokenization Session ─────────────────────────────
    //
    // Each tokenization pass creates a session with a fresh lookup table.
    // The session is returned alongside the tokenized text so the caller
    // can rehydrate after receiving the model response.

    /// A tokenization session holds the on-device lookup table.
    /// INVARIANT: Never serialize this to cloud or evidence.
    final class TokenizationSession {
        /// Forward map: original value → token placeholder
        private(set) var forwardMap: [String: String] = [:]
        /// Reverse map: token placeholder → original value
        private(set) var reverseMap: [String: String] = [:]
        /// Counters per category for generating sequential tokens
        private var counters: [String: Int] = [:]

        /// Generate the next token for a category (e.g., "EMAIL" → "[EMAIL_A]", "[EMAIL_B]", ...)
        func tokenize(value: String, category: String) -> String {
            if let existing = forwardMap[value] {
                return existing
            }
            let index = counters[category, default: 0]
            counters[category] = index + 1
            let suffix = Self.indexToLabel(index)
            let token = "[\(category)_\(suffix)]"
            forwardMap[value] = token
            reverseMap[token] = value
            return token
        }

        /// Rehydrate tokenized text by replacing tokens with original values.
        /// Call ONLY on-device after receiving model response.
        func rehydrate(_ text: String) -> String {
            var result = text
            for (token, original) in reverseMap {
                result = result.replacingOccurrences(of: token, with: original)
            }
            return result
        }

        /// How many unique values were tokenized.
        var tokenCount: Int { forwardMap.count }

        /// Convert integer index to alphabetic label: 0→A, 1→B, ... 25→Z, 26→AA, etc.
        private static func indexToLabel(_ index: Int) -> String {
            var n = index
            var label = ""
            repeat {
                label = String(UnicodeScalar(65 + (n % 26))!) + label
                n = n / 26 - 1
            } while n >= 0
            return label
        }
    }

    // ── Sensitive Pattern Definitions ────────────────────
    private static let sensitivePatterns: [(pattern: String, category: String)] = [
        // ORDER MATTERS: More specific patterns FIRST to avoid greedy consumption.
        //
        // Email addresses
        (#"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, "EMAIL"),
        // SSN-like patterns (BEFORE phone — SSN is more specific)
        (#"\d{3}-\d{2}-\d{4}"#, "SSN"),
        // Case numbers (common federal formats — BEFORE phone)
        (#"\b\d{1,2}:\d{2}-(?:cr|cv|mj|mc)-\d{4,6}(?:-[A-Z]{2,4})?\b"#, "CASE_NUMBER"),
        // Date of birth patterns (MM/DD/YYYY, MM-DD-YYYY — BEFORE phone)
        (#"\b(?:0[1-9]|1[0-2])[/\-](?:0[1-9]|[12]\d|3[01])[/\-](?:19|20)\d{2}\b"#, "DOB"),
        // Credit card numbers (13-19 digits, possibly spaced)
        (#"\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{1,7}\b"#, "CC"),
        // Phone numbers (various formats — AFTER SSN/CC to avoid over-matching)
        (#"\+?\d{1,3}[-.\s]?\(?\d{1,4}\)?[-.\s]?\d{1,4}[-.\s]?\d{1,9}"#, "PHONE"),
        // US street addresses (number + street name pattern)
        (#"\b\d{1,5}\s+(?:[A-Z][a-z]+\s?){1,4}(?:St|Ave|Blvd|Dr|Rd|Ct|Ln|Way|Pl|Cir|Pkwy|Hwy)\.?\b"#, "ADDRESS"),
        // US zip codes (5 or 9 digit)
        (#"\b\d{5}(?:-\d{4})?\b"#, "ZIPCODE"),
        // API keys / tokens (long alphanumeric strings)
        (#"(?:sk|pk|api|key|token|secret|bearer)[_-]?[A-Za-z0-9]{20,}"#, "KEY"),
        // Bank routing numbers (exactly 9 digits)
        (#"\b\d{9}\b"#, "ROUTING_NUM"),
    ]

    // ── Public API ───────────────────────────────────────

    /// Tokenize sensitive data in text before it leaves the device.
    /// Returns (tokenized text, session for rehydration).
    ///
    /// INVARIANT: The session's lookup table must NEVER leave the device.
    static func tokenize(_ text: String) -> (tokenized: String, session: TokenizationSession) {
        let session = TokenizationSession()
        var result = text
        for (pattern, category) in sensitivePatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            // Find all matches (iterate in reverse to preserve indices)
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, options: [], range: nsRange)
            for match in matches.reversed() {
                guard let range = Range(match.range, in: result) else { continue }
                let original = String(result[range])
                let token = session.tokenize(value: original, category: category)
                result.replaceSubrange(range, with: token)
            }
        }

        // Evidence log (non-blocking) — records that diode was applied
        if session.tokenCount > 0 {
            let count = session.tokenCount
            let charCount = text.count
            Task { @MainActor in
                try? EvidenceEngine.shared.logGenericArtifact(
                    type: "data_diode_applied",
                    planId: UUID(),
                    jsonString: """
                    {"tokenizations":\(count),"inputChars":\(charCount),"timestamp":"\(Date().ISO8601Format())"}
                    """
                )
            }
        }

        return (result, session)
    }

    /// Legacy redact API — returns tokenized text without session (for evidence logging).
    /// Compatible with existing callers that only need the redacted string.
    static func redact(_ text: String) -> String {
        tokenize(text).tokenized
    }

    /// Tokenize and return both the tokenized text and a summary for evidence.
    static func tokenizeForEvidence(_ text: String) -> (tokenized: String, summary: String) {
        let (tokenized, session) = tokenize(text)
        let charCount = text.count
        let summary = "chars=\(charCount), tokenizations=\(session.tokenCount)"
        return (tokenized, summary)
    }

    /// Legacy evidence API — backward compatible.
    static func redactForEvidence(_ text: String) -> (redacted: String, summary: String) {
        let (tokenized, summary) = tokenizeForEvidence(text)
        return (tokenized, summary)
    }

    /// Tokenize a list of context strings suitable for cloud model prompts.
    static func tokenizeContextSummary(_ items: [String]) -> (tokenized: String, session: TokenizationSession) {
        let combined = items.joined(separator: "\n")
        return tokenize(combined)
    }

    /// Legacy context summary API — backward compatible.
    static func redactContextSummary(_ items: [String]) -> String {
        items.map { redact($0) }.joined(separator: "\n")
    }
}
