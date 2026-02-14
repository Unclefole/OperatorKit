import Foundation

// ============================================================================
// WEB RESEARCH SKILL — GOVERNED DOCUMENT ANALYSIS MICRO-OPERATOR
//
// Purpose: Fetch public web documents, parse them, analyze with governed
//          model routing, and package findings into a ProposalPack.
//
// INVARIANT: Produces ProposalPacks ONLY. Zero execution.
// INVARIANT: MUST NOT reference ExecutionEngine, ServiceAccessToken,
//            CalendarService, ReminderService, MailComposerService.
// INVARIANT: MUST NOT mint tokens or call CapabilityKernel.issueToken.
// INVARIANT: ALL web fetches go through GovernedWebFetcher → NetworkPolicyEnforcer.
// INVARIANT: ALL content is redacted via DataDiode BEFORE cloud model usage.
// INVARIANT: READ + ANALYZE only. No form submissions, no auth, no mutations.
//
// EVIDENCE TAGS:
//   web_research_started, web_research_fetch_complete,
//   web_research_analysis_complete, web_research_proposal_generated,
//   web_research_failed
// ============================================================================

public final class WebResearchSkill: OperatorSkill {

    public let skillId = "web_research"
    public let displayName = "Web Research"
    public let riskTier: RiskTier = .medium
    public let allowedScopes: [PermissionDomain] = [.network, .files]
    public let requiredSigners: Int = 1
    public let producesProposalPack: Bool = true
    public let executionOptional: Bool = false

    public init() {}

    // MARK: - Observe

    /// Parse the input to extract URL(s) and research query.
    public func observe(input: SkillInput) async -> SkillObservation {
        var signals: [Signal] = []
        var excerpts: [String] = []
        let text = input.textContent

        // Extract URLs from input
        let urls = extractURLs(from: text)
        if !urls.isEmpty {
            for url in urls {
                signals.append(Signal(
                    label: "Target URL: \(url.host ?? "unknown")",
                    confidence: 0.95,
                    category: .informational,
                    excerpt: url.absoluteString
                ))
                excerpts.append(url.absoluteString)
            }
        }

        // Detect research intent keywords
        let lower = text.lowercased()
        let researchKeywords: [(String, SignalCategory, Double)] = [
            ("legal", .legal, 0.85),
            ("case", .legal, 0.75),
            ("court", .legal, 0.85),
            ("federal", .legal, 0.80),
            ("charges", .legal, 0.85),
            ("filing", .legal, 0.75),
            ("docket", .legal, 0.80),
            ("indictment", .legal, 0.90),
            ("complaint", .legal, 0.80),
            ("contract", .contract, 0.80),
            ("regulation", .legal, 0.75),
            ("compliance", .legal, 0.80),
            ("financial", .financial, 0.80),
            ("report", .informational, 0.60),
            ("document", .informational, 0.55),
            ("research", .informational, 0.50),
            ("find", .informational, 0.45),
        ]

        for (keyword, category, confidence) in researchKeywords {
            if lower.contains(keyword) {
                signals.append(Signal(
                    label: "Research keyword: \(keyword)",
                    confidence: confidence,
                    category: category,
                    excerpt: extractContext(from: text, keyword: keyword)
                ))
            }
        }

        // Detect subject mentions (person/entity names heuristic)
        let namePatterns = extractPotentialNames(from: text)
        for name in namePatterns {
            signals.append(Signal(
                label: "Subject reference: \(name)",
                confidence: 0.70,
                category: .informational,
                excerpt: name
            ))
        }

        // If no URL found, attempt Brave Search to discover URLs
        if urls.isEmpty {
            do {
                let searchClient = BraveSearchClient.shared
                let searchResponse = try await searchClient.search(query: text, count: 5)

                if !searchResponse.results.isEmpty {
                    signals.append(Signal(
                        label: "Brave Search: \(searchResponse.results.count) results found",
                        confidence: 0.90,
                        category: .informational,
                        excerpt: "Query: \(text.prefix(100))"
                    ))

                    for result in searchResponse.results {
                        signals.append(Signal(
                            label: "Search result: \(result.title.prefix(80))",
                            confidence: 0.85,
                            category: .informational,
                            excerpt: result.url.absoluteString
                        ))
                        excerpts.append(result.url.absoluteString)

                        // Store description as context for synthesis
                        excerpts.append("SNIPPET: \(result.description)")
                    }

                    logEvidence(type: "web_research_search_complete",
                               detail: "query=\(text.prefix(50)), results=\(searchResponse.results.count)")
                } else {
                    signals.append(Signal(
                        label: "Brave Search returned no results",
                        confidence: 0.40,
                        category: .informational,
                        excerpt: nil
                    ))
                }
            } catch {
                // Search failed — log but continue with keyword analysis
                signals.append(Signal(
                    label: "Web search unavailable: \(error.localizedDescription.prefix(80))",
                    confidence: 0.30,
                    category: .informational,
                    excerpt: nil
                ))
                logEvidence(type: "web_research_search_failed", detail: error.localizedDescription)
            }
        }

        logEvidence(type: "web_research_started", detail: "urls=\(urls.count), signals=\(signals.count)")

        return SkillObservation(
            skillId: skillId,
            signals: signals,
            rawExcerpts: excerpts
        )
    }

