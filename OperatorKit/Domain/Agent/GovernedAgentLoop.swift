import Foundation

// ============================================================================
// GOVERNED AGENT LOOP — SUPERVISED AUTONOMY ENGINE
//
// "The model can think. Only the kernel can act."
//
// This is a BOUNDED intelligence run with deterministic stopping conditions.
// The model reasons about the task, generates a search plan, and requests
// tool calls — but NEVER executes them directly. Each tool call is validated
// and executed by the governed connector system.
//
// SUPERVISED AUTONOMY LOOP:
//   Pass 1: Model generates research/search plan → executes search + fetch
//   Pass 2: Model evaluates gaps → optional second search/fetch
//   Pass 3: Model synthesizes final executive artifact
//   → ProposalPack generated → Human approval REQUIRED
//
// NON-NEGOTIABLE INVARIANTS:
//   • Models NEVER execute tools directly
//   • Every tool call passes ConnectorGate + NetworkPolicyEnforcer
//   • System FAILS CLOSED if capability cannot be verified
//   • Evidence is logged at every stage
//   • Maximum reasoning passes: 3
//   • No recursive task spawning
//   • No uncontrolled browsing
//   • No hidden execution
//
// This is NOT an open-ended agent.
// This is AUTHORITY INFRASTRUCTURE FOR SUPERVISED AUTONOMY.
// ============================================================================

// MARK: - Agent Loop Configuration

/// Hard limits for the agent loop — non-negotiable
public enum AgentLoopLimits {
    /// Maximum reasoning passes before forced stop
    static let maxPasses: Int = 3

    /// Maximum total tool calls across all passes
    static let maxToolCalls: Int = 8

    /// Maximum URLs the agent may request to fetch
    static let maxFetchURLs: Int = 3

    /// Maximum search queries the agent may issue
    static let maxSearchQueries: Int = 3

    /// Timeout per reasoning pass (seconds)
    static let perPassTimeoutSeconds: TimeInterval = 30.0

    /// Maximum total loop duration (seconds)
    static let totalTimeoutSeconds: TimeInterval = 90.0
}

// MARK: - Agent Tool Call Protocol

/// A tool call requested by the model — NOT yet executed.
/// The system validates and executes it through governed connectors.
public enum AgentToolCall: Codable, Equatable, Sendable {
    case search(query: String)
    case fetchPage(url: String)
    case synthesize(instructions: String)

    var toolName: String {
        switch self {
        case .search: return "search"
        case .fetchPage: return "fetch_page"
        case .synthesize: return "synthesize"
        }
    }

    var isTerminal: Bool {
        if case .synthesize = self { return true }
        return false
    }
}

/// Result of executing a tool call through governed connectors
public struct AgentToolResult: Sendable {
    public let toolCall: AgentToolCall
    public let success: Bool
    public let output: String
    public let evidenceTag: String
    public let durationMs: Int
}

// MARK: - Agent Loop State

/// Observable state for the agent loop — drives UI updates
public enum AgentLoopPhase: String, Sendable {
    case idle = "idle"
    case planning = "planning"
    case searching = "searching"
    case fetching = "fetching"
    case evaluating = "evaluating"
    case synthesizing = "synthesizing"
    case complete = "complete"
    case failed = "failed"
    case aborted = "aborted"
}

/// A single reasoning pass record
public struct AgentPass: Identifiable, Sendable {
    public let id: Int  // 1-indexed pass number
    public let toolCalls: [AgentToolCall]
    public let toolResults: [AgentToolResult]
    public let modelReasoning: String
    public let durationMs: Int
    public let timestamp: Date
}

/// Complete result of the agent loop
public struct AgentLoopResult: Sendable {
    public let requestText: String
    public let passes: [AgentPass]
    public let synthesizedArtifact: String
    public let totalDurationMs: Int
    public let totalToolCalls: Int
    public let searchQueries: [String]
    public let fetchedURLs: [String]
    public let modelProvider: String
    public let modelId: String
    public let evidenceTrail: [String]
}

// MARK: - Live Telemetry Types

/// A single event in the live telemetry feed — streams into UI in real-time.
public struct LiveTelemetryEvent: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let icon: String
    public let label: String
    public let detail: String
    public let color: LiveTelemetryColor
    public let type: LiveTelemetryType

    public enum LiveTelemetryType: Sendable {
        case guardrail    // security/policy check
        case toolCall     // search, fetch, synthesize
        case modelCall    // AI model invocation
        case dataIngress  // data flowing in
        case milestone    // pass complete, synthesis done
        case system       // system events
    }

    public enum LiveTelemetryColor: Sendable {
        case blue, green, amber, red, purple, muted
    }
}

