import Foundation
import os.log

// ============================================================================
// MODEL CONNECTION TESTER — MINIMAL PING (NO STREAMING, NO PROMPT RETENTION)
//
// Tests cloud model connectivity by sending the smallest valid request
// through the full governed pipeline:
//
//   APIKeyVault → NetworkPolicyEnforcer → Cloud API → Response check
//
// INVARIANT: Key retrieved from APIKeyVault (biometric required).
// INVARIANT: All requests go through NetworkPolicyEnforcer.execute().
// INVARIANT: Timeout: 5 seconds. No retry.
// INVARIANT: No prompt or response content is retained or logged.
// INVARIANT: No Authorization headers appear in logs.
// INVARIANT: Evidence logged: started / succeeded / failed.
// ============================================================================

// MARK: - Connection Test Result

public struct ConnectionTestResult: Sendable {
    public let provider: ModelProvider
    public let success: Bool
    public let latencyMs: Int
    public let errorMessage: String?
    public let timestamp: Date

    public var statusText: String {
        if success {
            return "Connected (\(latencyMs)ms)"
        } else {
            return errorMessage ?? "Connection failed"
        }
    }
}

// MARK: - Connection Test Error

public enum ConnectionTestError: Error, LocalizedError, Sendable {
    case noKeyConfigured
    case networkPolicyBlocked(String)
    case httpError(Int, String)
    case timeout
    case cloudModelsDisabled
    case parseError
    case vaultError(String)

    public var errorDescription: String? {
        switch self {
        case .noKeyConfigured:
            return "No API key configured for this provider"
        case .networkPolicyBlocked(let reason):
            return "Network policy blocked: \(reason)"
        case .httpError(let code, let msg):
            return "HTTP \(code): \(msg)"
        case .timeout:
            return "Connection timed out (5s)"
        case .cloudModelsDisabled:
            return "Cloud models are disabled"
        case .parseError:
            return "Invalid response from API"
        case .vaultError(let msg):
            return "Vault error: \(msg)"
        }
    }
}

// MARK: - Model Connection Tester

public enum ModelConnectionTester {

    private static let logger = Logger(subsystem: "com.operatorkit", category: "ModelConnectionTester")

    /// Test connectivity to a cloud model provider.
    ///
    /// Flow:
    /// 1. Verify cloud models enabled
    /// 2. Retrieve key from APIKeyVault (biometric required)
    /// 3. Build minimal test request
    /// 4. Send through NetworkPolicyEnforcer
    /// 5. Verify valid response
    /// 6. Log evidence
    ///
    /// Timeout: 5 seconds. No streaming. No prompt retention.
    @MainActor
    public static func testConnection(for provider: ModelProvider) async -> ConnectionTestResult {
        let startTime = Date()
        let planId = UUID()

        // Evidence: started
        logEvidence(type: "model_connection_test_started", provider: provider, planId: planId)

        // 1. Check cloud models enabled
        guard IntelligenceFeatureFlags.cloudModelsEnabled else {
            let result = ConnectionTestResult(
                provider: provider, success: false, latencyMs: 0,
                errorMessage: ConnectionTestError.cloudModelsDisabled.localizedDescription,
                timestamp: Date()
            )
            logEvidence(type: "model_connection_test_failed", provider: provider, planId: planId,
                       extra: "reason: cloud_models_disabled")
            return result
        }

        // 2. Check kill switch
        guard !EnterpriseFeatureFlags.cloudKillSwitch else {
            let result = ConnectionTestResult(
                provider: provider, success: false, latencyMs: 0,
                errorMessage: "Cloud kill switch is active",
                timestamp: Date()
            )
            logEvidence(type: "model_connection_test_failed", provider: provider, planId: planId,
                       extra: "reason: cloud_kill_switch")
            return result
        }

        // 3. Retrieve key from APIKeyVault (triggers biometric)
        let keyString: String
        do {
            keyString = try APIKeyVault.shared.retrieveKeyString(for: provider)
        } catch {
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)
            let result = ConnectionTestResult(
                provider: provider, success: false, latencyMs: latency,
                errorMessage: "Key retrieval failed: \(error.localizedDescription)",
                timestamp: Date()
            )
            logEvidence(type: "model_connection_test_failed", provider: provider, planId: planId,
                       extra: "reason: vault_error")
            return result
        }

