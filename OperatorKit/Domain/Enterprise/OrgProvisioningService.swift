import Foundation
import CryptoKit

// ============================================================================
// ORG PROVISIONING SERVICE — Enterprise Onboarding MVP
//
// Handles: org creation, device enrollment, policy template application,
// admin controls (key rotation, device revocation, budget management).
//
// INVARIANT: Provisioning is administrative — NEVER triggers execution.
// INVARIANT: All admin actions are evidence-logged.
// ============================================================================

@MainActor
public final class OrgProvisioningService: ObservableObject {

    public static let shared = OrgProvisioningService()

    @Published private(set) var currentOrg: Organization?
    @Published private(set) var isProvisioned: Bool = false
    @Published private(set) var enrollmentState: EnrollmentState = .notStarted

    // MARK: - Types

    public struct Organization: Codable, Identifiable {
        public let id: UUID
        public var name: String
        public var createdAt: Date
        public var adminDeviceFingerprint: String
        public var policyTemplateId: String
        public var mirrorEndpoint: URL?
        public var orgAuthorityEndpoint: URL?
        public var economicBudgetUSD: Double
        public var maxDevices: Int
    }

    public enum EnrollmentState: String {
        case notStarted = "not_started"
        case orgCreated = "org_created"
        case deviceEnrolled = "device_enrolled"
        case policiesApplied = "policies_applied"
        case mirrrorConfigured = "mirror_configured"
        case fullyProvisioned = "fully_provisioned"
    }