    // MARK: - Analyze

    /// Fetch documents and parse them. Classify risk based on content.
    public func analyze(observation: SkillObservation) async -> SkillAnalysis {
        var items: [AnalysisItem] = []
        var overallRisk: RiskTier = .low

        // Extract URLs from observation
        let urls = observation.signals
            .compactMap { $0.excerpt }
            .compactMap { URL(string: $0) }
            .filter { $0.scheme?.lowercased() == "https" }

        let fetcher = GovernedWebFetcher.shared

        for url in urls.prefix(3) { // Max 3 URLs per research session
            do {
                // Fetch
                let webDoc = try await fetcher.fetch(url: url)

                // Parse
                let parsed = try DocumentParser.parse(webDoc)

                logEvidence(type: "web_research_fetch_complete",
                           detail: "url=\(url.host ?? "nil"), chars=\(parsed.charCount), pages=\(parsed.pageCount)")

                // Classify risk based on content
                let contentRisk = classifyContentRisk(parsed.text)
                if contentRisk > overallRisk { overallRisk = contentRisk }

                // Create analysis item for the document
                items.append(AnalysisItem(
                    title: "Document: \(parsed.title)",
                    detail: "Source: \(url.host ?? "unknown") — \(parsed.charCount) characters, \(parsed.pageCount) pages",
                    riskTier: contentRisk,
                    actionRequired: true,
                    suggestedAction: "Analyze document content for requested information",
                    evidenceExcerpt: parsed.preview(maxChars: 300)
                ))

                // Detect legal content
                let legalSignals = detectLegalContent(parsed.text)
                for signal in legalSignals {
                    items.append(AnalysisItem(
                        title: signal.label,
                        detail: signal.excerpt ?? "Detected in document",
                        riskTier: .medium,
                        actionRequired: false,
                        suggestedAction: nil,
                        evidenceExcerpt: signal.excerpt
                    ))
                }

            } catch {
                items.append(AnalysisItem(
                    title: "Fetch failed: \(url.host ?? "unknown")",
                    detail: error.localizedDescription,
                    riskTier: .medium,
                    actionRequired: false,
                    suggestedAction: "Verify URL is accessible and on allowlist"
                ))
                logEvidence(type: "web_research_failed", detail: "url=\(url.host ?? "nil"), error=\(error.localizedDescription)")
            }
        }

        // If no fetchable URLs but we have search snippets, use them as context
        if urls.isEmpty {
            let snippets = observation.rawExcerpts.filter { $0.hasPrefix("SNIPPET: ") }
            if !snippets.isEmpty {
                let snippetText = snippets
                    .map { String($0.dropFirst("SNIPPET: ".count)) }
                    .joined(separator: "\n\n")
                items.append(AnalysisItem(
                    title: "Search results context",
                    detail: "Synthesized from \(snippets.count) search result snippets via Brave Search",
                    riskTier: .low,
                    actionRequired: true,
                    suggestedAction: "Use search context for research brief synthesis",
                    evidenceExcerpt: String(snippetText.prefix(500))
                ))
            } else {
                items.append(AnalysisItem(
                    title: "No source content available",
                    detail: "No URLs provided and web search returned no results. Research brief will use available context only.",
                    riskTier: .low,
                    actionRequired: false,
                    suggestedAction: nil
                ))
            }
        }

        let summary: String
        if items.isEmpty {
            summary = "No documents fetched or analyzed."
        } else {
            let docCount = urls.count
            let snippetCount = observation.rawExcerpts.filter { $0.hasPrefix("SNIPPET: ") }.count
            let signalCount = items.count
            if docCount > 0 {
                summary = "Analyzed \(docCount) document(s). Found \(signalCount) items. Risk: \(overallRisk.rawValue)."
            } else if snippetCount > 0 {
                summary = "Web search returned \(snippetCount) result(s). Found \(signalCount) items. Risk: \(overallRisk.rawValue). Ready for AI synthesis."
            } else {
                summary = "Found \(signalCount) items from query analysis. Risk: \(overallRisk.rawValue)."
            }
        }

        logEvidence(type: "web_research_analysis_complete", detail: "items=\(items.count), risk=\(overallRisk.rawValue)")

        return SkillAnalysis(
            skillId: skillId,
            riskTier: overallRisk,
            items: items,
            summary: summary
        )
    }

