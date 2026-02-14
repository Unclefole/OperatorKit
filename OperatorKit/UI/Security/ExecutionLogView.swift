import SwiftUI

// ============================================================================
// EXECUTION LOG — Read-Only Certificate Viewer
//
// Displays execution certificates with verification status.
// NO editing. NO deletion. Read-only audit view.
// ============================================================================

struct ExecutionLogView: View {

    @State private var certificates: [ExecutionCertificate] = []
    @State private var selectedCertificate: ExecutionCertificate?
    @State private var chainStatus: ChainVerificationResult?

    var body: some View {
        List {
            chainStatusSection
            certificateListSection
        }
        .navigationTitle("Execution Log")
        .onAppear { loadCertificates() }
    }

    // MARK: - Chain Status

    private var chainStatusSection: some View {
        Section {
            if let status = chainStatus {
                HStack {
                    Image(systemName: status.intact ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .foregroundColor(status.intact ? .green : .red)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(status.intact ? "Chain Intact" : "Chain BROKEN")
                            .font(.headline)
                            .foregroundColor(status.intact ? .green : .red)
                        Text("\(status.verifiedCount) certificate(s) verified")
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            } else {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(OKColor.textMuted)
                    Text("No certificates yet")
                        .foregroundColor(OKColor.textSecondary)
                }
            }
        } header: {
            Text("HASH CHAIN STATUS")
        }
    }

    // MARK: - Certificate List

    private var certificateListSection: some View {
        Section {
            if certificates.isEmpty {
                Text("No execution certificates recorded")
                    .foregroundColor(OKColor.textMuted)
                    .italic()
            } else {
                ForEach(certificates.reversed()) { cert in
                    NavigationLink {
                        CertificateDetailView(certificate: cert)
                    } label: {
                        certificateRow(cert)
                    }
                }
            }
        } header: {
            Text("CERTIFICATES (\(certificates.count))")
        }
    }

    private func certificateRow(_ cert: ExecutionCertificate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                riskBadge(cert.riskTier)
                Text(cert.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
                Spacer()
                Image(systemName: cert.verifySignature() ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(cert.verifySignature() ? .green : .red)
                    .font(.caption)
            }
            HStack(spacing: 6) {
                if let cid = cert.connectorId {
                    Label(cid, systemImage: "link")
                        .font(.caption2)
                        .foregroundColor(OKColor.textMuted)
                }
                Text(cert.id.uuidString.prefix(8) + "…")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(OKColor.textMuted)
            }
        }
        .padding(.vertical, 2)
    }

    private func riskBadge(_ tier: RiskTier) -> some View {
        Text(tier.rawValue)
            .font(.system(.caption2, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(riskColor(tier).opacity(0.2))
            .foregroundColor(riskColor(tier))
            .cornerRadius(4)
    }

    private func riskColor(_ tier: RiskTier) -> Color {
        switch tier {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }

    // MARK: - Data Loading

    private func loadCertificates() {
        certificates = ExecutionCertificateStore.shared.all
        chainStatus = ExecutionCertificateStore.shared.verifyChainIntegrity()
    }
}

// MARK: - Certificate Detail View

struct CertificateDetailView: View {

    let certificate: ExecutionCertificate
    @State private var verification: CertificateVerificationStatus?

    var body: some View {
        List {
            verificationSection
            identitySection
            executionContextSection
            authorizationSection
            connectorSection
            policySection
            chainSection
        }
        .navigationTitle("Certificate")
        .onAppear { verify() }
    }

    private var verificationSection: some View {
        Section {
            if let v = verification {
                verificationRow("Signature Valid", passed: v.signatureValid)
                verificationRow("Hash Integrity", passed: v.hashIntegrity)
                verificationRow("Chain Intact", passed: v.chainIntact)
            } else {
                Text("Verifying…")
                    .foregroundColor(OKColor.textMuted)
            }
        } header: {
            Text("VERIFICATION")
        }
    }

    private func verificationRow(_ label: String, passed: Bool) -> some View {
        HStack {
            Image(systemName: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(passed ? .green : .red)
            Text(label)
            Spacer()
            Text(passed ? "PASS" : "FAIL")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundColor(passed ? .green : .red)
        }
    }

    private var identitySection: some View {
        Section {
            detailRow("Certificate ID", certificate.id.uuidString)
            detailRow("Timestamp", certificate.timestamp.formatted())
            detailRow("Risk Tier", certificate.riskTier.rawValue)
        } header: {
            Text("IDENTITY")
        }
    }

    private var executionContextSection: some View {
        Section {
            hashRow("Intent Hash", certificate.intentHash)
            hashRow("Proposal Hash", certificate.proposalHash)
            hashRow("Result Hash", certificate.resultHash)
        } header: {
            Text("EXECUTION CONTEXT (HASHED)")
        }
    }

    private var authorizationSection: some View {
        Section {
            hashRow("Token Hash", certificate.authorizationTokenHash)
            hashRow("Approver Hash", certificate.approverIdHash)
            hashRow("Device Key", certificate.deviceKeyId)
        } header: {
            Text("AUTHORIZATION (HASHED)")
        }
    }

    @ViewBuilder
    private var connectorSection: some View {
        if certificate.connectorId != nil || certificate.connectorVersion != nil {
            Section {
                if let cid = certificate.connectorId {
                    detailRow("Connector", cid)
                }
                if let ver = certificate.connectorVersion {
                    detailRow("Version", ver)
                }
            } header: {
                Text("CONNECTOR")
            }
        }
    }

    private var policySection: some View {
        Section {
            hashRow("Policy Snapshot", certificate.policySnapshotHash)
        } header: {
            Text("POLICY")
        }
    }

    private var chainSection: some View {
        Section {
            hashRow("Certificate Hash", certificate.certificateHash)
            hashRow("Previous Hash", certificate.previousCertificateHash)
            detailRow("Signature Size", "\(certificate.signature.count) bytes")
        } header: {
            Text("HASH CHAIN")
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(OKColor.textMuted)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(OKColor.textSecondary)
                .lineLimit(2)
        }
    }

    private func hashRow(_ label: String, _ hash: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(OKColor.textMuted)
            Text(hash.prefix(32) + "…")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(OKColor.textSecondary)
        }
    }

    private func verify() {
        verification = ExecutionCertificateStore.shared.verifyCertificate(certificate.id)
    }
}