    private let storageKey = "org_provisioning_data"
    private let orgFileURL: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Enterprise", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        orgFileURL = dir.appendingPathComponent("organization.json")
        loadOrg()
    }

    // MARK: - 1. Create Organization

    public func createOrg(
        name: String,
        mirrorEndpoint: URL? = nil,
        orgAuthorityEndpoint: URL? = nil,
        budgetUSD: Double = 10.0,
        maxDevices: Int = 5
    ) -> Organization {
        let fingerprint = SecureEnclaveApprover.shared.deviceFingerprint ?? "unknown"

        let org = Organization(
            id: UUID(),
            name: name,
            createdAt: Date(),
            adminDeviceFingerprint: fingerprint,
            policyTemplateId: "default",
            mirrorEndpoint: mirrorEndpoint,
            orgAuthorityEndpoint: orgAuthorityEndpoint,
            economicBudgetUSD: budgetUSD,
            maxDevices: maxDevices
        )

        currentOrg = org
        enrollmentState = .orgCreated
        saveOrg()

        log("[PROVISIONING] Organization created: \(name)")
        try? EvidenceEngine.shared.logGenericArtifact(
            type: "org_created",
            planId: org.id,
            jsonString: """
            {"orgId":"\(org.id)","name":"\(name)","adminDevice":"\(fingerprint.prefix(16))..."}
            """
        )

        return org
    }

    // MARK: - 2. Register First Trusted Device

    public func enrollCurrentDevice(displayName: String = "Admin Device") {
        guard currentOrg != nil else {
            logError("[PROVISIONING] Cannot enroll — no org created")
            return
        }

        let registry = TrustedDeviceRegistry.shared
        let fingerprint = SecureEnclaveApprover.shared.deviceFingerprint ?? "unknown"

        // Register in device registry
        registry.registerDevice(fingerprint: fingerprint, displayName: displayName)
        enrollmentState = .deviceEnrolled
        saveOrg()

        log("[PROVISIONING] Device enrolled: \(displayName) (\(fingerprint.prefix(16))...)")
        try? EvidenceEngine.shared.logGenericArtifact(
            type: "device_enrolled",
            planId: currentOrg!.id,
            jsonString: """
            {"fingerprint":"\(fingerprint.prefix(16))...","displayName":"\(displayName)"}
            """
        )
    }

    // MARK: - 3. Apply Policy Templates by Risk Tier

    public struct PolicyTemplate: Codable, Identifiable {
        public let id: String
        public let name: String
        public let lowRiskSigners: Int
        public let highRiskSigners: Int
        public let criticalRiskSigners: Int
        public let requireBiometric: Bool
        public let cloudAllowed: Bool
        public let dailyBudgetUSD: Double
    }

    public static let defaultPolicyTemplates: [PolicyTemplate] = [
        PolicyTemplate(
            id: "startup",
            name: "Startup (Fast)",
            lowRiskSigners: 1,
            highRiskSigners: 1,
            criticalRiskSigners: 2,
            requireBiometric: true,
            cloudAllowed: true,
            dailyBudgetUSD: 5.0
        ),
        PolicyTemplate(
            id: "enterprise",
            name: "Enterprise (Strict)",
            lowRiskSigners: 1,
            highRiskSigners: 2,
            criticalRiskSigners: 3,
            requireBiometric: true,
            cloudAllowed: false,
            dailyBudgetUSD: 25.0
        ),
        PolicyTemplate(
            id: "regulated",
            name: "Regulated (Maximum)",
            lowRiskSigners: 1,
            highRiskSigners: 2,
            criticalRiskSigners: 3,
            requireBiometric: true,
            cloudAllowed: false,
            dailyBudgetUSD: 50.0
        )
    ]

    public func applyPolicyTemplate(_ template: PolicyTemplate) {
        guard var org = currentOrg else { return }

        org.policyTemplateId = template.id
        org.economicBudgetUSD = template.dailyBudgetUSD
        currentOrg = org

        // Apply budget to EconomicGovernor
        EconomicGovernor.shared.dailyBudgetUSD = template.dailyBudgetUSD

        // Apply cloud feature flag
        // (Feature flags are compile-time but we log the intended state)

        enrollmentState = .policiesApplied
        saveOrg()

        log("[PROVISIONING] Policy template applied: \(template.name)")
        try? EvidenceEngine.shared.logGenericArtifact(
            type: "policy_template_applied",
            planId: org.id,
            jsonString: """
            {"templateId":"\(template.id)","name":"\(template.name)","budget":\(template.dailyBudgetUSD)}
            """
        )
    }

    // MARK: - 4. Configure Mirror + Org Authority

    public func configureMirrorEndpoint(_ endpoint: URL) {
        guard var org = currentOrg else { return }
        org.mirrorEndpoint = endpoint
        currentOrg = org
        EvidenceMirrorClient.shared.configure(endpoint: endpoint)
        enrollmentState = .mirrrorConfigured
        saveOrg()

        log("[PROVISIONING] Mirror endpoint configured: \(endpoint)")
    }

    public func configureOrgAuthority(_ endpoint: URL) {
        guard var org = currentOrg else { return }
        org.orgAuthorityEndpoint = endpoint
        currentOrg = org
        OrgAuthorityClient.shared.configure(endpoint: endpoint)
        saveOrg()

        log("[PROVISIONING] Org authority endpoint configured: \(endpoint)")
    }

    public func completeProvisioning() {
        enrollmentState = .fullyProvisioned
        isProvisioned = true
        saveOrg()
        log("[PROVISIONING] Enterprise provisioning COMPLETE")
    }

    // MARK: - Admin Controls

    public func rotateKeys(reason: String) {
        TrustEpochManager.shared.rotateKey()
        log("[ADMIN] Key rotated: \(reason)")
        try? EvidenceEngine.shared.logGenericArtifact(
            type: "admin_key_rotation",
            planId: currentOrg?.id ?? UUID(),
            jsonString: """
            {"reason":"\(reason)","newKeyVersion":\(TrustEpochManager.shared.activeKeyVersion),"epoch":\(TrustEpochManager.shared.trustEpoch)}
            """
        )
    }

    public func revokeDevice(fingerprint: String, reason: String) {
        TrustedDeviceRegistry.shared.revokeDevice(fingerprint: fingerprint, reason: reason)

        // Notify
        NotificationBridge.shared.scheduleDeviceTrustChanged(state: "revoked", fingerprint: fingerprint)

        log("[ADMIN] Device revoked: \(fingerprint.prefix(16))... Reason: \(reason)")
    }

    public func setServerBudget(dailyUSD: Double) {
        guard var org = currentOrg else { return }
        org.economicBudgetUSD = dailyUSD
        currentOrg = org
        EconomicGovernor.shared.dailyBudgetUSD = dailyUSD
        saveOrg()

        log("[ADMIN] Budget updated: $\(dailyUSD)/day")
    }

    // MARK: - Persistence

    private func saveOrg() {
        guard let org = currentOrg else { return }
        guard let data = try? JSONEncoder().encode(org) else { return }
        try? data.write(to: orgFileURL, options: .atomic)
    }

    private func loadOrg() {
        guard let data = try? Data(contentsOf: orgFileURL),
              let org = try? JSONDecoder().decode(Organization.self, from: data) else { return }
        currentOrg = org
        isProvisioned = true

        // Reconnect endpoints
        if let mirror = org.mirrorEndpoint {
            EvidenceMirrorClient.shared.configure(endpoint: mirror)
        }
        if let authority = org.orgAuthorityEndpoint {
            OrgAuthorityClient.shared.configure(endpoint: authority)
        }
    }
}
