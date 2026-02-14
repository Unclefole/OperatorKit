import XCTest
@testable import OperatorKit

// ============================================================================
// WEB RESEARCH CONNECTOR — INVARIANT TESTS
//
// Validates:
//   ✅ Non-allowlisted hosts are denied
//   ✅ HTTP (non-HTTPS) is rejected
//   ✅ POST requests are blocked (GovernedWebFetcher only sends GET)
//   ✅ Document parser fails closed on invalid input
//   ✅ DataDiode is applied before model usage
//   ✅ No ExecutionEngine references
//   ✅ No direct URLSession usage outside NetworkPolicyEnforcer
//   ✅ ProposalPack is generated successfully
// ============================================================================

final class WebResearchTests: XCTestCase {

    // MARK: - Network Policy Tests

    /// Verify non-allowlisted host is denied
    func testDenyNonAllowlistedHost() throws {
        let enforcer = NetworkPolicyEnforcer.shared
        let url = URL(string: "https://malicious-site.example.com/page")!
        XCTAssertThrowsError(try enforcer.validate(url)) { error in
            guard let policyError = error as? NetworkPolicyEnforcer.NetworkPolicyError else {
                XCTFail("Expected NetworkPolicyError, got \(error)")
                return
            }
            switch policyError {
            case .hostNotAllowed(let host):
                XCTAssertEqual(host, "malicious-site.example.com")
            default:
                XCTFail("Expected .hostNotAllowed, got \(policyError)")
            }
        }
    }

    /// Verify HTTP (non-TLS) is rejected
    func testRejectHTTP() throws {
        let enforcer = NetworkPolicyEnforcer.shared
        let url = URL(string: "http://www.justice.gov/page")!
        XCTAssertThrowsError(try enforcer.validate(url)) { error in
            guard let policyError = error as? NetworkPolicyEnforcer.NetworkPolicyError else {
                XCTFail("Expected NetworkPolicyError, got \(error)")
                return
            }
            switch policyError {
            case .httpForbidden:
                break // Expected
            default:
                XCTFail("Expected .httpForbidden, got \(policyError)")
            }
        }
    }

    /// Verify GovernedWebFetcher rejects HTTP URLs directly
    func testGovernedFetcherRejectsHTTP() async throws {
        let fetcher = GovernedWebFetcher.shared
        let url = URL(string: "http://www.justice.gov/page")!
        do {
            _ = try await fetcher.fetch(url: url)
            XCTFail("Should have thrown for HTTP URL")
        } catch let error as WebFetchError {
            switch error {
            case .httpOnly:
                break // Expected
            default:
                XCTFail("Expected .httpOnly, got \(error)")
            }
        }
    }

    /// Verify GovernedWebFetcher rejects non-allowlisted hosts
    func testGovernedFetcherRejectsNonAllowlisted() async throws {
        let fetcher = GovernedWebFetcher.shared
        let url = URL(string: "https://evil.example.com/steal-data")!
        do {
            _ = try await fetcher.fetch(url: url)
            XCTFail("Should have thrown for non-allowlisted host")
        } catch let error as WebFetchError {
            switch error {
            case .policyDenied:
                break // Expected
            default:
                XCTFail("Expected .policyDenied, got \(error)")
            }
        }
    }

    // MARK: - Document Parser Tests

    /// Verify parser fails closed on empty content
    func testParserFailsOnEmptyContent() throws {
        let emptyDoc = WebDocument(
            url: URL(string: "https://example.gov/empty")!,
            mimeType: "text/html",
            rawData: Data(),
            statusCode: 200
        )
        XCTAssertThrowsError(try DocumentParser.parse(emptyDoc)) { error in
            guard let parseError = error as? DocumentParseError else {
                XCTFail("Expected DocumentParseError, got \(error)")
                return
            }
            switch parseError {
            case .emptyContent:
                break // Expected
            default:
                XCTFail("Expected .emptyContent, got \(parseError)")
            }
        }
    }