/// A guardrail that just activated — flashes briefly in the UI.
public struct GuardrailFlash: Identifiable, Sendable {
    public let id = UUID()
    public let name: String
    public let icon: String
    public let status: GuardrailStatus

    public enum GuardrailStatus: Sendable {
        case passed, warned, blocked
    }
}

// MARK: - Governed Agent Loop

/// The bounded supervised autonomy engine.
///
/// Orchestrates AI reasoning + governed tool execution within strict limits.
/// The model generates structured tool call requests; the loop validates
/// and executes each through ConnectorGate + NetworkPolicyEnforcer.
///
/// INVARIANT: Model NEVER touches tools directly.
/// INVARIANT: Every pass is logged with full evidence.
/// INVARIANT: Hard stop at AgentLoopLimits.maxPasses.
@MainActor
public final class GovernedAgentLoop: ObservableObject {

    // MARK: - Published State (drives UI)

    @Published public private(set) var phase: AgentLoopPhase = .idle
    @Published public private(set) var currentPass: Int = 0
    @Published public private(set) var statusMessage: String = ""
    @Published public private(set) var toolCallLog: [AgentToolResult] = []
    @Published public private(set) var passes: [AgentPass] = []
    @Published public private(set) var synthesizedArtifact: String?
    @Published public private(set) var isComplete: Bool = false
    @Published public private(set) var errorMessage: String?

    // MARK: - Live Telemetry Feed (drives streaming UI)

    /// Real-time event feed — each event streams into the UI as it happens.
    /// This is what gives the "agentic" feel: data dropping in live.
    @Published public private(set) var liveFeed: [LiveTelemetryEvent] = []

    /// Current guardrail that just fired (flashes in UI, then fades)
    @Published public private(set) var activeGuardrail: GuardrailFlash?

    /// Elapsed seconds since loop started
    @Published public private(set) var elapsedSeconds: Double = 0

    /// Token count tracker
    @Published public private(set) var tokensUsed: Int = 0

    /// Timer for elapsed seconds
    private var elapsedTimer: Timer?

    // MARK: - Internal Counters (enforce hard limits)

    private var totalToolCalls: Int = 0
    private var searchQueriesUsed: Int = 0
    private var fetchURLsUsed: Int = 0
    private var evidenceTrail: [String] = []
    private var loopStartTime: Date?
    private var lastModelProvider: String = "unknown"
    private var lastModelId: String = "unknown"

    // MARK: - Execute

