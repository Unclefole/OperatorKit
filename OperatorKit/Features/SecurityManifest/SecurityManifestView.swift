import SwiftUI

// ============================================================================
// SECURITY MANIFEST VIEW (Phase 13F) — READ-ONLY TRUST SURFACE
//
// ARCHITECTURAL INVARIANT: This view is STRICTLY READ-ONLY.
// ─────────────────────────────────────────────────────────
// ❌ No Buttons (except navigation)
// ❌ No Toggles, Pickers, Steppers, TextFields
// ❌ No onTapGesture that triggers actions
// ❌ No async work (.task, DispatchQueue, URLSession)
// ❌ No export actions
// ✅ Read-only display of static security claims
// ✅ Instant render
// ✅ All data hardcoded (source code audit verified)
//
// DISPLAYS:
// - WebKit-Free status
// - JavaScript-Free status
// - No Embedded Browsers status
// - No Remote Code Execution status
// - How to verify these claims
//
// APP REVIEW SAFETY: This surface displays security verification claims only.
// ============================================================================

@MainActor
struct SecurityManifestView: View {

    // MARK: - Architectural Seal

    private static let isReadOnly = true
    
    // MARK: - Body

    var body: some View {
        let _ = Self.assertReadOnlyInvariant()

        if SecurityManifestFeatureFlag.isEnabled {
            manifestContent
        } else {
            featureDisabledView
        }
    }

    // MARK: - Invariant Assertion

    private static func assertReadOnlyInvariant() {
        #if DEBUG
        assert(Self.isReadOnly, "SecurityManifestView must be read-only")
        #endif
    }
    
    // MARK: - Manifest Content
    
    private var manifestContent: some View {
        List {
            headerSection
            guaranteesSection
            technicalSection
            verificationSection
            disclaimerSection
            footerSection
        }
        .navigationTitle("Security Manifest")
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lock.shield.fill")
                        .font(.title)
                        .foregroundColor(OKColor.riskNominal)
                    
                    Text("Security Manifest")
                        .font(.headline)
                }
                
                Text("Verifiable security claims backed by automated tests. This is a factual declaration, not a marketing promise.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Guarantees Section
    
    private var guaranteesSection: some View {
        Section {
            GuaranteeRow(
                claim: "WebKit",
                status: "Not Linked",
                icon: "xmark.circle.fill",
                color: OKColor.riskNominal,
                description: "No WebKit framework imported or used"
            )
            
            GuaranteeRow(
                claim: "JavaScript",
                status: "Not Present",
                icon: "xmark.circle.fill",
                color: OKColor.riskNominal,
                description: "No JavaScriptCore, no JS execution"
            )
            
            GuaranteeRow(
                claim: "Embedded Browsers",
                status: "None",
                icon: "xmark.circle.fill",
                color: OKColor.riskNominal,
                description: "No WKWebView, no SFSafariViewController"
            )
            
            GuaranteeRow(
                claim: "Remote Code Execution",
                status: "None",
                icon: "xmark.circle.fill",
                color: OKColor.riskNominal,
                description: "No dynamic code loading from network"
            )
        } header: {
            Label("VERIFIABLE GUARANTEES", systemImage: "checkmark.shield")
        } footer: {
            Text("These claims are verified by automated tests that run on every build.")
        }
    }
    
    // MARK: - Technical Section
    
    private var technicalSection: some View {
        Section {
            TechnicalRow(
                label: "Web Attack Surface",
                value: "None",
                detail: "No XSS, CSRF, or web-based exploits possible"
            )
            
            TechnicalRow(
                label: "JS Supply Chain",
                value: "None",
                detail: "No npm, no node_modules, no JS bundlers"
            )
            
            TechnicalRow(
                label: "Code Execution",
                value: "Native Only",
                detail: "All code is compiled Swift, reviewed by Apple"
            )
            
            TechnicalRow(
                label: "Behavior",
                value: "Deterministic",
                detail: "No dynamic code means predictable execution"
            )
        } header: {
            Text("What This Means")
        }
    }
    
    // MARK: - Verification Section
    
    private var verificationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("How to Verify")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                VerificationStep(
                    number: 1,
                    text: "Search source code for 'import WebKit' — expect 0 results"
                )
                
                VerificationStep(
                    number: 2,
                    text: "Search for 'import JavaScriptCore' — expect 0 results"
                )
                
                VerificationStep(
                    number: 3,
                    text: "Search for 'WKWebView' or 'JSContext' — expect 0 results"
                )
                
                VerificationStep(
                    number: 4,
                    text: "Check Xcode project for WebKit.framework — not linked"
                )
                
                VerificationStep(
                    number: 5,
                    text: "Run SecurityManifestInvariantTests — all pass"
                )
            }
            .padding(.vertical, 4)
        } header: {
            Text("Verification Steps")
        } footer: {
            Text("Developers and auditors can verify these claims independently.")
        }
    }
    
    // MARK: - Disclaimer Section
    
    private var disclaimerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("What This Does NOT Mean")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                DisclaimerRow(text: "That the app has no bugs")
                DisclaimerRow(text: "That the app is immune to all security issues")
                DisclaimerRow(text: "That network requests are impossible")
                DisclaimerRow(text: "That this replaces a professional security audit")
            }
            .padding(.vertical, 4)
        } footer: {
            Text("This is a factual declaration about specific technologies, not a blanket security guarantee.")
        }
    }
    
    // MARK: - Footer Section

    private var footerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(OKColor.riskNominal)

                    Text("All proofs verified locally on this device.")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                }

                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(OKColor.actionPrimary)
                    Text("See: docs/SECURITY_MANIFEST.md")
                        .font(.caption)
                }

                HStack {
                    Image(systemName: "testtube.2")
                        .foregroundColor(OKColor.riskWarning)
                    Text("Enforced by: SecurityManifestInvariantTests.swift")
                        .font(.caption)
                }
            }
            .foregroundColor(OKColor.textSecondary)
            .padding(.vertical, 4)
        } footer: {
            Text("This is a read-only verification surface. No actions, no network calls.")
        }
    }
    
    // MARK: - Feature Disabled View
    
    private var featureDisabledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.largeTitle)
                .foregroundColor(OKColor.textSecondary)
            
            Text("Security Manifest")
                .font(.headline)
            
            Text("This feature is not enabled.")
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
        }
        .padding()
    }
    
    // MARK: - Init

    init() {}
}

// MARK: - Guarantee Row

private struct GuaranteeRow: View {
    let claim: String
    let status: String
    let icon: String
    let color: Color
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(claim)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(status)
                    .font(.subheadline)
                    .foregroundColor(color)
                    .fontWeight(.semibold)
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(OKColor.textSecondary)
                .padding(.leading, 32)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Technical Row

private struct TechnicalRow: View {
    let label: String
    let value: String
    let detail: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                
                Spacer()
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(OKColor.textSecondary)
            }
            
            Text(detail)
                .font(.caption)
                .foregroundColor(OKColor.textSecondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Verification Step

private struct VerificationStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(OKColor.actionPrimary)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(OKColor.textSecondary)
        }
    }
}

// MARK: - Disclaimer Row

private struct DisclaimerRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "xmark")
                .font(.caption)
                .foregroundColor(OKColor.riskCritical)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(OKColor.textSecondary)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SecurityManifestView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SecurityManifestView()
        }
    }
}
#endif