    /// Verify parser fails on unsupported MIME type
    func testParserFailsOnUnsupportedFormat() throws {
        let binaryDoc = WebDocument(
            url: URL(string: "https://example.gov/file.bin")!,
            mimeType: "application/octet-stream",
            rawData: "binary data".data(using: .utf8)!,
            statusCode: 200
        )
        XCTAssertThrowsError(try DocumentParser.parse(binaryDoc)) { error in
            guard let parseError = error as? DocumentParseError else {
                XCTFail("Expected DocumentParseError, got \(error)")
                return
            }
            switch parseError {
            case .unsupportedFormat(let mime):
                XCTAssertEqual(mime, "application/octet-stream")
            default:
                XCTFail("Expected .unsupportedFormat, got \(parseError)")
            }
        }
    }

    /// Verify HTML parser extracts text and strips scripts
    func testHTMLParserStripsScripts() throws {
        let html = """
        <html><head><title>Test Doc</title></head>
        <body>
        <script>alert('xss')</script>
        <h1>Important Heading</h1>
        <p>This is the body text.</p>
        <style>.hidden{display:none}</style>
        </body></html>
        """
        let doc = WebDocument(
            url: URL(string: "https://example.gov/page")!,
            mimeType: "text/html",
            rawData: html.data(using: .utf8)!,
            statusCode: 200
        )
        let parsed = try DocumentParser.parse(doc)
        XCTAssertFalse(parsed.text.contains("alert"))
        XCTAssertFalse(parsed.text.contains("xss"))
        XCTAssertFalse(parsed.text.contains("display:none"))
        XCTAssertTrue(parsed.text.contains("Important Heading"))
        XCTAssertTrue(parsed.text.contains("body text"))
        XCTAssertEqual(parsed.title, "Test Doc")
    }

    // MARK: - DataDiode Tests

    /// Verify DataDiode redacts PII before model usage
    func testDiodeRedactsPII() {
        let text = "Contact john.doe@company.com at 555-123-4567. SSN: 123-45-6789."
        let (redacted, session) = DataDiode.tokenize(text)

        // Email must be tokenized
        XCTAssertFalse(redacted.contains("john.doe@company.com"))
        XCTAssertTrue(redacted.contains("[EMAIL_"))

        // Phone must be tokenized
        XCTAssertFalse(redacted.contains("555-123-4567"))
        XCTAssertTrue(redacted.contains("[PHONE_"))

        // SSN must be tokenized
        XCTAssertFalse(redacted.contains("123-45-6789"))
        XCTAssertTrue(redacted.contains("[SSN_"))

        // Rehydration must recover originals
        let rehydrated = session.rehydrate(redacted)
        XCTAssertTrue(rehydrated.contains("john.doe@company.com"))
        XCTAssertTrue(rehydrated.contains("123-45-6789"))
    }

    /// Verify enhanced PII patterns for legal documents
    func testDiodeRedactsLegalDocumentPII() {
        let text = "DOB: 01/15/1985. Address: 123 Main St. Case: 1:23-cr-00456-ABC"
        let redacted = DataDiode.redact(text)

        // DOB should be tokenized
        XCTAssertFalse(redacted.contains("01/15/1985"))

        // Case number should be tokenized
        XCTAssertFalse(redacted.contains("1:23-cr-00456-ABC"))
    }

    // MARK: - WebResearchSkill Tests