    // MARK: - Generate Proposal

    /// Package analysis findings into a ProposalPack. NO EXECUTION.
    public func generateProposal(analysis: SkillAnalysis) async -> ProposalPack {
        // Build execution steps (read-only — no mutations)
        let steps = analysis.items.enumerated().map { idx, item in
            ExecutionStepDefinition(
                order: idx + 1,
                action: item.suggestedAction ?? "Review document findings",
                description: "\(item.title): \(String(item.detail.prefix(100)))",
                isMutation: false,
                rollbackAction: nil
            )
        }

        let toolPlan = ToolPlan(
            intent: ToolPlanIntent(
                type: .reviewDocument,
                summary: analysis.summary,
                targetDescription: "Web document research"
            ),
            originatingAction: "web_research_skill",
            riskScore: analysis.riskTier.scoreEstimate,
            riskTier: analysis.riskTier,
            riskReasons: analysis.items.map { $0.title },
            reversibility: .reversible,
            reversibilityReason: "Read-only research — no side effects",
            requiredApprovals: ApprovalRequirement(
                approvalsNeeded: requiredSigners,
                requiresBiometric: analysis.riskTier >= .high,
                requiresPreview: true
            ),
            probes: [],
            executionSteps: steps
        )

        // Permission manifest — read-only network
        let permissions = PermissionManifest(scopes: [
            PermissionScope(domain: .network, access: .read, detail: "web_fetch_public_document")
        ])

        // Risk analysis
        let risk = RiskConsequenceAnalysis(
            riskScore: analysis.riskTier.scoreEstimate,
            consequenceTier: analysis.riskTier,
            reversibilityClass: .reversible, // Read-only = no side effects
            blastRadius: .selfOnly,
            reasons: analysis.items.map { $0.title }
        )

        // Cost estimate (on-device analysis = free; cloud escalation possible)
        let cost = CostEstimate.onDevice

        // Evidence citations
        let citations = analysis.items.prefix(10).map { item in
            EvidenceCitation(
                sourceType: .document,
                reference: item.title,
                redactedSummary: DataDiode.redact(item.detail)
            )
        }

        let proposal = ProposalPack(
            source: .user,
            toolPlan: toolPlan,
            permissionManifest: permissions,
            riskAnalysis: risk,
            costEstimate: cost,
            evidenceCitations: citations,
            humanSummary: "Web Research: \(analysis.summary)"
        )

        logEvidence(type: "web_research_proposal_generated",
                   detail: "proposalId=\(proposal.id), items=\(analysis.items.count), risk=\(analysis.riskTier.rawValue)")

        return proposal
    }

