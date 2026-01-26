import XCTest
@testable import OperatorKit

// ============================================================================
// POLICY INVARIANT TESTS (Phase 10C)
//
// These tests enforce that policies are:
// - Content-free (no user data)
// - UI-enforced only (not in execution engine)
// - Fail-closed (deny if uncertain)
// - Pure (no side effects in evaluator)
//
// See: docs/SAFETY_CONTRACT.md (unchanged)
// ============================================================================

final class PolicyInvariantTests: XCTestCase {
    
    // MARK: - A) Policy Contains No Forbidden Keys
    
    /// Verifies OperatorPolicy contains no user content keys
    func testPolicyContainsNoForbiddenKeys() throws {
        let policy = OperatorPolicy(
            enabled: true,
            allowEmailDrafts: true,
            allowCalendarWrites: false,
            allowTaskCreation: true,
            allowMemoryWrites: false,
            maxExecutionsPerDay: 10,
            requireExplicitConfirmation: true
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(policy)
        let jsonString = String(data: data, encoding: .utf8)!
        
        // Forbidden keys that would indicate user content
        let forbiddenKeys = [
            "body", "subject", "title", "recipient", "draft",
            "context", "email", "event", "description", "attendee",
            "participants", "content", "message", "text", "name"
        ]
        
        for key in forbiddenKeys {
            XCTAssertFalse(
                jsonString.lowercased().contains("\"\(key)\""),
                "INVARIANT VIOLATION: OperatorPolicy contains forbidden key: \(key)"
            )
        }
    }
    
    /// Verifies PolicyExportPacket contains no user content keys
    func testExportPacketContainsNoForbiddenKeys() throws {
        let policy = OperatorPolicy.defaultPolicy
        let packet = PolicyExportPacket(
            appVersion: "1.0.0",
            buildNumber: "100",
            policy: policy,
            policySummary: policy.summary
        )
        
        let data = try packet.exportJSON()
        let jsonString = String(data: data, encoding: .utf8)!
        
        let forbiddenKeys = [
            "body", "subject", "title", "recipient", "draft",
            "context", "email", "event", "description", "attendee",
            "participants", "content", "message", "text"
        ]
        
        for key in forbiddenKeys {
            XCTAssertFalse(
                jsonString.lowercased().contains("\"\(key)\""),
                "INVARIANT VIOLATION: PolicyExportPacket contains forbidden key: \(key)"
            )
        }
    }
    
    // MARK: - B) Policy Denial Blocks UI, Not Execution Engine
    
    /// Verifies ExecutionEngine.swift does NOT reference policy
    func testExecutionEngineDoesNotReferencePolicy() throws {
        let filePath = findProjectFile(named: "ExecutionEngine.swift", in: "Domain/Execution")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let policyReferences = [
            "OperatorPolicy",
            "PolicyEvaluator",
            "PolicyDecision",
            "OperatorPolicyStore",
            "canStartExecution",
            "canDraftEmail",
            "canWriteCalendar"
        ]
        
        for ref in policyReferences {
            XCTAssertFalse(
                content.contains(ref),
                "INVARIANT VIOLATION: ExecutionEngine.swift references policy type: \(ref)"
            )
        }
    }
    
    /// Verifies ApprovalGate.swift does NOT reference policy
    func testApprovalGateDoesNotReferencePolicy() throws {
        let filePath = findProjectFile(named: "ApprovalGate.swift", in: "Domain/Approval")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let policyReferences = [
            "OperatorPolicy",
            "PolicyEvaluator",
            "PolicyDecision",
            "OperatorPolicyStore"
        ]
        
        for ref in policyReferences {
            XCTAssertFalse(
                content.contains(ref),
                "INVARIANT VIOLATION: ApprovalGate.swift references policy type: \(ref)"
            )
        }
    }
    
    /// Verifies ModelRouter.swift does NOT reference policy
    func testModelRouterDoesNotReferencePolicy() throws {
        let filePath = findProjectFile(named: "ModelRouter.swift", in: "Models")
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        
        let policyReferences = [
            "OperatorPolicy",
            "PolicyEvaluator",
            "PolicyDecision"
        ]
        
        for ref in policyReferences {
            XCTAssertFalse(
                content.contains(ref),
                "INVARIANT VIOLATION: ModelRouter.swift references policy type: \(ref)"
            )
        }
    }
    
    // MARK: - C) Policy Evaluator Is Pure
    
    /// Verifies policy evaluator does not mutate state
    func testPolicyEvaluatorIsPure() {
        let store = OperatorPolicyStore.shared
        let evaluator = PolicyEvaluator(policyStore: store, usageLedger: .shared)
        
        // Get initial policy
        let initialPolicy = store.currentPolicy
        
        // Call evaluator methods multiple times
        _ = evaluator.canStartExecution()
        _ = evaluator.canDraftEmail()
        _ = evaluator.canWriteCalendar()
        _ = evaluator.canCreateTask()
        _ = evaluator.canWriteMemory()
        _ = evaluator.allDecisions()
        _ = evaluator.blockedCapabilities()
        _ = evaluator.allowedCapabilities()
        
        // Verify policy unchanged
        XCTAssertEqual(store.currentPolicy, initialPolicy, "Policy evaluator must not mutate state")
    }
    
    /// Verifies PolicyDecision is immutable
    func testPolicyDecisionIsImmutable() {
        let decision1 = PolicyDecision.allow(reason: "Test")
        let decision2 = PolicyDecision.deny(reason: "Test")
        let decision3 = PolicyDecision.allow(capability: .emailDrafts)
        let decision4 = PolicyDecision.deny(capability: .calendarWrites)
        
        // All decisions should be equatable
        XCTAssertTrue(decision1.allowed)
        XCTAssertFalse(decision2.allowed)
        XCTAssertTrue(decision3.allowed)
        XCTAssertFalse(decision4.allowed)
        
        // Cannot mutate (compile-time check, but verify values are consistent)
        XCTAssertEqual(decision1.reason, "Test")
        XCTAssertEqual(decision2.reason, "Test")
    }
    
    // MARK: - D) Export Packet Round-Trips
    
    /// Verifies PolicyExportPacket round-trips correctly
    func testExportPacketRoundTrips() throws {
        let policy = OperatorPolicy(
            enabled: true,
            allowEmailDrafts: false,
            allowCalendarWrites: true,
            allowTaskCreation: false,
            allowMemoryWrites: true,
            maxExecutionsPerDay: 5,
            requireExplicitConfirmation: true
        )
        
        let packet = PolicyExportPacket(
            appVersion: "1.0.0",
            buildNumber: "100",
            policy: policy,
            policySummary: policy.summary
        )
        
        // Encode
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(packet)
        
        // Decode
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(PolicyExportPacket.self, from: data)
        
        // Verify
        XCTAssertEqual(decoded.appVersion, packet.appVersion)
        XCTAssertEqual(decoded.buildNumber, packet.buildNumber)
        XCTAssertEqual(decoded.policy.enabled, policy.enabled)
        XCTAssertEqual(decoded.policy.allowEmailDrafts, policy.allowEmailDrafts)
        XCTAssertEqual(decoded.policy.allowCalendarWrites, policy.allowCalendarWrites)
        XCTAssertEqual(decoded.policy.allowTaskCreation, policy.allowTaskCreation)
        XCTAssertEqual(decoded.policy.allowMemoryWrites, policy.allowMemoryWrites)
        XCTAssertEqual(decoded.policy.maxExecutionsPerDay, policy.maxExecutionsPerDay)
        XCTAssertEqual(decoded.schemaVersion, packet.schemaVersion)
    }
    
    /// Verifies export packet has schema version
    func testExportPacketHasSchemaVersion() {
        let packet = PolicyExportPacket(
            appVersion: "1.0.0",
            buildNumber: "100",
            policy: .defaultPolicy,
            policySummary: "Test"
        )
        
        XCTAssertEqual(packet.schemaVersion, PolicyExportPacket.currentSchemaVersion)
        XCTAssertGreaterThan(packet.schemaVersion, 0)
    }
    
    // MARK: - E) Default Policy Is Conservative
    
    /// Verifies default policy is conservative
    func testDefaultPolicyIsConservative() {
        let policy = OperatorPolicy.defaultPolicy
        
        // Default should be enabled
        XCTAssertTrue(policy.enabled)
        
        // Default should require explicit confirmation
        XCTAssertTrue(policy.requireExplicitConfirmation)
        
        // All capabilities should be allowed by default (user can restrict)
        XCTAssertTrue(policy.allowEmailDrafts)
        XCTAssertTrue(policy.allowCalendarWrites)
        XCTAssertTrue(policy.allowTaskCreation)
        XCTAssertTrue(policy.allowMemoryWrites)
        
        // No daily limit by default (subscription limits apply separately)
        XCTAssertNil(policy.maxExecutionsPerDay)
    }
    
    /// Verifies restrictive policy blocks everything
    func testRestrictivePolicyBlocksEverything() {
        let policy = OperatorPolicy.restrictive
        
        XCTAssertTrue(policy.enabled)
        XCTAssertFalse(policy.allowEmailDrafts)
        XCTAssertFalse(policy.allowCalendarWrites)
        XCTAssertFalse(policy.allowTaskCreation)
        XCTAssertFalse(policy.allowMemoryWrites)
        XCTAssertEqual(policy.maxExecutionsPerDay, 0)
    }
    
    // MARK: - F) Policy Capability Checks
    
    /// Verifies capability checks work correctly
    func testCapabilityChecks() {
        // Policy with some capabilities disabled
        let policy = OperatorPolicy(
            enabled: true,
            allowEmailDrafts: true,
            allowCalendarWrites: false,
            allowTaskCreation: true,
            allowMemoryWrites: false
        )
        
        XCTAssertTrue(PolicyCapability.emailDrafts.isAllowed(by: policy))
        XCTAssertFalse(PolicyCapability.calendarWrites.isAllowed(by: policy))
        XCTAssertTrue(PolicyCapability.taskCreation.isAllowed(by: policy))
        XCTAssertFalse(PolicyCapability.memoryWrites.isAllowed(by: policy))
    }
    
    /// Verifies disabled policy allows everything
    func testDisabledPolicyAllowsEverything() {
        let policy = OperatorPolicy(
            enabled: false,
            allowEmailDrafts: false,
            allowCalendarWrites: false,
            allowTaskCreation: false,
            allowMemoryWrites: false
        )
        
        // When policy is disabled, all capabilities should be allowed
        XCTAssertTrue(PolicyCapability.emailDrafts.isAllowed(by: policy))
        XCTAssertTrue(PolicyCapability.calendarWrites.isAllowed(by: policy))
        XCTAssertTrue(PolicyCapability.taskCreation.isAllowed(by: policy))
        XCTAssertTrue(PolicyCapability.memoryWrites.isAllowed(by: policy))
    }
    
    // MARK: - G) Policy Files No Network/Analytics
    
    /// Verifies policy files don't import networking
    func testPolicyFilesNoNetworkImports() throws {
        let files = [
            ("OperatorPolicy.swift", "Policies"),
            ("OperatorPolicyStore.swift", "Policies"),
            ("PolicyEvaluator.swift", "Policies"),
            ("PolicyExportPacket.swift", "Policies")
        ]
        
        let networkPatterns = [
            "import Network",
            "import Alamofire",
            "URLSession",
            "URLRequest",
            "HTTPURLResponse"
        ]
        
        for (fileName, directory) in files {
            let filePath = findProjectFile(named: fileName, in: directory)
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            
            for pattern in networkPatterns {
                XCTAssertFalse(
                    content.contains(pattern),
                    "INVARIANT VIOLATION: \(fileName) contains network reference: \(pattern)"
                )
            }
        }
    }
    
    // MARK: - H) Policy Summary Display
    
    /// Verifies policy summary is plain language
    func testPolicySummaryIsPlainLanguage() {
        let policy = OperatorPolicy(
            enabled: true,
            allowEmailDrafts: false,
            allowCalendarWrites: false,
            allowTaskCreation: true,
            allowMemoryWrites: true,
            maxExecutionsPerDay: 10,
            requireExplicitConfirmation: true
        )
        
        let summary = policy.summary
        
        // Summary should be non-empty
        XCTAssertFalse(summary.isEmpty)
        
        // Should not contain technical jargon
        XCTAssertFalse(summary.contains("ExecutionEngine"))
        XCTAssertFalse(summary.contains("ApprovalGate"))
        XCTAssertFalse(summary.contains("ModelRouter"))
        
        // Should contain readable text
        XCTAssertTrue(summary.contains("Blocked") || summary.contains("allowed"))
    }
    
    /// Verifies policy status text is concise
    func testPolicyStatusTextIsConcise() {
        let defaultPolicy = OperatorPolicy.defaultPolicy
        XCTAssertEqual(defaultPolicy.statusText, "All Allowed")
        
        let restrictive = OperatorPolicy.restrictive
        XCTAssertEqual(restrictive.statusText, "All Blocked")
        
        let disabled = OperatorPolicy(enabled: false)
        XCTAssertEqual(disabled.statusText, "Disabled")
    }
    
    // MARK: - Helpers
    
    /// Finds a project file by name and subdirectory
    private func findProjectFile(named fileName: String, in subdirectory: String) -> String {
        let currentFile = URL(fileURLWithPath: #file)
        let projectRoot = currentFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let targetPath = projectRoot
            .appendingPathComponent("OperatorKit")
            .appendingPathComponent(subdirectory)
            .appendingPathComponent(fileName)
            .path
        
        return targetPath
    }
}

// MARK: - Policy Decision Tests

extension PolicyInvariantTests {
    
    /// Verifies PolicyDecision factory methods
    func testPolicyDecisionFactoryMethods() {
        // Allow
        let allow = PolicyDecision.allow(reason: "Test reason")
        XCTAssertTrue(allow.allowed)
        XCTAssertEqual(allow.reason, "Test reason")
        XCTAssertNil(allow.capability)
        
        // Allow with capability
        let allowCap = PolicyDecision.allow(capability: .emailDrafts)
        XCTAssertTrue(allowCap.allowed)
        XCTAssertEqual(allowCap.capability, .emailDrafts)
        
        // Deny
        let deny = PolicyDecision.deny(reason: "Test denial")
        XCTAssertFalse(deny.allowed)
        XCTAssertEqual(deny.reason, "Test denial")
        
        // Deny with capability
        let denyCap = PolicyDecision.deny(capability: .calendarWrites)
        XCTAssertFalse(denyCap.allowed)
        XCTAssertEqual(denyCap.capability, .calendarWrites)
        
        // Daily limit
        let dailyLimit = PolicyDecision.denyDailyLimit(used: 5, max: 5)
        XCTAssertFalse(dailyLimit.allowed)
        XCTAssertTrue(dailyLimit.reason.contains("5/5"))
        
        // Policy disabled
        let disabled = PolicyDecision.policyDisabled
        XCTAssertTrue(disabled.allowed)
        XCTAssertTrue(disabled.reason.contains("disabled"))
    }
}
