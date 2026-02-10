import Foundation

// ============================================================================
// OPENAI CLIENT — Thin, Governed Cloud Client
//
// INVARIANT: ONLY referenced by ModelRouter.swift. No other file imports this.
// INVARIANT: Requires ModelCallToken (verified + consumed before call).
// INVARIANT: All requests go through CloudDomainAllowlist.
// INVARIANT: All payloads pass through DataDiode before sending.
// INVARIANT: API key is runtime-injected, NEVER in source code.
// ============================================================================

/// Internal: only ModelRouter may use this client.
final class OpenAIClient: @unchecked Sendable {

    static let shared = OpenAIClient()

    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    /// Runtime-injected API key. Nil = not configured.
    /// Set via environment or user configuration at runtime.
    private var apiKey: String? {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
            ?? UserDefaults.standard.string(forKey: "ok_openai_api_key")
    }

    private init() {}

    // MARK: - Generate

    /// Send a governed completion request to OpenAI.
    /// Caller MUST have already verified + consumed a ModelCallToken.
    func generate(
        systemPrompt: String,
        userPrompt: String,
        model: String = "gpt-4o-mini"
    ) async throws -> CloudCompletionResponse {
        // 1. API key check
        guard let key = apiKey, !key.isEmpty else {
            throw CloudModelError.apiKeyMissing(.cloudOpenAI)
        }

        // 2. Domain allowlist check
        try CloudDomainAllowlist.assertAllowed(baseURL)

        // 3. Redact prompts through DataDiode
        let redactedSystem = DataDiode.redact(systemPrompt)
        let redactedUser = DataDiode.redact(userPrompt)

        // 4. Build request
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": redactedSystem],
                ["role": "user", "content": redactedUser]
            ],
            "max_tokens": 2048,
            "temperature": 0.3
        ]

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
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
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw CloudModelError.responseParseFailed("Invalid OpenAI response structure")
        }

        let usage = json["usage"] as? [String: Any]
        return CloudCompletionResponse(
            content: content,
            provider: .cloudOpenAI,
            model: model,
            promptTokens: usage?["prompt_tokens"] as? Int,
            completionTokens: usage?["completion_tokens"] as? Int
        )
    }
}

// MARK: - Shared Response Type

/// Normalized cloud completion response used by both OpenAI and Anthropic clients.
struct CloudCompletionResponse {
    let content: String
    let provider: ModelProvider
    let model: String
    let promptTokens: Int?
    let completionTokens: Int?
}