        // 4. Build minimal test request
        let request: URLRequest
        do {
            request = try buildTestRequest(for: provider, key: keyString)
        } catch {
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)
            let result = ConnectionTestResult(
                provider: provider, success: false, latencyMs: latency,
                errorMessage: error.localizedDescription,
                timestamp: Date()
            )
            logEvidence(type: "model_connection_test_failed", provider: provider, planId: planId,
                       extra: "reason: request_build_failed")
            return result
        }

        // 5. Execute through NetworkPolicyEnforcer with 5s timeout
        do {
            let (data, response) = try await NetworkPolicyEnforcer.shared.execute(request)
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)

            guard let httpResponse = response as? HTTPURLResponse else {
                let result = ConnectionTestResult(
                    provider: provider, success: false, latencyMs: latency,
                    errorMessage: "No HTTP response",
                    timestamp: Date()
                )
                logEvidence(type: "model_connection_test_failed", provider: provider, planId: planId,
                           extra: "reason: no_http_response")
                return result
            }

            // 6. Verify response
            if (200...299).contains(httpResponse.statusCode) {
                // Verify response has expected structure (don't log content)
                let valid = validateResponse(data: data, provider: provider)
                if valid {
                    let result = ConnectionTestResult(
                        provider: provider, success: true, latencyMs: latency,
                        errorMessage: nil, timestamp: Date()
                    )
                    logEvidence(type: "model_connection_test_succeeded", provider: provider, planId: planId,
                               extra: "latencyMs: \(latency)")
                    return result
                } else {
                    let result = ConnectionTestResult(
                        provider: provider, success: false, latencyMs: latency,
                        errorMessage: "Invalid response structure",
                        timestamp: Date()
                    )
                    logEvidence(type: "model_connection_test_failed", provider: provider, planId: planId,
                               extra: "reason: invalid_response_structure")
                    return result
                }
            } else {
                // Parse error message (sanitized — no key exposure)
                let errorBody = parseErrorBody(data: data, provider: provider)
                let result = ConnectionTestResult(
                    provider: provider, success: false, latencyMs: latency,
                    errorMessage: "HTTP \(httpResponse.statusCode): \(errorBody)",
                    timestamp: Date()
                )
                logEvidence(type: "model_connection_test_failed", provider: provider, planId: planId,
                           extra: "reason: http_\(httpResponse.statusCode)")
                return result
            }

        } catch {
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)
            let isTimeout = latency >= 4500 // Near 5s timeout
            let result = ConnectionTestResult(
                provider: provider, success: false, latencyMs: latency,
                errorMessage: isTimeout ? "Connection timed out (5s)" : error.localizedDescription,
                timestamp: Date()
            )
            logEvidence(type: "model_connection_test_failed", provider: provider, planId: planId,
                       extra: "reason: \(isTimeout ? "timeout" : "network_error")")
            return result
        }
    }

    // MARK: - Request Building

    /// Build a minimal test request. Uses the smallest valid payload.
    /// No real prompt content. Response will be tiny.
    private static func buildTestRequest(for provider: ModelProvider, key: String) throws -> URLRequest {
        switch provider {
        case .cloudOpenAI:
            return try buildOpenAITestRequest(key: key)
        case .cloudAnthropic:
            return try buildAnthropicTestRequest(key: key)
        case .cloudGemini:
            return try buildGeminiTestRequest(key: key)
        case .cloudGroq:
            return try buildGroqTestRequest(key: key)
        case .cloudLlama:
            return try buildLlamaTestRequest(key: key)
        case .onDevice:
            fatalError("On-device does not need connection testing")
        }
    }

    private static func buildOpenAITestRequest(key: String) throws -> URLRequest {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        try CloudDomainAllowlist.assertAllowed(url)

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [["role": "user", "content": "ping"]],
            "max_tokens": 1
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 5
        return request
    }

    private static func buildAnthropicTestRequest(key: String) throws -> URLRequest {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        try CloudDomainAllowlist.assertAllowed(url)

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "ping"]]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 5
        return request
    }

    private static func buildGeminiTestRequest(key: String) throws -> URLRequest {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(key)")!
        try CloudDomainAllowlist.assertAllowed(url)

        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": "ping"]]]
            ],
            "generationConfig": [
                "maxOutputTokens": 1
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 5
        return request
    }

    private static func buildGroqTestRequest(key: String) throws -> URLRequest {
        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        try CloudDomainAllowlist.assertAllowed(url)

        let body: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [["role": "user", "content": "ping"]],
            "max_tokens": 1
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 5
        return request
    }

    private static func buildLlamaTestRequest(key: String) throws -> URLRequest {
        let url = URL(string: "https://api.together.xyz/v1/chat/completions")!
        try CloudDomainAllowlist.assertAllowed(url)

        let body: [String: Any] = [
            "model": "meta-llama/Llama-3.3-70B-Instruct-Turbo",
            "messages": [["role": "user", "content": "ping"]],
            "max_tokens": 1
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 5
        return request
    }

    // MARK: - Response Validation

    /// Validate response structure without logging content.
    private static func validateResponse(data: Data, provider: ModelProvider) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        switch provider {
        case .cloudOpenAI:
            return json["choices"] != nil || json["id"] != nil
        case .cloudAnthropic:
            return json["content"] != nil || json["id"] != nil
        case .cloudGemini:
            return json["candidates"] != nil
        case .cloudGroq:
            return json["choices"] != nil || json["id"] != nil  // OpenAI-compatible
        case .cloudLlama:
            return json["choices"] != nil || json["id"] != nil  // OpenAI-compatible
        case .onDevice:
            return true
        }
    }

    /// Parse error body safely — never expose keys.
    private static func parseErrorBody(data: Data, provider: ModelProvider) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "Unknown error"
        }

        // OpenAI error format
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            // Sanitize: redact anything that looks like a key
            return sanitizeErrorMessage(message)
        }

        // Anthropic error format
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return sanitizeErrorMessage(message)
        }

        if let message = json["message"] as? String {
            return sanitizeErrorMessage(message)
        }

        return "API error"
    }

    /// Sanitize error messages to remove any accidental key exposure.
    private static func sanitizeErrorMessage(_ message: String) -> String {
        var sanitized = message
        // Redact anything that looks like an API key (OpenAI, Anthropic, Gemini, Groq)
        let patterns = [
            "sk-[a-zA-Z0-9-]+",        // OpenAI
            "sk-ant-[a-zA-Z0-9-]+",     // Anthropic
            "Bearer [^ ]+",             // Bearer tokens
            "AIza[a-zA-Z0-9_-]+",       // Google API keys
            "gsk_[a-zA-Z0-9]+",         // Groq API keys
            "key=[a-zA-Z0-9_-]+"        // URL query key parameter
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                sanitized = regex.stringByReplacingMatches(
                    in: sanitized,
                    range: NSRange(sanitized.startIndex..., in: sanitized),
                    withTemplate: "[REDACTED]"
                )
            }
        }
        // Truncate long error messages
        if sanitized.count > 200 {
            sanitized = String(sanitized.prefix(200)) + "…"
        }
        return sanitized
    }

    // MARK: - Evidence

    @MainActor
    private static func logEvidence(type: String, provider: ModelProvider, planId: UUID, extra: String = "") {
        let extraClause = extra.isEmpty ? "" : ",\(extra)"
        try? EvidenceEngine.shared.logGenericArtifact(
            type: type,
            planId: planId,
            jsonString: """
            {"provider":"\(provider.rawValue)","timestamp":"\(Date().ISO8601Format())"\(extraClause)}
            """
        )
    }
}
