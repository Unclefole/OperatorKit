import SwiftUI

// ============================================================================
// REGRESSION FIREWALL VIEW (Phase 13A)
//
// Read-only visibility into existing safety tests.
// Shows test list and last verified status.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No new tests added
// ❌ No test execution
// ❌ No write operations
// ✅ Read-only display
// ✅ Feature-flagged
// ============================================================================

public struct RegressionFirewallView: View {
    
    // MARK: - Body
    
    public var body: some View {
        if TrustSurfacesFeatureFlag.Components.regressionFirewallVisibilityEnabled {
            firewallContent
        } else {
            featureDisabledView
        }
    }
    
    // MARK: - Firewall Content
    
    private var firewallContent: some View {
        List {
            headerSection
            protectedModulesSection
            safetyTestsSection
            firewallTestsSection
            copyTestsSection
            sealTestsSection
            statusSection
        }
        .navigationTitle("Regression Firewall")
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.title)
                        .foregroundColor(OKColor.riskWarning)
                    
                    Text("Regression Firewall")
                        .font(.headline)
                }
                
                Text("This view shows existing safety tests. No tests can be run, added, or modified from this screen.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Protected Modules Section
    
    private var protectedModulesSection: some View {
        Section {
            ProtectedModuleRow(
                name: "ExecutionEngine.swift",
                path: "Domain/Execution/",
                status: "Protected"
            )
            
            ProtectedModuleRow(
                name: "ApprovalGate.swift",
                path: "Domain/Approval/",
                status: "Protected"
            )
            
            ProtectedModuleRow(
                name: "ModelRouter.swift",
                path: "Models/",
                status: "Protected"
            )
        } header: {
            Text("Protected Core Modules")
        } footer: {
            Text("These modules cannot be modified by any phase. Changes would break firewall tests.")
        }
    }
    
    // MARK: - Safety Tests Section
    
    private var safetyTestsSection: some View {
        Section {
            TestCategoryRow(category: "SafetyInvariantsTests", testCount: 7)
            TestCategoryRow(category: "ExecutionInvariantsTests", testCount: 5)
            TestCategoryRow(category: "ApprovalInvariantsTests", testCount: 4)
        } header: {
            Text("Category: Safety Invariants")
        }
    }
    
    // MARK: - Firewall Tests Section
    
    private var firewallTestsSection: some View {
        Section {
            TestCategoryRow(category: "ModuleFirewallTests", testCount: 6)
            TestCategoryRow(category: "NetworkFirewallTests", testCount: 4)
            TestCategoryRow(category: "PermissionFirewallTests", testCount: 3)
        } header: {
            Text("Category: Firewall Tests")
        }
    }
    
    // MARK: - Copy Tests Section
    
    private var copyTestsSection: some View {
        Section {
            TestCategoryRow(category: "BannedWordTests", testCount: 5)
            TestCategoryRow(category: "TerminologyCanonTests", testCount: 7)
            TestCategoryRow(category: "InterpretationLockTests", testCount: 10)
        } header: {
            Text("Category: Copy & Language")
        }
    }
    
    // MARK: - Seal Tests Section
    
    private var sealTestsSection: some View {
        Section {
            TestCategoryRow(category: "ReleaseCandidateSealTests", testCount: 12)
            TestCategoryRow(category: "AdversarialReadinessTests", testCount: 8)
            TestCategoryRow(category: "ExternalReviewDryRunTests", testCount: 6)
        } header: {
            Text("Category: Release Seals")
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        Section {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(OKColor.riskNominal)
                
                Text("Last Verified")
                    .font(.subheadline)
                
                Spacer()
                
                Text("Phase 12D")
                    .font(.subheadline)
                    .foregroundColor(OKColor.textSecondary)
            }
            
            HStack {
                Image(systemName: "testtube.2")
                    .foregroundColor(OKColor.actionPrimary)
                
                Text("Test Scope")
                    .font(.subheadline)
                
                Spacer()
                
                Text("Frozen")
                    .font(.subheadline)
                    .foregroundColor(OKColor.textSecondary)
            }
            
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(OKColor.riskExtreme)
                
                Text("New Tests Allowed")
                    .font(.subheadline)
                
                Spacer()
                
                Text("No")
                    .font(.subheadline)
                    .foregroundColor(OKColor.riskCritical)
            }
        } header: {
            Text("Firewall Status")
        } footer: {
            Text("Test scope was frozen in Phase 12D. No new test categories may be added.")
        }
    }
    
    // MARK: - Feature Disabled View
    
    private var featureDisabledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "eye.slash")
                .font(.largeTitle)
                .foregroundColor(OKColor.textSecondary)
            
            Text("Regression Firewall")
                .font(.headline)
            
            Text("This feature is not enabled.")
                .font(.subheadline)
                .foregroundColor(OKColor.textSecondary)
        }
        .padding()
    }
    
    // MARK: - Init
    
    public init() {}
}

// MARK: - Protected Module Row

private struct ProtectedModuleRow: View {
    let name: String
    let path: String
    let status: String
    
    var body: some View {
        HStack {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(OKColor.riskNominal)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(path)
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
            
            Spacer()
            
            Text(status)
                .font(.caption)
                .foregroundColor(OKColor.riskNominal)
        }
    }
}

// MARK: - Test Category Row

private struct TestCategoryRow: View {
    let category: String
    let testCount: Int
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(OKColor.riskNominal)
                .frame(width: 24)
            
            Text(category)
                .font(.subheadline)
            
            Spacer()
            
            Text("\(testCount) tests")
                .font(.caption)
                .foregroundColor(OKColor.textSecondary)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct RegressionFirewallView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RegressionFirewallView()
        }
    }
}
#endif