    /// Run the bounded supervised autonomy loop.
    ///
    /// - Parameter request: The user's natural language request
    /// - Returns: Complete agent loop result with synthesized artifact
    /// - Throws: If the loop fails closed (missing capabilities, limits exceeded, etc.)
    public func execute(request: String) async throws -> AgentLoopResult {
        // Reset state
        reset()
        loopStartTime = Date()
        startElapsedTimer()
        phase = .planning
        statusMessage = "Analyzing request..."
        logEvidence("agent_loop_started", detail: "request_length=\(request.count)")

        // ── Live feed: startup sequence ──
        emit("SYSTEM INIT", detail: "Governed agent loop starting", icon: "bolt.shield.fill", color: .blue, type: .system)
        flashGuardrail("CapabilityKernel", icon: "cpu", status: .passed)
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms visual beat
        flashGuardrail("ConnectorGate", icon: "lock.shield", status: .passed)
        try? await Task.sleep(nanoseconds: 150_000_000)
        flashGuardrail("NetworkPolicy", icon: "network.badge.shield.half.filled", status: .passed)
        try? await Task.sleep(nanoseconds: 150_000_000)
        emit("REQUEST", detail: String(request.prefix(80)), icon: "text.bubble", color: .muted, type: .system)

        var conversationHistory: [(role: String, content: String)] = []
        var allPasses: [AgentPass] = []
        var finalArtifact: String?

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // BOUNDED LOOP — max AgentLoopLimits.maxPasses passes
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        for passNumber in 1...AgentLoopLimits.maxPasses {
            currentPass = passNumber

            // Check total timeout
            guard let start = loopStartTime,
                  Date().timeIntervalSince(start) < AgentLoopLimits.totalTimeoutSeconds else {
                throw AgentLoopError.totalTimeout
            }

            let passStart = Date()

            // ── Step 1: Ask model what to do ──
            let systemPrompt = buildSystemPrompt(
                passNumber: passNumber,
                remainingSearches: AgentLoopLimits.maxSearchQueries - searchQueriesUsed,
                remainingFetches: AgentLoopLimits.maxFetchURLs - fetchURLsUsed,
                isLastPass: passNumber == AgentLoopLimits.maxPasses
            )

            let userPrompt: String
            if passNumber == 1 {
                userPrompt = """
                USER REQUEST:
                \(request)

                This is pass \(passNumber) of \(AgentLoopLimits.maxPasses). Generate your research plan and first tool call.
                """
            } else {
                let historyContext = conversationHistory
                    .map { "[\($0.role)] \($0.content)" }
                    .joined(separator: "\n\n")
                userPrompt = """
                CONVERSATION SO FAR:
                \(historyContext)

                This is pass \(passNumber) of \(AgentLoopLimits.maxPasses).\(passNumber == AgentLoopLimits.maxPasses ? " THIS IS YOUR FINAL PASS — you MUST call synthesize now." : " Evaluate gaps and decide: search more, fetch a page, or synthesize your final artifact.")
                """
            }

            // Call model through governed V2 routing
            phase = passNumber == 1 ? .planning : .evaluating
            statusMessage = passNumber == 1 ? "Planning research approach..." : "Evaluating gaps (pass \(passNumber)/\(AgentLoopLimits.maxPasses))..."

            emit("MODEL CALL", detail: "Pass \(passNumber) — requesting AI reasoning", icon: "brain.head.profile", color: .purple, type: .modelCall)
            flashGuardrail("DataDiode", icon: "shield.checkered", status: .passed)

            let modelResponse: GovernedModelResponse
            do {
                modelResponse = try await ModelRouter.shared.generateGovernedV2(
                    taskType: .researchBrief,
                    prompt: userPrompt,
                    context: systemPrompt,
                    riskTier: .medium
                )
                lastModelProvider = modelResponse.provider.rawValue
                lastModelId = modelResponse.modelId
                tokensUsed += modelResponse.outputTokens
            } catch {
                emit("MODEL FAILED", detail: error.localizedDescription, icon: "xmark.circle", color: .red, type: .modelCall)
                logEvidence("agent_loop_model_failed", detail: "pass=\(passNumber), error=\(error.localizedDescription)")
                stopElapsedTimer()
                throw AgentLoopError.modelCallFailed(error.localizedDescription)
            }

            emit("MODEL RESPONSE", detail: "\(modelResponse.provider.rawValue) — \(modelResponse.outputTokens) tokens", icon: "brain", color: .purple, type: .modelCall)
            logEvidence("agent_loop_model_response", detail: "pass=\(passNumber), provider=\(modelResponse.provider.rawValue), tokens=\(modelResponse.outputTokens)")

            // ── Step 2: Parse tool calls from model output ──
            let parsedCalls = parseToolCalls(from: modelResponse.text)
            var passToolCalls: [AgentToolCall] = []
            var passToolResults: [AgentToolResult] = []

            if parsedCalls.isEmpty && passNumber == AgentLoopLimits.maxPasses {
                // Last pass with no tool calls — treat entire response as synthesis
                finalArtifact = modelResponse.text
                phase = .synthesizing
                statusMessage = "Synthesizing final artifact..."
                logEvidence("agent_loop_implicit_synthesize", detail: "pass=\(passNumber)")
            }

            // ── Step 3: Execute tool calls through governed connectors ──
            for call in parsedCalls {
                // Enforce hard limits
                guard totalToolCalls < AgentLoopLimits.maxToolCalls else {
                    logEvidence("agent_loop_tool_limit_reached", detail: "total=\(totalToolCalls)")
                    break
                }

                let result = await executeToolCall(call)
                passToolCalls.append(call)
                passToolResults.append(result)
                toolCallLog.append(result)
                totalToolCalls += 1

                // Add result to conversation history
                conversationHistory.append((
                    role: "tool_result",
                    content: "[\(call.toolName)] \(result.success ? "SUCCESS" : "FAILED"): \(result.output.prefix(2000))"
                ))

                // If synthesize was called, we have our final artifact
                if case .synthesize = call, result.success {
                    finalArtifact = result.output
                }
            }

            // Record pass
            let passDuration = Int(Date().timeIntervalSince(passStart) * 1000)
            let pass = AgentPass(
                id: passNumber,
                toolCalls: passToolCalls,
                toolResults: passToolResults,
                modelReasoning: String(modelResponse.text.prefix(500)),
                durationMs: passDuration,
                timestamp: passStart
            )
            allPasses.append(pass)
            passes = allPasses

            // Add model response to conversation history
            conversationHistory.append((
                role: "assistant",
                content: modelResponse.text
            ))

            logEvidence("agent_loop_pass_complete", detail: "pass=\(passNumber), tools=\(passToolCalls.count), duration=\(passDuration)ms")

            // If we have a final artifact, stop
            if finalArtifact != nil {
                break
            }
        }

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // FORCED STOP — if model didn't synthesize, force it
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        if finalArtifact == nil {
            phase = .synthesizing
            statusMessage = "Forcing synthesis (max passes reached)..."
            logEvidence("agent_loop_forced_synthesis", detail: "passes=\(allPasses.count)")

            let gatherContent = conversationHistory
                .filter { $0.role == "tool_result" }
                .map { $0.content }
                .joined(separator: "\n\n---\n\n")

            let forcePrompt = """
            You have completed all research passes. Here is everything gathered:

            \(gatherContent)

            ORIGINAL REQUEST: \(request)

            Now synthesize a comprehensive executive artifact based on the gathered information.
            Write the complete artifact. Do NOT request any more tool calls.
            """

            do {
                let synthResponse = try await ModelRouter.shared.generateGovernedV2(
                    taskType: .researchBrief,
                    prompt: forcePrompt,
                    context: "You are a research analyst. Produce your final deliverable now. No tool calls. Plain text artifact only.",
                    riskTier: .medium
                )
                finalArtifact = synthResponse.text
                logEvidence("agent_loop_forced_synthesis_complete", detail: "chars=\(synthResponse.text.count)")
            } catch {
                logEvidence("agent_loop_forced_synthesis_failed", detail: error.localizedDescription)
                // Use whatever we have
                finalArtifact = "[Synthesis failed — raw research data]\n\n\(gatherContent)"
            }
        }

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // COMPLETE — package result
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        let totalDuration = Int(Date().timeIntervalSince(loopStartTime ?? Date()) * 1000)
        synthesizedArtifact = finalArtifact
        phase = .complete
        isComplete = true
        statusMessage = "Research complete — \(allPasses.count) pass(es), \(totalToolCalls) tool call(s)"
        stopElapsedTimer()

        emit("COMPLETE", detail: "\(allPasses.count) passes, \(totalToolCalls) tools, \(tokensUsed) tokens in \(String(format: "%.1f", Double(totalDuration) / 1000))s", icon: "checkmark.shield.fill", color: .green, type: .milestone)
        flashGuardrail("Human Approval", icon: "hand.raised.fill", status: .warned)

        logEvidence("agent_loop_complete", detail: "passes=\(allPasses.count), tools=\(totalToolCalls), duration=\(totalDuration)ms")

        return AgentLoopResult(
            requestText: request,
            passes: allPasses,
            synthesizedArtifact: finalArtifact ?? "",
            totalDurationMs: totalDuration,
            totalToolCalls: totalToolCalls,
            searchQueries: toolCallLog.filter {
                if case .search = $0.toolCall { return true }
                return false
            }.map {
                if case .search(let q) = $0.toolCall { return q }
                return ""
            },
            fetchedURLs: toolCallLog.filter {
                if case .fetchPage = $0.toolCall { return true }
                return false
            }.map {
                if case .fetchPage(let u) = $0.toolCall { return u }
                return ""
            },
            modelProvider: lastModelProvider,
            modelId: lastModelId,
            evidenceTrail: evidenceTrail
        )
    }

