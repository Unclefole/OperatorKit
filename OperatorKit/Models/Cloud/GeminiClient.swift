import Foundation

// ============================================================================
// GEMINI CLIENT — Google AI Cloud Client
//
// INVARIANT: ONLY referenced by ModelRouter.swift. No other file imports this.
// INVARIANT: Requires ModelCallToken (verified + consumed before call).
// INVARIANT: All requests go through CloudDomainAllowlist.
// INVARIANT: All payloads pass through DataDiode before sending.
// INVARIANT: API key resolved from APIKeyVault at call time.
// INVARIANT: Never reads from UserDefaults.
// INVARIANT: Never caches the key in memory.
// ============================================================================

/// Internal: only ModelRouter may use this client.
final class GeminiClient: @unchecked Sendable {

    static let shared = GeminiClient()

    private let baseURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models")!

    /// Resolve API key at call time from APIKeyVault (hardware-backed).
    /// Falls back to environment variable for CI/testing ONLY.
    private func resolveKey() throws -> String {
        // Primary: APIKeyVault (hardware-backed, biometric-gated)
        if let vaultKey = try? APIKeyVault.shared.retrieveKeyString(for: .cloudGemini) {
            return vaultKey
        }
        // Fallback: environment variable (CI / Xcode scheme only)
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        throw CloudModelError.apiKeyMissing(.cloudGemini)
    }

    private init() {}

    // MARK: - Generate

    /// Send a governed completion request to Google Gemini.
    /// Caller MUST have already verified + consumed a ModelCallToken.
    func generate(
        systemPrompt: String,
        userPrompt: String,
        model: String = "gemini-2.0-flash"
    ) async throws -> CloudCompletionResponse {
        // 1. API key check — resolved at call time from vault
        let key = try resolveKey()

        // 2. Build the URL with model and key
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)")!

        // 3. Domain allowlist check
        try CloudDomainAllowlist.assertAllowed(url)

        // 4. Redact prompts through DataDiode
        let redactedSystem = DataDiode.redact(systemPrompt)
        let redactedUser = DataDiode.redact(userPrompt)

        // 5. Build request body (Gemini format)
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "\(redactedSystem)\n\n\(redactedUser)"]
                    ]
                ]
            ],
            "generationConfig": [
                "maxOutputTokens": 2048,
                "temperature": 0.3
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        // 6. Execute via NetworkPolicyEnforcer
        let (data, response) = try await NetworkPolicyEnforcer.shared.execute(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudModelError.requestFailed("No HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown"
            throw CloudModelError.requestFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        // 7. Parse Gemini response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw CloudModelError.responseParseFailed("Invalid Gemini response structure")
        }

        let usageMetadata = json["usageMetadata"] as? [String: Any]
        return CloudCompletionResponse(
            content: text,
            provider: .cloudGemini,
            model: model,
            promptTokens: usageMetadata?["promptTokenCount"] as? Int,
            completionTokens: usageMetadata?["candidatesTokenCount"] as? Int
        )
    }
}
