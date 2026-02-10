import SwiftUI

// ============================================================================
// ENTERPRISE ONBOARDING VIEW — Pilot-Ready Provisioning UI
//
// Flow: Create Org → Enroll Device → Apply Policy → Configure Mirror → Done
// ============================================================================

struct EnterpriseOnboardingView: View {

    @StateObject private var provisioning = OrgProvisioningService.shared
    @State private var orgName: String = ""
    @State private var mirrorURL: String = ""
    @State private var orgAuthorityURL: String = ""
    @State private var selectedTemplate: OrgProvisioningService.PolicyTemplate = OrgProvisioningService.defaultPolicyTemplates[0]
    @State private var showSuccess = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                progressStepper
                currentStepView
            }
            .padding()
        }
        .background(OKColor.backgroundPrimary)
        .navigationTitle("Enterprise Setup")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ENTERPRISE PROVISIONING")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)

            Text("Set up your organization for governed AI execution")
                .font(.system(size: 15))
                .foregroundStyle(OKColor.textSecondary)
        }
    }

    // MARK: - Progress

    private var progressStepper: some View {
        HStack(spacing: 4) {
            ForEach(steps, id: \.title) { step in
                VStack(spacing: 4) {
                    Circle()
                        .fill(step.isComplete ? OKColor.riskNominal : (step.isCurrent ? OKColor.actionPrimary : OKColor.borderSubtle))
                        .frame(width: 10, height: 10)
                    Text(step.title)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(step.isComplete ? OKColor.riskNominal : OKColor.textMuted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    private struct Step {
        let title: String
        let isComplete: Bool
        let isCurrent: Bool
    }

    private var steps: [Step] {
        let state = provisioning.enrollmentState
        return [
            Step(title: "Org", isComplete: state.rawValue != "not_started", isCurrent: state == .notStarted),
            Step(title: "Device", isComplete: ["device_enrolled", "policies_applied", "mirror_configured", "fully_provisioned"].contains(state.rawValue), isCurrent: state == .orgCreated),
            Step(title: "Policy", isComplete: ["policies_applied", "mirror_configured", "fully_provisioned"].contains(state.rawValue), isCurrent: state == .deviceEnrolled),
            Step(title: "Mirror", isComplete: ["mirror_configured", "fully_provisioned"].contains(state.rawValue), isCurrent: state == .policiesApplied),
            Step(title: "Done", isComplete: state == .fullyProvisioned, isCurrent: state == .mirrrorConfigured)
        ]
    }

    // MARK: - Step Views

    @ViewBuilder
    private var currentStepView: some View {
        switch provisioning.enrollmentState {
        case .notStarted:
            createOrgStep
        case .orgCreated:
            enrollDeviceStep
        case .deviceEnrolled:
            policyStep
        case .policiesApplied:
            mirrorStep
        case .mirrrorConfigured:
            finalizeStep
        case .fullyProvisioned:
            completedView
        }
    }

    // Step 1: Create Org
    private var createOrgStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("STEP 1 — CREATE ORGANIZATION")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)

            TextField("Organization Name", text: $orgName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 15))

            Button("Create Organization") {
                guard !orgName.isEmpty else { return }
                _ = provisioning.createOrg(name: orgName)
            }
            .buttonStyle(OKPrimaryButtonStyle())
            .disabled(orgName.isEmpty)
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    // Step 2: Enroll Device
    private var enrollDeviceStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("STEP 2 — ENROLL THIS DEVICE")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)

            HStack {
                Image(systemName: "iphone")
                    .foregroundStyle(OKColor.actionPrimary)
                Text("This device will become the admin operator")
                    .font(.system(size: 15))
                    .foregroundStyle(OKColor.textSecondary)
            }

            if let fingerprint = SecureEnclaveApprover.shared.deviceFingerprint {
                Text("Fingerprint: \(fingerprint.prefix(24))...")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(OKColor.textMuted)
            }

            Button("Enroll Device (Biometric Required)") {
                provisioning.enrollCurrentDevice(displayName: "\(orgName) Admin")
            }
            .buttonStyle(OKPrimaryButtonStyle())
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    // Step 3: Policy Template
    private var policyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("STEP 3 — SELECT POLICY TEMPLATE")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)

            ForEach(OrgProvisioningService.defaultPolicyTemplates, id: \.id) { template in
                Button {
                    selectedTemplate = template
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(OKColor.textPrimary)
                            Text("LOW: \(template.lowRiskSigners) signer · HIGH: \(template.highRiskSigners) signers · CRITICAL: \(template.criticalRiskSigners) signers")
                                .font(.system(size: 12))
                                .foregroundStyle(OKColor.textMuted)
                            Text("Budget: $\(String(format: "%.0f", template.dailyBudgetUSD))/day · Cloud: \(template.cloudAllowed ? "ON" : "OFF")")
                                .font(.system(size: 12))
                                .foregroundStyle(OKColor.textMuted)
                        }
                        Spacer()
                        if selectedTemplate.id == template.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(OKColor.actionPrimary)
                        }
                    }
                    .padding()
                    .background(selectedTemplate.id == template.id ? OKColor.backgroundTertiary : OKColor.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(selectedTemplate.id == template.id ? OKColor.actionPrimary : OKColor.borderSubtle, lineWidth: 1)
                    )
                }
            }

            Button("Apply Policy") {
                provisioning.applyPolicyTemplate(selectedTemplate)
            }
            .buttonStyle(OKPrimaryButtonStyle())
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    // Step 4: Mirror
    private var mirrorStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("STEP 4 — CONFIGURE AUDIT MIRROR (OPTIONAL)")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)

            TextField("Mirror Endpoint URL", text: $mirrorURL)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 15))
                .keyboardType(.URL)
                .autocapitalization(.none)

            TextField("Org Authority URL (for co-signing)", text: $orgAuthorityURL)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 15))
                .keyboardType(.URL)
                .autocapitalization(.none)

            HStack(spacing: 12) {
                Button("Configure") {
                    if let mirror = URL(string: mirrorURL), !mirrorURL.isEmpty {
                        provisioning.configureMirrorEndpoint(mirror)
                    }
                    if let authority = URL(string: orgAuthorityURL), !orgAuthorityURL.isEmpty {
                        provisioning.configureOrgAuthority(authority)
                    }
                    if provisioning.enrollmentState == .policiesApplied {
                        // Still advance even without mirror
                        provisioning.configureMirrorEndpoint(URL(string: "https://placeholder.operatorkit.dev")!)
                    }
                }
                .buttonStyle(OKPrimaryButtonStyle())

                Button("Skip") {
                    provisioning.configureMirrorEndpoint(URL(string: "https://placeholder.operatorkit.dev")!)
                }
                .foregroundStyle(OKColor.textMuted)
                .font(.system(size: 15, weight: .medium))
            }
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    // Step 5: Finalize
    private var finalizeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("STEP 5 — FINALIZE PROVISIONING")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)

            if let org = provisioning.currentOrg {
                Group {
                    Text("Organization: \(org.name)")
                    Text("Policy: \(org.policyTemplateId)")
                    Text("Budget: $\(String(format: "%.0f", org.economicBudgetUSD))/day")
                    Text("Admin: \(org.adminDeviceFingerprint.prefix(20))...")
                }
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(OKColor.textSecondary)
            }

            Button("Complete Setup") {
                provisioning.completeProvisioning()
            }
            .buttonStyle(OKPrimaryButtonStyle())
        }
        .padding()
        .background(OKColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
    }

    // Completed
    private var completedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(OKColor.riskNominal)
            Text("ENTERPRISE READY")
                .font(.system(size: 22, weight: .bold))
                .tracking(0.3)
                .foregroundStyle(OKColor.textPrimary)
            Text("Your organization is provisioned and ready for governed AI execution.")
                .font(.system(size: 15))
                .foregroundStyle(OKColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}