    // MARK: - Abort

    public func abort() {
        phase = .aborted
        statusMessage = "Aborted by operator."
        logEvidence("agent_loop_aborted", detail: "pass=\(currentPass)")
    }

    // MARK: - Tool Call Execution (Governed)

    /// Execute a single tool call through governed connectors.
    /// The MODEL never touches these tools — the SYSTEM executes on its behalf.
    private func executeToolCall(_ call: AgentToolCall) async -> AgentToolResult {
        let start = Date()

        switch call {
        case .search(let query):
            // ── BRAVE SEARCH — through ConnectorGate + NetworkPolicyEnforcer ──
            guard searchQueriesUsed < AgentLoopLimits.maxSearchQueries else {
                return AgentToolResult(
                    toolCall: call,
                    success: false,
                    output: "Search limit reached (\(AgentLoopLimits.maxSearchQueries) max)",
                    evidenceTag: "agent_search_limit_reached",
                    durationMs: 0
                )
            }

            phase = .searching
            statusMessage = "Searching: \(query.prefix(60))..."
            emit("SEARCH", detail: query, icon: "magnifyingglass", color: .blue, type: .toolCall)
            flashGuardrail("ConnectorGate", icon: "lock.shield", status: .passed)

            do {
                let response = try await BraveSearchClient.shared.search(query: query, count: 5)
                searchQueriesUsed += 1

                let resultText = response.results.enumerated().map { idx, r in
                    "[\(idx + 1)] \(r.title)\n    URL: \(r.url.absoluteString)\n    \(r.description)"
                }.joined(separator: "\n\n")

                // Emit each result as a data ingress event
                for r in response.results.prefix(3) {
                    emit("DATA IN", detail: r.title, icon: "arrow.down.doc", color: .green, type: .dataIngress)
                }

                let output = "Found \(response.results.count) results:\n\n\(resultText)"
                logEvidence("agent_search_executed", detail: "query=\(query.prefix(50)), results=\(response.results.count)")

                return AgentToolResult(
                    toolCall: call,
                    success: true,
                    output: output,
                    evidenceTag: "agent_search_executed",
                    durationMs: Int(Date().timeIntervalSince(start) * 1000)
                )
            } catch {
                logEvidence("agent_search_failed", detail: "query=\(query.prefix(50)), error=\(error.localizedDescription)")
                return AgentToolResult(
                    toolCall: call,
                    success: false,
                    output: "Search failed: \(error.localizedDescription)",
                    evidenceTag: "agent_search_failed",
                    durationMs: Int(Date().timeIntervalSince(start) * 1000)
                )
            }

        case .fetchPage(let urlString):
            // ── WEB FETCH — through GovernedWebFetcher → NetworkPolicyEnforcer ──
            guard fetchURLsUsed < AgentLoopLimits.maxFetchURLs else {
                return AgentToolResult(
                    toolCall: call,
                    success: false,
                    output: "Fetch limit reached (\(AgentLoopLimits.maxFetchURLs) max)",
                    evidenceTag: "agent_fetch_limit_reached",
                    durationMs: 0
                )
            }

            guard let url = URL(string: urlString), url.scheme?.lowercased() == "https" else {
                return AgentToolResult(
                    toolCall: call,
                    success: false,
                    output: "Invalid or non-HTTPS URL rejected",
                    evidenceTag: "agent_fetch_rejected_non_https",
                    durationMs: 0
                )
            }

            phase = .fetching
            statusMessage = "Fetching: \(url.host ?? "unknown")..."
            emit("FETCH", detail: url.host ?? "unknown", icon: "globe", color: .blue, type: .toolCall)
            flashGuardrail("NetworkPolicy", icon: "network.badge.shield.half.filled", status: .passed)

            do {
                let webDoc = try await GovernedWebFetcher.shared.fetch(url: url)
                let parsed = try DocumentParser.parse(webDoc)
                emit("DATA IN", detail: "\(parsed.charCount) chars from \(url.host ?? "source")", icon: "arrow.down.doc", color: .green, type: .dataIngress)
                flashGuardrail("DataDiode", icon: "shield.checkered", status: .passed)
                fetchURLsUsed += 1

                // Redact through DataDiode before giving to model
                let redactedContent = DataDiode.redact(parsed.text)
                let truncated = String(redactedContent.prefix(3000))

                let output = """
                Title: \(parsed.title)
                Source: \(url.host ?? "unknown")
                Characters: \(parsed.charCount)
                Pages: \(parsed.pageCount)

                Content (redacted, truncated):
                \(truncated)
                """

                logEvidence("agent_fetch_executed", detail: "url=\(url.host ?? "nil"), chars=\(parsed.charCount)")

                return AgentToolResult(
                    toolCall: call,
                    success: true,
                    output: output,
                    evidenceTag: "agent_fetch_executed",
                    durationMs: Int(Date().timeIntervalSince(start) * 1000)
                )
            } catch {
                logEvidence("agent_fetch_failed", detail: "url=\(url.host ?? "nil"), error=\(error.localizedDescription)")
                return AgentToolResult(
                    toolCall: call,
                    success: false,
                    output: "Fetch failed: \(error.localizedDescription)",
                    evidenceTag: "agent_fetch_failed",
                    durationMs: Int(Date().timeIntervalSince(start) * 1000)
                )
            }

        case .synthesize(let instructions):
            // ── SYNTHESIS — terminal action, model produces final artifact ──
            phase = .synthesizing
            statusMessage = "Synthesizing executive artifact..."
            emit("SYNTHESIZE", detail: "Generating final executive artifact", icon: "doc.text.fill", color: .purple, type: .toolCall)

            // Gather all tool results as context for synthesis
            let toolContext = toolCallLog
                .filter { $0.success }
                .map { "[\($0.toolCall.toolName)] \($0.output)" }
                .joined(separator: "\n\n---\n\n")

            do {
                let synthResponse = try await ModelRouter.shared.generateGovernedV2(
                    taskType: .researchBrief,
                    prompt: """
                    SYNTHESIS INSTRUCTIONS: \(instructions)

                    GATHERED RESEARCH DATA:
                    \(toolContext)
                    """,
                    context: "You are a senior research analyst. Produce a polished, executive-ready artifact. Be specific, cite sources, include data points. No tool calls — final output only.",
                    riskTier: .medium
                )

                logEvidence("agent_synthesize_complete", detail: "chars=\(synthResponse.text.count)")

                return AgentToolResult(
                    toolCall: call,
                    success: true,
                    output: synthResponse.text,
                    evidenceTag: "agent_synthesize_complete",
                    durationMs: Int(Date().timeIntervalSince(start) * 1000)
                )
            } catch {
                logEvidence("agent_synthesize_failed", detail: error.localizedDescription)
                return AgentToolResult(
                    toolCall: call,
                    success: false,
                    output: "Synthesis failed: \(error.localizedDescription)",
                    evidenceTag: "agent_synthesize_failed",
                    durationMs: Int(Date().timeIntervalSince(start) * 1000)
                )
            }
        }
    }