    // MARK: - Content Risk Classification

    private func classifyContentRisk(_ text: String) -> RiskTier {
        let lower = text.lowercased()

        // HIGH risk: legal proceedings, criminal, financial
        let highKeywords = [
            "indictment", "criminal complaint", "grand jury", "sentencing",
            "plea agreement", "conviction", "felony", "misdemeanor",
            "securities fraud", "money laundering", "bank fraud", "wire fraud",
            "racketeering", "conspiracy", "forfeiture"
        ]
        for kw in highKeywords {
            if lower.contains(kw) { return .high }
        }

        // MEDIUM risk: legal/regulatory content
        let mediumKeywords = [
            "court order", "docket", "case number", "defendant", "plaintiff",
            "regulation", "enforcement action", "civil penalty", "violation",
            "compliance order", "cease and desist", "subpoena"
        ]
        for kw in mediumKeywords {
            if lower.contains(kw) { return .medium }
        }

        return .low
    }

    // MARK: - Legal Content Detection

    private func detectLegalContent(_ text: String) -> [Signal] {
        var signals: [Signal] = []
        let lower = text.lowercased()

        let legalPatterns: [(String, String, Double)] = [
            ("case no\\.", "Case number reference", 0.90),
            ("docket no\\.", "Docket number reference", 0.90),
            ("defendant", "Defendant mentioned", 0.80),
            ("plaintiff", "Plaintiff mentioned", 0.80),
            ("united states v\\.", "Federal prosecution", 0.95),
            ("sealed", "Sealed document reference", 0.85),
            ("sentencing", "Sentencing information", 0.90),
            ("judgment", "Court judgment", 0.85),
        ]

        for (pattern, label, confidence) in legalPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsRange = NSRange(lower.startIndex..., in: lower)
                if regex.firstMatch(in: lower, range: nsRange) != nil {
                    signals.append(Signal(
                        label: label,
                        confidence: confidence,
                        category: .legal,
                        excerpt: nil
                    ))
                }
            }
        }

        return signals
    }

    // MARK: - Helpers

    private func extractURLs(from text: String) -> [URL] {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        guard let det = detector else { return [] }
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = det.matches(in: text, range: nsRange)
        return matches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return URL(string: String(text[range]))
        }.filter { $0.scheme?.lowercased() == "https" }
    }

    private func extractContext(from text: String, keyword: String) -> String {
        guard let range = text.lowercased().range(of: keyword) else { return "" }
        let start = text.index(range.lowerBound, offsetBy: -50, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: 50, limitedBy: text.endIndex) ?? text.endIndex
        return String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractPotentialNames(from text: String) -> [String] {
        // Simple heuristic: capitalized word pairs that aren't common words
        let commonWords: Set<String> = ["The", "This", "That", "From", "With", "About", "Department", "Justice", "Court", "State", "United", "States"]
        var names: [String] = []
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        for i in 0..<(words.count - 1) {
            let w1 = words[i]
            let w2 = words[i + 1]
            if w1.first?.isUppercase == true && w2.first?.isUppercase == true
                && w1.count > 1 && w2.count > 1
                && !commonWords.contains(w1) && !commonWords.contains(w2)
                && !w1.hasSuffix(".") {
                let name = "\(w1) \(w2)"
                if !names.contains(name) {
                    names.append(name)
                }
            }
        }
        return Array(names.prefix(5)) // Max 5 detected names
    }

    // MARK: - Evidence

    private func logEvidence(type: String, detail: String) {
        Task { @MainActor in
            try? EvidenceEngine.shared.logGenericArtifact(
                type: type,
                planId: UUID(),
                jsonString: """
                {"skillId":"web_research","detail":"\(detail)","timestamp":"\(Date().ISO8601Format())"}
                """
            )
        }
    }
}
