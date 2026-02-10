import Foundation

// ============================================================================
// ANTHROPIC CLIENT — Thin, Governed Cloud Client
//
// INVARIANT: ONLY referenced by ModelRouter.swift. No other file imports this.
// INVARIANT: Requires ModelCallToken (verified + consumed before call).
// INVARIANT: All requests go through CloudDomainAllowlist.
// INVARIANT: All payloads pass through DataDiode before sending.
// INVARIANT: API key is runtime-injected, NEVER in source code.
// ============================================================================

/// Internal: only ModelRouter may use this client.
final class AnthropicClient: @unchecked Sendable {

    static let shared = AnthropicClient()

    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!

    /// Runtime-injected API key. Nil = not configured.
    private var apiKey: String? {
        ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
            ?? UserDefaults.standard.string(forKey: "ok_anthropic_api_key")
    }

    private init() {}

    // MARK: - Generate

    /// Send a governed completion request to Anthropic.
    /// Caller MUST have already verified + consumed a ModelCallToken.
    func generate(
        systemPrompt: String,
        userPrompt: String,
        model: String = "claude-sonnet-4-20250514"
    ) async throws -> CloudCompletionResponse {
        // 1. API key check
        guard let key = apiKey, !key.isEmpty else {
            throw CloudModelError.apiKeyMissing(.cloudAnthropic)
        }

        // 2. Domain allowlist check
        try CloudDomainAllowlist.assertAllowed(baseURL)

        // 3. Redact prompts through DataDiode
        let redactedSystem = DataDiode.redact(systemPrompt)
        let redactedUser = DataDiode.redact(userPrompt)

        // 4. Build request
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": redactedSystem,
            "messages": [
                ["role": "user", "content": redactedUser]
            ]
        ]

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        // 5. Execute via NetworkPolicyEnforcer
        let (data, response) = try await NetworkPolicyEnforcer.shared.execute(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudModelError.requestFailed("No HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown"
            throw CloudModelError.requestFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        // 6. Parse
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String else {
            throw CloudModelError.responseParseFailed("Invalid Anthropic response structure")
        }

        let usage = json["usage"] as? [String: Any]
        return CloudCompletionResponse(
            content: text,
            provider: .cloudAnthropic,
            model: model,
            promptTokens: usage?["input_tokens"] as? Int,
            completionTokens: usage?["output_tokens"] as? Int
        )
    }
}