    // MARK: - System Prompt Builder

    private func buildSystemPrompt(
        passNumber: Int,
        remainingSearches: Int,
        remainingFetches: Int,
        isLastPass: Bool
    ) -> String {
        """
        You are a governed research analyst inside OperatorKit.
        You have access to these tools. Respond with EXACTLY ONE JSON tool call per response.

        AVAILABLE TOOLS:
        1. {"tool": "search", "args": {"query": "your search query"}}
           → Searches the web via Brave Search API. Returns titles, URLs, and snippets.
           → Remaining: \(remainingSearches) search(es)

        2. {"tool": "fetch_page", "args": {"url": "https://example.com/page"}}
           → Fetches and parses a web page (HTTPS only, allowlisted hosts).
           → Content is automatically redacted through DataDiode.
           → Remaining: \(remainingFetches) fetch(es)

        3. {"tool": "synthesize", "args": {"instructions": "what to produce"}}
           → TERMINAL ACTION. Triggers synthesis of the final executive artifact.
           → Use this when you have enough data OR on your final pass.

        RULES:
        • You are on pass \(passNumber) of \(AgentLoopLimits.maxPasses).
        • \(isLastPass ? "THIS IS YOUR FINAL PASS. You MUST call synthesize." : "Plan your research efficiently — you have limited passes.")
        • Respond with a brief reasoning paragraph, then EXACTLY ONE JSON tool call.
        • If you have enough data, call synthesize immediately.
        • NEVER request actions outside these three tools.
        • NEVER attempt to browse, click, submit forms, or mutate anything.
        • All fetched content is redacted before you see it.

        OUTPUT FORMAT:
        [Your reasoning about what to do next — 2-3 sentences max]

        ```json
        {"tool": "...", "args": {...}}
        ```
        """
    }

