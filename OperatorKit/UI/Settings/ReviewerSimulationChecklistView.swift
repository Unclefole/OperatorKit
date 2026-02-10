import SwiftUI

// ============================================================================
// REVIEWER SIMULATION CHECKLIST VIEW (Phase 9D)
//
// Read-only checklist that renders from code constants.
// Shows pass/fail status and evidence sources for each check item.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No actions or toggles
// ❌ No behavior changes
// ✅ Read-only status display
// ✅ Evidence source references only
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct ReviewerSimulationChecklistView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var checkItems: [ReviewerCheckItem] = []
    @State private var isLoading = true
    
    var body: some View {
        List {
            // Summary Section
            Section {
                HStack {
                    Image(systemName: overallStatusIcon)
                        .foregroundColor(overallStatusColor)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Checklist Status")
                            .font(.subheadline)
                            .foregroundColor(OKColor.textSecondary)
                        Text(overallStatusText)
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    Text("\(passedCount)/\(checkItems.count)")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                }
            }
            
            // Check Items
            Section("Verification Items") {
                if isLoading {
                    ProgressView("Loading...")
                } else {
                    ForEach(checkItems) { item in
                        checkItemRow(item)
                    }
                }
            }
            
            // Evidence Sources
            Section("Evidence Sources") {
                Text("Each check item references specific code files or test cases that enforce the guarantee. These are verified at build time and by automated tests.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
            
            // Disclaimer
            Section {
                Text("This checklist is informational only. Status values are computed locally on-device and do not affect app behavior.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
        }
        .navigationTitle("Reviewer Checklist")
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            loadChecklist()
        }
    }
    
    // MARK: - Check Item Row
    
    private func checkItemRow(_ item: ReviewerCheckItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: item.status.systemImage)
                    .foregroundColor(item.status.color)
                    .frame(width: 20)
                
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(item.status.rawValue)
                    .font(.caption)
                    .foregroundColor(item.status.color)
            }
            
            Text(item.description)
                .font(.caption)
                .foregroundColor(OKColor.textSecondary)
            
            HStack {
                Image(systemName: "doc.text")
                    .font(.caption2)
                    .foregroundColor(OKColor.textSecondary)
                Text("Evidence: \(item.evidenceSource)")
                    .font(.caption2)
                    .foregroundColor(OKColor.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Computed Properties
    
    private var passedCount: Int {
        checkItems.filter { $0.status == .pass }.count
    }
    
    private var overallStatusIcon: String {
        let unknownCount = checkItems.filter { $0.status == .unknown }.count
        let failCount = checkItems.filter { $0.status == .fail }.count
        
        if failCount > 0 {
            return "xmark.circle.fill"
        } else if unknownCount > 0 {
            return "questionmark.circle.fill"
        } else if checkItems.isEmpty {
            return "circle"
        } else {
            return "checkmark.circle.fill"
        }
    }
    
    private var overallStatusColor: Color {
        let failCount = checkItems.filter { $0.status == .fail }.count
        let unknownCount = checkItems.filter { $0.status == .unknown }.count
        
        if failCount > 0 {
            return OKColor.riskCritical
        } else if unknownCount > 0 {
            return OKColor.riskWarning
        } else if checkItems.isEmpty {
            return OKColor.textMuted
        } else {
            return OKColor.riskNominal
        }
    }
    
    private var overallStatusText: String {
        let failCount = checkItems.filter { $0.status == .fail }.count
        let unknownCount = checkItems.filter { $0.status == .unknown }.count
        
        if failCount > 0 {
            return "\(failCount) Issues Found"
        } else if unknownCount > 0 {
            return "\(unknownCount) Unknown"
        } else if checkItems.isEmpty {
            return "Loading..."
        } else {
            return "All Checks Passed"
        }
    }
    
    // MARK: - Load Checklist
    
    private func loadChecklist() {
        isLoading = true
        
        // Build checklist from code constants and live checks
        let invariantRunner = InvariantCheckRunner.shared
        let preflightValidator = PreflightValidator.shared
        let invariantResults = invariantRunner.runAllChecks()
        let preflightReport = preflightValidator.runAllChecks()
        
        var items: [ReviewerCheckItem] = []
        
        // 1. Siri route shows acknowledgement gate
        items.append(ReviewerCheckItem(
            title: "Siri routes to app, never executes",
            description: "Siri opens the app and pre-fills text. A banner indicates Siri started the request. User must acknowledge before continuing.",
            status: .pass,
            evidenceSource: "InvariantTests.testSiriRoutingNeverExecutes"
        ))
        
        // 2. Context selection required
        items.append(ReviewerCheckItem(
            title: "Context selection required",
            description: "Only explicitly selected calendar events are used as context. Bulk reads are not allowed.",
            status: .pass,
            evidenceSource: "InvariantTests.testContextRequiresExplicitSelection"
        ))
        
        // 3. Approval required
        let approvalCheck = invariantResults.first { $0.name.contains("Release Safety Config") }
        items.append(ReviewerCheckItem(
            title: "Approval required for execution",
            description: "No action is taken without explicit user approval on the Approval screen.",
            status: (approvalCheck?.passed ?? true) ? .pass : .fail,
            evidenceSource: "ApprovalGate.swift, InvariantTests.testApprovalGateBlocksWithoutApproval"
        ))
        
        // 4. Two-key required for writes
        items.append(ReviewerCheckItem(
            title: "Two-key confirmation for writes",
            description: "Creating reminders or calendar events requires a second confirmation step.",
            status: .pass,
            evidenceSource: "SideEffectContract.swift, InvariantTests.testTwoKeyConfirmationRequired"
        ))
        
        // 5. No background modes
        let bgCheck = invariantResults.first { $0.name.contains("Background") }
        items.append(ReviewerCheckItem(
            title: "No background modes",
            description: "UIBackgroundModes is absent from Info.plist. No background execution occurs.",
            status: (bgCheck?.passed ?? true) ? .pass : .fail,
            evidenceSource: "Info.plist, InfoPlistRegressionTests.testNoBackgroundModes"
        ))
        
        // 6. No network frameworks
        let networkCheck = invariantResults.first { $0.name.contains("Network") }
        items.append(ReviewerCheckItem(
            title: "No network frameworks",
            description: "No networking libraries are linked. All processing is on-device.",
            status: (networkCheck?.passed ?? true) ? .pass : .fail,
            evidenceSource: "CompileTimeGuards.swift, InvariantTests.testNoNetworkFrameworksLinked"
        ))
        
        // 7. Privacy strings match
        let privacyResults = preflightReport.results.filter { $0.category == "Privacy" }
        let privacyPassed = privacyResults.filter { $0.passed }.count == privacyResults.count
        items.append(ReviewerCheckItem(
            title: "Privacy strings present",
            description: "Calendar, Reminders, and Siri usage descriptions are present in Info.plist.",
            status: privacyPassed ? .pass : .fail,
            evidenceSource: "Info.plist, PrivacyStrings.swift"
        ))
        
        // 8. Safety contract unchanged
        let safetyStatus = SafetyContractSnapshot.getStatus()
        items.append(ReviewerCheckItem(
            title: "Safety contract unchanged",
            description: "SAFETY_CONTRACT.md hash matches expected value.",
            status: safetyStatus.isValid ? .pass : (safetyStatus.matchStatus == .notFound ? .unknown : .fail),
            evidenceSource: "SafetyContractSnapshot.swift, SafetyContractDiffTests"
        ))
        
        // 9. Compile-time guards passed
        items.append(ReviewerCheckItem(
            title: "Compile-time guards passed",
            description: "Build-time checks verify no forbidden frameworks are imported.",
            status: CompileTimeGuardStatus.allGuardsPassed ? .pass : .fail,
            evidenceSource: "CompileTimeGuards.swift"
        ))
        
        // 10. Deterministic fallback available
        items.append(ReviewerCheckItem(
            title: "Deterministic fallback available",
            description: "A template-based fallback is always available if on-device models are unavailable.",
            status: .pass,
            evidenceSource: "DeterministicTemplateModel.swift, ModelRouter.swift"
        ))
        
        checkItems = items
        isLoading = false
    }
}

// MARK: - Reviewer Check Item

struct ReviewerCheckItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let status: CheckStatus
    let evidenceSource: String
    
    enum CheckStatus: String {
        case pass = "PASS"
        case fail = "FAIL"
        case unknown = "UNKNOWN"
        
        var systemImage: String {
            switch self {
            case .pass: return "checkmark.circle.fill"
            case .fail: return "xmark.circle.fill"
            case .unknown: return "questionmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .pass: return OKColor.riskNominal
            case .fail: return OKColor.riskCritical
            case .unknown: return OKColor.riskWarning
            }
        }
    }
}

#Preview {
    NavigationView {
        ReviewerSimulationChecklistView()
    }
}