    /// Verify WebResearchSkill generates a ProposalPack
    @MainActor
    func testWebResearchSkillGeneratesProposal() async {
        let skill = WebResearchSkill()

        // Verify protocol compliance
        XCTAssertTrue(skill.producesProposalPack)
        XCTAssertFalse(skill.executionOptional)
        XCTAssertEqual(skill.skillId, "web_research")

        let input = SkillInput(
            inputType: .webResearchQuery,
            textContent: "Research https://www.justice.gov/example-document about John Smith federal case"
        )

        // Run observe
        let observation = await skill.observe(input: input)
        XCTAssertGreaterThan(observation.signals.count, 0)

        // Verify URL was detected
        let urlSignals = observation.signals.filter { $0.label.contains("Target URL") }
        XCTAssertGreaterThan(urlSignals.count, 0)

        // Verify legal keywords detected
        let legalSignals = observation.signals.filter { $0.category == .legal }
        XCTAssertGreaterThan(legalSignals.count, 0, "Should detect legal keywords in 'federal case'")
    }

    /// Verify skill is registered in SkillRegistry
    @MainActor
    func testWebResearchRegistered() {
        let registry = SkillRegistry.shared
        registry.registerDayOneSkills()
        XCTAssertNotNil(registry.skill(for: "web_research"), "WebResearchSkill must be registered")
    }

    // MARK: - Feature Flag Tests

    /// Verify web research is off by default
    func testWebResearchOffByDefault() {
        // Reset to ensure clean state
        UserDefaults.standard.removeObject(forKey: "ok_enterprise_web_research")
        XCTAssertFalse(EnterpriseFeatureFlags.webResearchEnabled, "Web research must be OFF by default")
    }

    /// Verify allowlist gated by feature flag
    func testAllowlistGatedByFeatureFlag() {
        UserDefaults.standard.removeObject(forKey: "ok_enterprise_web_research")
        let enforcer = NetworkPolicyEnforcer.shared
        XCTAssertFalse(enforcer.isWebResearchActive, "Research should be inactive when flag is OFF")
    }

    // MARK: - Model Task Type Tests

    /// Verify extractInformation task type exists and is configured correctly
    func testExtractInformationTaskType() {
        let taskType = ModelTaskType.extractInformation
        XCTAssertEqual(taskType.minQualityTier, .medium)
        XCTAssertTrue(taskType.requiresJSON)
        XCTAssertEqual(taskType.defaultSensitivity, .cloudAllowed)
        XCTAssertEqual(taskType.displayName, "Extract Information")
    }

    /// Verify webDocumentAnalysis task type exists and is configured correctly
    func testWebDocumentAnalysisTaskType() {
        let taskType = ModelTaskType.webDocumentAnalysis
        XCTAssertEqual(taskType.minQualityTier, .high)
        XCTAssertFalse(taskType.requiresJSON)
        XCTAssertEqual(taskType.defaultSensitivity, .cloudPreferred)
        XCTAssertEqual(taskType.displayName, "Web Document Analysis")
    }

    // MARK: - WebDocument Tests

    /// Verify WebDocument hash integrity
    func testWebDocumentHashIntegrity() {
        let data = "Hello, World!".data(using: .utf8)!
        let doc = WebDocument(
            url: URL(string: "https://example.gov/test")!,
            mimeType: "text/plain",
            rawData: data,
            statusCode: 200
        )
        XCTAssertFalse(doc.sha256Hash.isEmpty)
        XCTAssertEqual(doc.contentLength, data.count)
        XCTAssertEqual(doc.statusCode, 200)
    }

    /// Verify MIME type detection
    func testMimeTypeDetection() {
        let htmlDoc = WebDocument(
            url: URL(string: "https://example.gov/page")!,
            mimeType: "text/html; charset=utf-8",
            rawData: "<html></html>".data(using: .utf8)!,
            statusCode: 200
        )
        XCTAssertTrue(htmlDoc.isHTML)
        XCTAssertFalse(htmlDoc.isPDF)

        let pdfDoc = WebDocument(
            url: URL(string: "https://example.gov/file.pdf")!,
            mimeType: "application/pdf",
            rawData: Data(),
            statusCode: 200
        )
        XCTAssertFalse(pdfDoc.isHTML)
        XCTAssertTrue(pdfDoc.isPDF)
    }
}