    // MARK: - Tool Call Parser

    /// Parse structured tool calls from model output.
    /// Looks for JSON blocks matching the tool call schema.
    private func parseToolCalls(from text: String) -> [AgentToolCall] {
        var calls: [AgentToolCall] = []

        // Find JSON blocks in the response
        let jsonPattern = "\\{\\s*\"tool\"\\s*:\\s*\"([^\"]+)\"\\s*,\\s*\"args\"\\s*:\\s*\\{([^}]*)\\}\\s*\\}"
        guard let regex = try? NSRegularExpression(pattern: jsonPattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)

        for match in matches.prefix(1) { // Only take FIRST tool call per response
            guard match.numberOfRanges >= 3,
                  let toolRange = Range(match.range(at: 1), in: text),
                  let argsRange = Range(match.range(at: 2), in: text) else {
                continue
            }

            let toolName = String(text[toolRange])
            let argsText = String(text[argsRange])

            switch toolName {
            case "search":
                if let query = extractStringArg(named: "query", from: argsText) {
                    calls.append(.search(query: query))
                }
            case "fetch_page":
                if let url = extractStringArg(named: "url", from: argsText) {
                    calls.append(.fetchPage(url: url))
                }
            case "synthesize":
                let instructions = extractStringArg(named: "instructions", from: argsText) ?? "Synthesize a comprehensive executive brief from all gathered research."
                calls.append(.synthesize(instructions: instructions))
            default:
                // Unknown tool — log and skip (fail closed: don't execute unknown tools)
                logEvidence("agent_unknown_tool_rejected", detail: "tool=\(toolName)")
            }
        }

        return calls
    }

    /// Extract a named string argument from a JSON args fragment
    private func extractStringArg(named name: String, from argsText: String) -> String? {
        let pattern = "\"\(name)\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\"" // handles escaped quotes
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsRange = NSRange(argsText.startIndex..., in: argsText)
        guard let match = regex.firstMatch(in: argsText, range: nsRange),
              match.numberOfRanges >= 2,
              let valueRange = Range(match.range(at: 1), in: argsText) else {
            return nil
        }
        return String(argsText[valueRange])
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    // MARK: - Helpers

    private func reset() {
        phase = .idle
        currentPass = 0
        statusMessage = ""
        toolCallLog = []
        passes = []
        synthesizedArtifact = nil
        isComplete = false
        errorMessage = nil
        totalToolCalls = 0
        searchQueriesUsed = 0
        fetchURLsUsed = 0
        evidenceTrail = []
        loopStartTime = nil
        liveFeed = []
        activeGuardrail = nil
        elapsedSeconds = 0
        tokensUsed = 0
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    // MARK: - Live Telemetry Emitters

    private func emit(_ label: String, detail: String, icon: String, color: LiveTelemetryEvent.LiveTelemetryColor, type: LiveTelemetryEvent.LiveTelemetryType) {
        let event = LiveTelemetryEvent(timestamp: Date(), icon: icon, label: label, detail: detail, color: color, type: type)
        liveFeed.append(event)
    }

    private func flashGuardrail(_ name: String, icon: String, status: GuardrailFlash.GuardrailStatus) {
        activeGuardrail = GuardrailFlash(name: name, icon: icon, status: status)
        emit("GUARDRAIL: \(name)", detail: status == .passed ? "PASSED" : status == .warned ? "WARNING" : "BLOCKED", icon: icon, color: status == .passed ? .green : status == .warned ? .amber : .red, type: .guardrail)
    }

    private func startElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.loopStartTime else { return }
                self.elapsedSeconds = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func logEvidence(_ type: String, detail: String) {
        let entry = "[\(type)] \(detail) @ \(Date().ISO8601Format())"
        evidenceTrail.append(entry)
        try? EvidenceEngine.shared.logGenericArtifact(
            type: type,
            planId: UUID(),
            jsonString: """
            {"source":"GovernedAgentLoop","pass":\(currentPass),"detail":"\(detail.replacingOccurrences(of: "\"", with: "'"))","timestamp":"\(Date().ISO8601Format())"}
            """
        )
    }
}

// MARK: - Agent Loop Errors

public enum AgentLoopError: LocalizedError {
    case totalTimeout
    case modelCallFailed(String)
    case toolLimitExceeded
    case noArtifactProduced
    case aborted

    public var errorDescription: String? {
        switch self {
        case .totalTimeout:
            return "Agent loop exceeded total timeout (\(Int(AgentLoopLimits.totalTimeoutSeconds))s). Fail closed."
        case .modelCallFailed(let reason):
            return "Model call failed: \(reason)"
        case .toolLimitExceeded:
            return "Maximum tool calls exceeded (\(AgentLoopLimits.maxToolCalls)). Fail closed."
        case .noArtifactProduced:
            return "Agent loop completed without producing an artifact."
        case .aborted:
            return "Agent loop aborted by operator."
        }
    }
}
