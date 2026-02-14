import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import EventKit

// MARK: - Paywall Gate (Inlined)
// Paywall ENABLED for App Store release
private let _privacyPaywallEnabled: Bool = true

/// Displays and manages privacy controls
/// INVARIANT: No auto-requesting permissions - user must tap to request
/// Shows distinct permission states: Not Determined, Denied, Authorized, Restricted, Write-Only
struct PrivacyControlsView: View {
    /// When true, this view is the root of a tab (not pushed via Route).
    /// Back button hides; Home button switches to the Home tab.
    var isTabRoot: Bool = false

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nav: AppNavigationState
    @ObservedObject private var permissionManager = PermissionManager.shared
    @State private var isRequestingPermission: Bool = false
    @State private var showingSettingsAlert: Bool = false
    @State private var isRefreshing: Bool = false
    @State private var showingDataUseDisclosure: Bool = false  // Phase 6A
    @State private var showingReviewerHelp: Bool = false  // Phase 6B
    @State private var showingQualityAndTrust: Bool = false  // Phase 8A
    @State private var showingSubscription: Bool = false  // Phase 10A
    @State private var showingDiagnostics: Bool = false  // Phase 10B
    @State private var showingPolicyEditor: Bool = false  // Phase 10C
    @State private var showingSyncSettings: Bool = false  // Phase 10D
    @State private var showingTeamSettings: Bool = false  // Phase 10E
    @State private var showingHelpCenter: Bool = false  // Phase 10I
    @State private var showingOnboarding: Bool = false  // Phase 10I
    @State private var showingAppStoreReadiness: Bool = false  // Phase 10J
    @State private var showingConversionSummary: Bool = false  // Phase 10L
    @State private var showingTeamSalesKit: Bool = false  // Phase 10M
    @State private var showingCustomerProof: Bool = false  // Phase 10P
    
    #if DEBUG
    // Phase 6B Demo Mode - binds to AppState
    // Eval Harness State
    @StateObject private var evalRunner = EvalRunner()
    @State private var showingEvalResults: Bool = false
    @State private var lastEvalResult: QuickEvalResult?
    @State private var faultInjectionEnabled: Bool = false
    @State private var lastFaultInjectionReport: EvalSuiteReport?
    #endif
    
    var body: some View {
        ZStack {
            // Background - using design system
            OKBackgroundView()

            VStack(spacing: 0) {
                // Header
                headerView
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Privacy Summary
                        privacySummaryCard
                        
                        // Appearance
                        appearanceSection
                        
                        // Last Refresh Info
                        lastRefreshCard
                        
                        // Permission Sections
                        permissionsSection
                        
                        // On-Device Model Section (Phase 4A)
                        onDeviceModelSection
                        
                        // Data Usage Section
                        dataUsageSection
                        
                        // Subscription Section (Phase 10A)
                        subscriptionSection
                        
                        // Diagnostics Section (Phase 10B)
                        diagnosticsSection
                        
                        // Customer Proof Section (Phase 10P)
                        customerProofSection
                        
                        // Policy Section (Phase 10C)
                        policySection
                        
                        // Sync Section (Phase 10D)
                        syncSection
                        
                        // Team Section (Phase 10E)
                        teamSection
                        
                        // Subscription Section (Phase 10G)
                        subscriptionSection
                        
                        // Help & Support Section (Phase 10I)
                        helpSupportSection
                        
                        // Onboarding Section (Phase 10I)
                        onboardingSection
                        
                        // App Store Readiness Section (Phase 10J)
                        #if DEBUG
                        appStoreReadinessSection
                        
                        // Conversion Summary Section (Phase 10L)
                        conversionSummarySection
                        
                        // Enterprise & Team Sales Kit (Phase 10M)
                        teamSalesKitSection
                        #endif
                        
                        // Enterprise Controls (Phase 21)
                        enterpriseSection

                        // Invariant Guarantees
                        guaranteesSection
                        
                        // Reviewer Help (Phase 6B) - Available in all builds
                        VStack(alignment: .leading, spacing: 12) {
                            Text("App Review")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            VStack(spacing: 0) {
                                reviewerHelpLink
                            }
                            .background(OKColor.backgroundPrimary)
                            .cornerRadius(12)
                            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
                        }
                        
                        #if DEBUG
                        // Synthetic Demo Mode (Phase 6B)
                        syntheticDemoSection
                        // Debug Diagnostics
                        debugDiagnosticsSection
                        
                        // Model Evaluation Harness
                        evalHarnessSection
                        #endif
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Refresh on appear (user-initiated by navigating here)
            refreshPermissions()
        }
        .alert("Permission Denied", isPresented: $showingSettingsAlert) {
            Button("Open Settings") {
                permissionManager.openSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permission was previously denied. Please enable it in Settings.")
        }
    }
    
    // MARK: - Header
    // ARCHITECTURE: Context-aware navigation header.
    // When isTabRoot == true  → back button hidden (nothing to pop), home switches tab.
    // When isTabRoot == false → pushed via Route, back pops, home resets path.
    private var headerView: some View {
        HStack {
            if isTabRoot {
                // Tab root: no back destination — use invisible spacer to keep layout balanced
                Color.clear
                    .frame(width: 24, height: 24)
            } else {
                Button(action: { nav.goBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(OKColor.actionPrimary)
                }
            }

            Spacer()

            OperatorKitLogoView(size: .small, showText: false)

            Spacer()

            Button(action: {
                if isTabRoot {
                    nav.goHomeTab()
                } else {
                    nav.goHome()
                }
            }) {
                Image(systemName: "house")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(OKColor.textMuted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(OKColor.backgroundPrimary)
    }
    
    // MARK: - Appearance Section
    
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OKSectionHeader("APPEARANCE")
            
            VStack(spacing: 0) {
                ForEach(AppState.AppearanceMode.allCases) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.appearanceMode = mode
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(appState.appearanceMode == mode ? OKColor.actionPrimary : OKColor.textSecondary)
                                .frame(width: 24)
                            
                            Text(mode.rawValue)
                                .font(OKTypography.body())
                                .foregroundColor(OKColor.textPrimary)
                            
                            Spacer()
                            
                            if appState.appearanceMode == mode {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(OKColor.actionPrimary)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            appState.appearanceMode == mode
                                ? OKColor.actionPrimary.opacity(0.08)
                                : Color.clear
                        )
                    }
                    .buttonStyle(.plain)
                    
                    if mode != AppState.AppearanceMode.allCases.last {
                        Divider()
                            .background(OKColor.borderSubtle)
                            .padding(.leading, 52)
                    }
                }
            }
            .background(OKColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: OKRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: OKRadius.card)
                    .strokeBorder(OKColor.borderSubtle, lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Privacy Summary Card
    private var privacySummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 28))
                    .foregroundColor(OKColor.riskNominal)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Data Stays on Your Device")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("OperatorKit works entirely on-device. Nothing leaves your phone.")
                        .font(.subheadline)
                        .foregroundColor(OKColor.textMuted)
                }
            }
            
            Divider()
            
            // Quick status badges
            HStack(spacing: 20) {
                authStateBadge(
                    title: "Calendar",
                    state: permissionManager.calendarState,
                    icon: "calendar"
                )
                
                authStateBadge(
                    title: "Reminders",
                    state: permissionManager.remindersState,
                    icon: "bell"
                )
                
                authStateBadge(
                    title: "Mail",
                    state: permissionManager.canSendMail ? .authorized : .denied,
                    icon: "envelope"
                )
            }
        }
        .padding(20)
        .background(OKColor.backgroundPrimary)
        .cornerRadius(16)
        .shadow(color: OKColor.shadow.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    private func authStateBadge(title: String, state: AuthorizationState, icon: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color(state.color).opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(state.color))
            }
            
            Text(title)
                .font(.caption2)
                .foregroundColor(OKColor.textMuted)
            
            Text(stateShortLabel(state))
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(Color(state.color))
        }
    }
    
    private func stateShortLabel(_ state: AuthorizationState) -> String {
        switch state {
        case .authorized: return "Active"
        case .notDetermined: return "Ask"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .writeOnly: return "Write"
        case .unknown: return "?"
        }
    }
    
    // MARK: - Last Refresh Card
    private var lastRefreshCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 16))
                .foregroundColor(OKColor.textMuted)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Last Refreshed")
                    .font(.caption)
                    .foregroundColor(OKColor.textMuted)
                
                Text(formattedRefreshTime)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            Button(action: refreshPermissions) {
                Text("Refresh Now")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(OKColor.actionPrimary)
            }
            .disabled(isRefreshing)
        }
        .padding(12)
        .background(OKColor.backgroundPrimary)
        .cornerRadius(10)
        .shadow(color: OKColor.shadow.opacity(0.02), radius: 4, x: 0, y: 2)
    }
    
    private var formattedRefreshTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: permissionManager.lastRefresh)
    }
    
    // MARK: - Permissions Section
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Permissions")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 0) {
                // Calendar
                permissionRowNew(
                    icon: "calendar",
                    iconColor: OKColor.riskCritical,
                    title: "Calendar",
                    subtitle: calendarSubtitle,
                    state: permissionManager.calendarState,
                    onRequest: { requestCalendar() },
                    isLoading: isRequestingPermission
                )
                
                Divider().padding(.leading, 56)
                
                // Reminders
                permissionRowNew(
                    icon: "bell.fill",
                    iconColor: OKColor.riskWarning,
                    title: "Reminders",
                    subtitle: remindersSubtitle,
                    state: permissionManager.remindersState,
                    onRequest: { requestReminders() },
                    isLoading: isRequestingPermission
                )
                
                Divider().padding(.leading, 56)
                
                // Mail
                permissionRowNew(
                    icon: "envelope.fill",
                    iconColor: OKColor.actionPrimary,
                    title: "Mail",
                    subtitle: "Open email composer with drafts",
                    state: permissionManager.canSendMail ? .authorized : .denied,
                    onRequest: nil,
                    isLoading: false,
                    isMailPermission: true
                )
            }
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
            
            // Data access helper text
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(OKColor.actionPrimary)
                Text("OperatorKit only accesses data when you explicitly select it.")
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
            .padding(.horizontal, 4)
        }
    }
    
    private var calendarSubtitle: String {
        switch permissionManager.calendarState {
        case .authorized:
            return "Calendar access is on. OperatorKit only accesses data when you explicitly select it."
        case .writeOnly:
            return "Calendar write access is on. OperatorKit can create events you approve."
        case .denied:
            return "Calendar access is currently off. Open Settings to allow access."
        case .restricted:
            return "Calendar access is managed by your organization."
        case .notDetermined:
            return "Allow access to view or create calendar events."
        case .unknown:
            return "Unable to check calendar status."
        }
    }
    
    private var remindersSubtitle: String {
        switch permissionManager.remindersState {
        case .authorized:
            return "Reminders access is on. OperatorKit only accesses data when you explicitly select it."
        case .writeOnly:
            return "Reminders write access is on. OperatorKit can create reminders you approve."
        case .denied:
            return "Reminders access is currently off. Open Settings to allow access."
        case .restricted:
            return "Reminders access is managed by your organization."
        case .notDetermined:
            return "Allow access to preview or create reminders."
        case .unknown:
            return "Unable to check reminders status."
        }
    }
    
    private func permissionRowNew(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        state: AuthorizationState,
        onRequest: (() -> Void)?,
        isLoading: Bool,
        isMailPermission: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(OKColor.textMuted)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Status and action
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                authStateButton(
                    state: state,
                    onRequest: onRequest,
                    isMailPermission: isMailPermission
                )
            }
        }
        .padding(16)
    }
    
    @ViewBuilder
    private func authStateButton(
        state: AuthorizationState,
        onRequest: (() -> Void)?,
        isMailPermission: Bool
    ) -> some View {
        switch state {
        case .authorized:
            // Green checkmark
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                Text("Granted")
                    .font(.caption)
            }
            .foregroundColor(OKColor.riskNominal)
            
        case .writeOnly:
            // Blue pencil
            HStack(spacing: 4) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 14))
                Text("Write Only")
                    .font(.caption)
            }
            .foregroundColor(OKColor.actionPrimary)
            
        case .denied:
            // Red X with Open Settings action
            Button(action: {
                if isMailPermission {
                    // Open mail settings specifically
                    if let url = URL(string: "message://") {
                        UIApplication.shared.open(url)
                    } else {
                        permissionManager.openSettings()
                    }
                } else {
                    showingSettingsAlert = true
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                    Text("Open Settings")
                        .font(.caption)
                }
                .foregroundColor(OKColor.riskCritical)
            }
            
        case .restricted:
            // Orange lock
            HStack(spacing: 4) {
                Image(systemName: "lock.circle.fill")
                    .font(.system(size: 14))
                Text("Restricted")
                    .font(.caption)
            }
            .foregroundColor(OKColor.riskWarning)
            
        case .notDetermined:
            // Blue Allow access button
            if let onRequest = onRequest {
                Button(action: onRequest) {
                    Text("Allow access")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(OKColor.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(OKColor.actionPrimary)
                        .cornerRadius(16)
                }
            } else {
                Text("Not enabled")
                    .font(.caption)
                    .foregroundColor(OKColor.textMuted)
            }
            
        case .unknown:
            // Gray question mark
            HStack(spacing: 4) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 14))
                Text("Unknown")
                    .font(.caption)
            }
            .foregroundColor(OKColor.textMuted)
        }
    }
    
    // MARK: - Data Usage Section
    private var dataUsageSection: some View {
        let guarantees = DataGuarantees.current

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Data Guarantees")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                // All-safe badge
                if guarantees.allSafe {
                    Text("ALL SAFE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(OKColor.riskNominal)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(OKColor.riskNominal.opacity(0.1))
                        .cornerRadius(6)
                }
            }

            VStack(spacing: 0) {
                dataRow(
                    icon: guarantees.cloudUpload ? "icloud.fill" : "icloud.slash",
                    iconColor: guarantees.cloudUpload ? OKColor.riskWarning : OKColor.riskExtreme,
                    title: guarantees.cloudUpload ? "Cloud Upload Active" : "No Cloud Upload",
                    subtitle: guarantees.cloudUpload
                        ? "Metadata-only packets via Sync module"
                        : "All processing happens on your device"
                )

                Divider().padding(.leading, 56)

                dataRow(
                    icon: guarantees.tracking ? "eye" : "eye.slash",
                    iconColor: guarantees.tracking ? OKColor.riskCritical : OKColor.actionPrimary,
                    title: guarantees.tracking ? "Tracking Active" : "No Tracking",
                    subtitle: guarantees.tracking
                        ? "Analytics or telemetry detected"
                        : "No analytics, telemetry, or user tracking"
                )

                Divider().padding(.leading, 56)

                dataRow(
                    icon: guarantees.encryptedStorage ? "lock.shield" : "lock.open",
                    iconColor: guarantees.encryptedStorage ? OKColor.riskNominal : OKColor.riskCritical,
                    title: guarantees.encryptedStorage ? "Encrypted Storage" : "Storage Not Encrypted",
                    subtitle: guarantees.encryptedStorage
                        ? "iOS Data Protection encrypts app sandbox"
                        : "WARNING: Storage encryption unavailable"
                )
                
                Divider().padding(.leading, 56)
                
                // Full Data Use Disclosure link (Phase 6A)
                Button(action: {
                    showingDataUseDisclosure = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 18))
                            .foregroundColor(OKColor.actionPrimary)
                            .frame(width: 44, height: 44)
                            .background(OKColor.actionPrimary.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Full Data Use Disclosure")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(OKColor.textPrimary)
                            
                            Text("Detailed explanation of how your data is used")
                                .font(.caption)
                                .foregroundColor(OKColor.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(OKColor.textMuted)
                    }
                    .padding(12)
                }
                
                Divider().padding(.leading, 56)
                
                // Quality & Trust link (Phase 8A)
                Button(action: {
                    showingQualityAndTrust = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "star.bubble")
                            .font(.system(size: 18))
                            .foregroundColor(OKColor.riskExtreme)
                            .frame(width: 44, height: 44)
                            .background(OKColor.riskExtreme.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quality & Trust")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(OKColor.textPrimary)
                            
                            Text("View your local feedback and calibration data")
                                .font(.caption)
                                .foregroundColor(OKColor.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(OKColor.textMuted)
                    }
                    .padding(12)
                }
            }
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .sheet(isPresented: $showingDataUseDisclosure) {
            DataUseDisclosureView()
        }
        .sheet(isPresented: $showingQualityAndTrust) {
            QualityAndTrustView()
        }
        .sheet(isPresented: $showingReviewerHelp) {
            ReviewerHelpView()
        }
    }
    
    // MARK: - Reviewer Help Link (Phase 6B)
    private var reviewerHelpLink: some View {
        Button(action: {
            showingReviewerHelp = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "person.badge.shield.checkmark")
                    .font(.system(size: 18))
                    .foregroundColor(OKColor.riskExtreme)
                    .frame(width: 44, height: 44)
                    .background(OKColor.riskExtreme.opacity(0.1))
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reviewer Help")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(OKColor.textPrimary)
                    
                    Text("Test plan and guarantees overview")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(OKColor.textMuted)
            }
            .padding(12)
        }
    }
    
    private func dataRow(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(OKColor.textMuted)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(OKColor.riskNominal)
        }
        .padding(16)
    }
    
    // MARK: - On-Device Trust Center (Phase 4A + Governance)
    private var onDeviceModelSection: some View {
        let modelRouter = ModelRouter.shared
        let appleAvailability = modelRouter.appleOnDeviceAvailability
        let mode = IntelligenceMode.current

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: mode.icon)
                    .font(.system(size: 20))
                    .foregroundColor(mode.tintColor)

                Text("On-Device Trust Center")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                // Intelligence mode badge
                Text(mode.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(mode.tintColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(mode.tintColor.opacity(0.1))
                    .cornerRadius(6)
            }
            
            VStack(spacing: 0) {
                // Current backend
                modelBackendRow()
                
                Divider().padding(.leading, 56)
                
                // Apple On-Device status
                appleOnDeviceStatusRow(isAvailable: appleAvailability.isAvailable)
                
                Divider().padding(.leading, 56)
                
                // Network status — bound to real AppSecurityConfig state
                dataRow(
                    icon: GovernanceSettingsStore.shared.networkStatusIcon,
                    iconColor: GovernanceSettingsStore.shared.networkStatusColor,
                    title: GovernanceSettingsStore.shared.networkStatusText,
                    subtitle: AppSecurityConfig.networkAccessAllowed
                        ? "Sync module only — metadata packets"
                        : "All AI runs locally on your device"
                )
            }
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
    
    private func modelBackendRow() -> some View {
        let modelRouter = ModelRouter.shared
        let currentBackend = modelRouter.currentBackend
        
        return HStack(spacing: 12) {
            Image(systemName: modelBackendIcon(currentBackend))
                .font(.system(size: 20))
                .foregroundColor(OKColor.riskExtreme)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Active Model")
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(currentBackend.displayName)
                    .font(.caption)
                    .foregroundColor(OKColor.textMuted)
            }
            
            Spacer()
            
            // Backend status badge
            HStack(spacing: 4) {
                Circle()
                    .fill(OKColor.riskNominal)
                    .frame(width: 8, height: 8)
                Text("On-Device")
                    .font(.caption2)
                    .foregroundColor(OKColor.textMuted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(OKColor.riskNominal.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(16)
    }
    
    private func appleOnDeviceStatusRow(isAvailable: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "apple.logo")
                .font(.system(size: 20))
                .foregroundColor(isAvailable ? OKColor.riskNominal : OKColor.textMuted)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple On-Device")
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(isAvailable ? "Available (iOS 18.1+ with Apple Intelligence)" : "Not available on this device/OS")
                    .font(.caption)
                    .foregroundColor(OKColor.textMuted)
            }
            
            Spacer()
            
            // Availability badge
            HStack(spacing: 4) {
                Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 12))
                Text(isAvailable ? "Available" : "Unavailable")
                    .font(.caption2)
            }
            .foregroundColor(isAvailable ? OKColor.riskNominal : OKColor.textMuted)
        }
        .padding(16)
    }
    
    private func modelBackendIcon(_ backend: ModelBackend) -> String {
        switch backend {
        case .appleOnDevice:
            return "apple.logo"
        case .coreML:
            return "brain"
        case .structuredOnDevice:
            return "doc.text.magnifyingglass"
        case .deterministic:
            return "text.badge.checkmark"
        }
    }
    
    // MARK: - Subscription Section (Phase 10A)
    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "creditcard")
                    .font(.system(size: 20))
                    .foregroundColor(OKColor.actionPrimary)
                
                Text("Subscription")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 0) {
                // Current tier row
                HStack(spacing: 12) {
                    Image(systemName: appState.isPro ? "star.fill" : "person.fill")
                        .font(.system(size: 20))
                        .foregroundColor(appState.isPro ? OKColor.actionPrimary : OKColor.textMuted)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current Plan")
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Text(appState.currentTier.displayName)
                            .font(.caption)
                            .foregroundColor(OKColor.textMuted)
                    }
                    
                    Spacer()
                    
                    SubscriptionTierBadge(tier: appState.currentTier)
                }
                .padding(16)
                
                Divider().padding(.leading, 56)
                
                // Manage subscription link
                Button(action: {
                    showingSubscription = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "gear")
                            .font(.system(size: 18))
                            .foregroundColor(OKColor.actionPrimary)
                            .frame(width: 44, height: 44)
                            .background(OKColor.actionPrimary.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.isPro ? "Manage Subscription" : "Upgrade to Pro")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(OKColor.textPrimary)
                            
                            Text(appState.isPro ? "View plan details and renewal date" : "Remove limits and get more done")
                                .font(.caption)
                                .foregroundColor(OKColor.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(OKColor.textMuted)
                    }
                    .padding(12)
                }
            }
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .sheet(isPresented: $showingSubscription) {
            if appState.isPro {
                NavigationView {
                    SubscriptionStatusView()
                        .environmentObject(appState)
                }
            } else if _privacyPaywallEnabled {
                UpgradeView()
                    .environmentObject(appState)
            } else {
                // Fallback: Never show blank screen
                NavigationView {
                    VStack(spacing: 24) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 48))
                            .foregroundColor(OKColor.actionPrimary)

                        Text("Pro Coming Soon")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Pro features will be available in a future update.")
                            .font(.body)
                            .foregroundColor(OKColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Button("Done") {
                            showingSubscription = false
                        }
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(OKColor.actionPrimary)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(OKColor.backgroundPrimary)
                    .navigationTitle("OperatorKit Pro")
                    .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
                }
            }
        }
    }
    
    // MARK: - Enterprise Section (Phase 21)
    private var enterpriseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ENTERPRISE")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(OKColor.textMuted)

            VStack(spacing: 0) {
                NavigationLink(value: Route.skillsDashboard) {
                    enterpriseRow(icon: "brain.head.profile", title: "Micro-Operators", detail: "\(SkillRegistry.shared.registeredSkills.count) skills")
                }
                Divider().background(OKColor.borderSubtle)

                NavigationLink(value: Route.scoutDashboard) {
                    enterpriseRow(icon: "binoculars.fill", title: "Scout Mode", detail: EnterpriseFeatureFlags.scoutModeEnabled ? "Active" : "Off")
                }
                Divider().background(OKColor.borderSubtle)

                NavigationLink(value: Route.enterpriseOnboarding) {
                    enterpriseRow(icon: "building.2", title: "Onboarding Wizard", detail: OrgProvisioningService.shared.isProvisioned ? "Provisioned" : "Not configured")
                }
                Divider().background(OKColor.borderSubtle)

                NavigationLink(value: Route.trustRegistry) {
                    enterpriseRow(icon: "shield.checkered", title: "Trust Registry", detail: "\(TrustedDeviceRegistry.shared.devices.count) device(s)")
                }
                Divider().background(OKColor.borderSubtle)

                NavigationLink(value: Route.integrityIncident) {
                    enterpriseRow(icon: "exclamationmark.shield", title: "System Integrity", detail: KernelIntegrityGuard.shared.systemPosture.rawValue.uppercased())
                }
                Divider().background(OKColor.borderSubtle)

                NavigationLink(value: Route.securityDashboard) {
                    enterpriseRow(icon: "lock.shield", title: "Security Dashboard", detail: DeviceAttestationService.shared.isSupported ? "Attest: \(DeviceAttestationService.shared.state.rawValue)" : "Attest: N/A")
                }
                Divider().background(OKColor.borderSubtle)

                NavigationLink(value: Route.auditStatus) {
                    enterpriseRow(icon: "doc.badge.clock", title: "Audit Status", detail: EvidenceMirrorClient.shared.syncStatus.rawValue)
                }
                Divider().background(OKColor.borderSubtle)

                NavigationLink(value: Route.killSwitches) {
                    enterpriseRow(icon: "bolt.shield", title: "Kill Switches", detail: EnterpriseFeatureFlags.executionKillSwitch ? "ACTIVE" : "Nominal")
                }
                Divider().background(OKColor.borderSubtle)

                NavigationLink(value: Route.intelligenceSettings) {
                    enterpriseRow(icon: "brain", title: "Intelligence", detail: IntelligenceFeatureFlags.cloudModelsEnabled ? "Cloud ON" : "On-Device Only")
                }
                Divider().background(OKColor.borderSubtle)

                NavigationLink(value: Route.pilotRunner) {
                    enterpriseRow(icon: "play.circle", title: "Pilot Runner", detail: PilotRunner.shared.allPassed ? "Passed" : "Not run")
                }
                Divider().background(OKColor.borderSubtle)

                NavigationLink(value: Route.reviewPack) {
                    enterpriseRow(icon: "doc.text.magnifyingglass", title: "Export Review Pack", detail: EnterpriseReviewPackBuilder.shared.lastExportAt != nil ? "Exported" : "Not exported")
                }
            }
            .background(OKColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(OKColor.borderSubtle, lineWidth: 1))
        }
    }

    private func enterpriseRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(OKColor.actionPrimary)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(OKColor.textPrimary)
            Spacer()
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(OKColor.textMuted)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(OKColor.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Diagnostics Section (Phase 10B)
    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 20))
                    .foregroundColor(OKColor.riskExtreme)
                
                Text("Diagnostics")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 0) {
                Button(action: {
                    showingDiagnostics = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 18))
                            .foregroundColor(OKColor.riskExtreme)
                            .frame(width: 44, height: 44)
                            .background(OKColor.riskExtreme.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("View Diagnostics")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(OKColor.textPrimary)
                            
                            Text("Execution stats, limits, and system status")
                                .font(.caption)
                                .foregroundColor(OKColor.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(OKColor.textMuted)
                    }
                    .padding(12)
                }
            }
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .sheet(isPresented: $showingDiagnostics) {
            DiagnosticsView()
                .environmentObject(appState)
        }
    }
    
    // MARK: - Customer Proof Section (Phase 10P)
    private var customerProofSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 20))
                    .foregroundColor(OKColor.riskOperational)
                
                Text("Proof & Trust")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 0) {
                Button(action: {
                    showingCustomerProof = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.badge.checkmark")
                            .font(.system(size: 18))
                            .foregroundColor(OKColor.riskOperational)
                            .frame(width: 44, height: 44)
                            .background(OKColor.riskOperational.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Customer Proof Dashboard")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(OKColor.textPrimary)
                            
                            Text("Safety verification, audit trail, exports")
                                .font(.caption)
                                .foregroundColor(OKColor.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(OKColor.textMuted)
                    }
                    .padding(12)
                }
            }
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .sheet(isPresented: $showingCustomerProof) {
            CustomerProofView()
        }
    }
    
    // MARK: - Execution Policy Engine (Phase 10C + Governance)
    private var policySection: some View {
        let governance = GovernanceSettingsStore.shared

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 20))
                    .foregroundColor(OKColor.riskExtreme)

                Text("Execution Policy Engine")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                // Institutional status — never "All Allowed"
                Text(governance.policyStatusText)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(OKColor.riskExtreme)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(OKColor.riskExtreme.opacity(0.1))
                    .cornerRadius(6)
            }

            VStack(spacing: 0) {
                // Current policy status
                HStack(spacing: 12) {
                    Image(systemName: "hand.raised")
                        .font(.system(size: 20))
                        .foregroundColor(OKColor.riskExtreme)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current Policy")
                            .font(.body)
                            .fontWeight(.medium)

                        Text(OperatorPolicyStore.shared.policySummary())
                            .font(.caption)
                            .foregroundColor(OKColor.textMuted)
                            .lineLimit(2)
                    }

                    Spacer()

                    PolicyStatusBadge(policy: OperatorPolicyStore.shared.currentPolicy)
                }
                .padding(16)

                Divider().padding(.leading, 56)

                // Execution Tiers
                ForEach(governance.executionTierSummary, id: \.tier) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.tier.icon)
                            .font(.system(size: 18))
                            .foregroundColor(item.tier.tintColor)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.tier.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text(item.tier.subtitle)
                                .font(.caption)
                                .foregroundColor(OKColor.textMuted)
                        }

                        Spacer()

                        if item.locked {
                            // Tier 2 — HARD LOCKED indicator
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10))
                                Text("LOCKED")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(OKColor.riskCritical)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(OKColor.riskCritical.opacity(0.1))
                            .cornerRadius(6)
                        } else {
                            Text(item.autoApprove ? "Auto" : "Manual")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(item.autoApprove ? OKColor.riskWarning : OKColor.riskNominal)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background((item.autoApprove ? OKColor.riskWarning : OKColor.riskNominal).opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if item.tier != .irreversible {
                        Divider().padding(.leading, 56)
                    }
                }

                Divider().padding(.leading, 56)

                // Edit policy link
                Button(action: {
                    showingPolicyEditor = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18))
                            .foregroundColor(OKColor.riskExtreme)
                            .frame(width: 44, height: 44)
                            .background(OKColor.riskExtreme.opacity(0.1))
                            .cornerRadius(10)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Edit Policy")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(OKColor.textPrimary)

                            Text("Configure capabilities and execution tiers")
                                .font(.caption)
                                .foregroundColor(OKColor.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(OKColor.textMuted)
                    }
                    .padding(12)
                }
            }
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .sheet(isPresented: $showingPolicyEditor) {
            PolicyEditorView()
        }
    }
    
    // MARK: - Sync Section (Phase 10D)
    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "icloud")
                    .font(.system(size: 20))
                    .foregroundColor(OKColor.riskOperational)
                
                Text("Cloud Sync (Optional)")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 0) {
                // Sync status
                HStack(spacing: 12) {
                    Image(systemName: syncEnabled ? "icloud.fill" : "icloud.slash")
                        .font(.system(size: 20))
                        .foregroundColor(syncEnabled ? OKColor.riskOperational : OKColor.textMuted)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(syncEnabled ? "Sync Enabled" : "Sync Disabled")
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Text(syncEnabled ? "Metadata-only packets can be uploaded" : "All data stays on your device")
                            .font(.caption)
                            .foregroundColor(OKColor.textMuted)
                    }
                    
                    Spacer()
                    
                    Text(syncEnabled ? "ON" : "OFF")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(syncEnabled ? OKColor.riskOperational : OKColor.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((syncEnabled ? OKColor.riskOperational : OKColor.textMuted).opacity(0.1))
                        .cornerRadius(6)
                }
                .padding(16)
                
                Divider().padding(.leading, 56)
                
                // Settings link
                Button(action: {
                    showingSyncSettings = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))
                            .foregroundColor(OKColor.riskOperational)
                            .frame(width: 44, height: 44)
                            .background(OKColor.riskOperational.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sync Settings")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(OKColor.textPrimary)
                            
                            Text("Sign in, view staged packets, upload")
                                .font(.caption)
                                .foregroundColor(OKColor.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(OKColor.textMuted)
                    }
                    .padding(12)
                }
            }
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .sheet(isPresented: $showingSyncSettings) {
            SyncSettingsView()
        }
    }
    
    /// Sync enabled state (Phase 10D)
    private var syncEnabled: Bool {
        UserDefaults.standard.bool(forKey: SyncFeatureFlag.storageKey)
    }
    
    // MARK: - Team Section (Phase 10E)
    private var teamSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3")
                    .font(.system(size: 20))
                    .foregroundColor(OKColor.riskWarning)
                
                Text("Team")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 0) {
                // Team status
                HStack(spacing: 12) {
                    Image(systemName: TeamStore.shared.hasTeam ? "person.3.fill" : "person.3")
                        .font(.system(size: 20))
                        .foregroundColor(TeamStore.shared.hasTeam ? OKColor.riskWarning : OKColor.textMuted)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if let team = TeamStore.shared.currentTeam {
                            Text(team.name)
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Role: \(team.memberRole.displayName)")
                                .font(.caption)
                                .foregroundColor(OKColor.textMuted)
                        } else {
                            Text("No Team")
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Share governance artifacts with your team")
                                .font(.caption)
                                .foregroundColor(OKColor.textMuted)
                        }
                    }
                    
                    Spacer()
                    
                    if EntitlementManager.shared.hasTeamFeatures {
                        Text("Team Tier")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(OKColor.riskWarning)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(OKColor.riskWarning.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
                .padding(16)
                
                Divider().padding(.leading, 56)
                
                // Team settings link
                Button(action: {
                    showingTeamSettings = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape.2")
                            .font(.system(size: 18))
                            .foregroundColor(OKColor.riskWarning)
                            .frame(width: 44, height: 44)
                            .background(OKColor.riskWarning.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Team Settings")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(OKColor.textPrimary)
                            
                            Text("Manage team, members, and shared artifacts")
                                .font(.caption)
                                .foregroundColor(OKColor.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(OKColor.textMuted)
                    }
                    .padding(12)
                }
            }
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .sheet(isPresented: $showingTeamSettings) {
            TeamSettingsView()
        }
    }
    
    // MARK: - Extended Subscription Section (Phase 10G)
    @State private var showingSubscriptionStatus: Bool = false
    
    private var extendedSubscriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "creditcard")
                    .font(.system(size: 20))
                    .foregroundColor(OKColor.actionPrimary)
                
                Text("Subscription")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 0) {
                // Current tier
                HStack(spacing: 12) {
                    Image(systemName: currentTierIcon)
                        .font(.system(size: 20))
                        .foregroundColor(currentTierColor)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(EntitlementManager.shared.currentTier.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                        Text(currentTierDescription)
                            .font(.caption)
                            .foregroundColor(OKColor.textMuted)
                    }
                    
                    Spacer()
                }
                .padding(16)
                
                Divider().padding(.leading, 56)
                
                // Manage subscription link
                Button(action: {
                    showingSubscriptionStatus = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))
                            .foregroundColor(OKColor.actionPrimary)
                            .frame(width: 44, height: 44)
                            .background(OKColor.actionPrimary.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Manage Subscription")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(OKColor.textPrimary)
                            
                            Text("View plans, usage, and billing")
                                .font(.caption)
                                .foregroundColor(OKColor.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(OKColor.textMuted)
                    }
                    .padding(12)
                }
            }
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .sheet(isPresented: $showingSubscriptionStatus) {
            NavigationView {
                SubscriptionStatusView()
            }
        }
    }
    
    private var currentTierIcon: String {
        switch EntitlementManager.shared.currentTier {
        case .free: return "person.circle"
        case .pro: return "star.circle.fill"
        case .team: return "person.3.fill"
        }
    }
    
    private var currentTierColor: Color {
        switch EntitlementManager.shared.currentTier {
        case .free: return OKColor.textMuted
        case .pro: return OKColor.actionPrimary
        case .team: return OKColor.riskWarning
        }
    }
    
    private var currentTierDescription: String {
        switch EntitlementManager.shared.currentTier {
        case .free: return "Limited drafted outcomes and memory"
        case .pro: return "Unlimited usage"
        case .team: return "Team governance and sharing"
        }
    }
    
    // MARK: - Help & Support Section (Phase 10I)
    
    private var helpSupportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 20))
                    .foregroundColor(OKColor.actionPrimary)
                
                Text("Help & Support")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 0) {
                Button {
                    showingHelpCenter = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 18))
                            .foregroundColor(OKColor.actionPrimary)
                            .frame(width: 44, height: 44)
                            .background(OKColor.actionPrimary.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Help Center")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(OKColor.textPrimary)
                            
                            Text("FAQ, troubleshooting, contact support")
                                .font(.caption)
                                .foregroundColor(OKColor.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(OKColor.textMuted)
                    }
                    .padding(12)
                }
            }
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .sheet(isPresented: $showingHelpCenter) {
            HelpCenterView()
        }
    }
    
    // MARK: - Onboarding Section (Phase 10I)
    
    private var onboardingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "graduationcap")
                    .font(.system(size: 20))
                    .foregroundColor(OKColor.riskExtreme)
                
                Text("Getting Started")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 0) {
                Button {
                    OnboardingStateStore.shared.markForRerun()
                    showingOnboarding = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "play.circle")
                            .font(.system(size: 18))
                            .foregroundColor(OKColor.riskExtreme)
                            .frame(width: 44, height: 44)
                            .background(OKColor.riskExtreme.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Re-run Onboarding")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(OKColor.textPrimary)
                            
                            Text("Review safety model and features")
                                .font(.caption)
                                .foregroundColor(OKColor.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(OKColor.textMuted)
                    }
                    .padding(12)
                }
            }
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView(onComplete: {
                showingOnboarding = false
            })
        }
    }
    
    // MARK: - App Store Readiness Section (Phase 10J)
    
    #if DEBUG
    private var appStoreReadinessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "app.badge.checkmark")
                    .font(.system(size: 20))
                    .foregroundColor(OKColor.riskWarning)
                
                Text("App Store Readiness")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 0) {
                Button {
                    showingAppStoreReadiness = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "checklist")
                            .font(.system(size: 18))
                            .foregroundColor(OKColor.riskWarning)
                            .frame(width: 44, height: 44)
                            .background(OKColor.riskWarning.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Submission Readiness")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(OKColor.textPrimary)
                            
                            Text("Review notes, screenshots, exports")
                                .font(.caption)
                                .foregroundColor(OKColor.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(OKColor.textMuted)
                    }
                    .padding(12)
                }
            }
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .sheet(isPresented: $showingAppStoreReadiness) {
            AppStoreReadinessView()
        }
    }
    
    // MARK: - Conversion Summary Section (Phase 10L)
    
    private var conversionSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 20))
                    .foregroundColor(OKColor.riskExtreme)
                
                Text("Conversion Analytics")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 0) {
                Button {
                    showingConversionSummary = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "chart.pie")
                            .font(.system(size: 18))
                            .foregroundColor(OKColor.riskExtreme)
                            .frame(width: 44, height: 44)
                            .background(OKColor.riskExtreme.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Conversion Summary")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(OKColor.textPrimary)
                            
                            Text("Funnel counts and rates (local-only)")
                                .font(.caption)
                                .foregroundColor(OKColor.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(OKColor.textMuted)
                    }
                    .padding(12)
                }
            }
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .sheet(isPresented: $showingConversionSummary) {
            ConversionSummaryView()
        }
    }
    
    // MARK: - Team Sales Kit Section (Phase 10M)
    
    private var teamSalesKitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "building.2")
                    .font(.system(size: 20))
                    .foregroundColor(OKColor.actionPrimary)
                
                Text("Enterprise & Team")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 0) {
                Button {
                    showingTeamSalesKit = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.3")
                            .font(.system(size: 18))
                            .foregroundColor(OKColor.actionPrimary)
                            .frame(width: 44, height: 44)
                            .background(OKColor.actionPrimary.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Team Sales Kit")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(OKColor.textPrimary)
                            
                            Text("Procurement, trials, and rollout")
                                .font(.caption)
                                .foregroundColor(OKColor.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(OKColor.textMuted)
                    }
                    .padding(12)
                }
            }
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .sheet(isPresented: $showingTeamSalesKit) {
            TeamSalesKitView()
        }
    }
    #endif
    
    // MARK: - Safety Invariants Section (Runtime-Verified)
    private var guaranteesSection: some View {
        let invariants = SafetyInvariant.all
        let hasViolation = invariants.contains { !$0.isGuaranteed }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: hasViolation ? "exclamationmark.shield" : "shield.checkered")
                    .font(.system(size: 20))
                    .foregroundColor(hasViolation ? OKColor.riskCritical : OKColor.riskNominal)

                Text("Safety Invariants")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                // Runtime verification badge
                Text(hasViolation ? "VIOLATION" : "ALL VERIFIED")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(hasViolation ? OKColor.riskCritical : OKColor.riskNominal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((hasViolation ? OKColor.riskCritical : OKColor.riskNominal).opacity(0.1))
                    .cornerRadius(6)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(invariants) { invariant in
                    guaranteeRow(invariant.description, verified: invariant.isGuaranteed)
                }
            }
            .padding(16)
            .background((hasViolation ? OKColor.riskCritical : OKColor.riskNominal).opacity(0.05))
            .cornerRadius(12)
        }
    }

    private func guaranteeRow(_ text: String, verified: Bool = true) -> some View {
        HStack(spacing: 10) {
            Image(systemName: verified ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(verified ? OKColor.riskNominal : OKColor.riskCritical)

            Text(text)
                .font(.subheadline)
                .foregroundColor(OKColor.textPrimary)

            Spacer()

            Text(verified ? "Verified" : "Failed")
                .font(.caption2)
                .foregroundColor(verified ? OKColor.riskNominal : OKColor.riskCritical)
        }
    }
    
    // MARK: - Synthetic Demo Section (Phase 6B)
    #if DEBUG
    private var syntheticDemoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Demo Mode")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("DEBUG")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(OKColor.textPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(OKColor.riskWarning)
                    .cornerRadius(4)
            }
            
            VStack(spacing: 0) {
                // Toggle for synthetic data
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Use Synthetic Demo Data")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Show synthetic calendar/reminder items for testing")
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $appState.useSyntheticDemoData)
                        .labelsHidden()
                }
                .padding(12)
                
                if appState.useSyntheticDemoData {
                    Divider()
                    
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(OKColor.riskWarning)
                        
                        Text("Synthetic data active. Context Picker will show demo items. No real EventKit access in demo mode.")
                            .font(.caption)
                            .foregroundColor(OKColor.riskWarning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(OKColor.riskWarning.opacity(0.1))
                }
            }
            .background(OKColor.backgroundPrimary)
            .cornerRadius(12)
            .shadow(color: OKColor.shadow.opacity(0.04), radius: 6, x: 0, y: 2)
            
            Text("Demo mode uses synthetic data for QA and TestFlight testing. It does not access real user data and audit trails are marked as synthetic.")
                .font(.caption)
                .foregroundColor(OKColor.textSecondary)
        }
    }
    #endif
    
    // MARK: - Debug Diagnostics Section
    #if DEBUG
    private var debugDiagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Permission Diagnostics
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "ant.fill")
                        .font(.system(size: 16))
                        .foregroundColor(OKColor.riskExtreme)
                    
                    Text("DEBUG: Permission Diagnostics")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    let diagnostics = permissionManager.diagnosticInfo()
                    
                    ForEach(Array(diagnostics.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text(key)
                                .font(.caption)
                                .foregroundColor(OKColor.textMuted)
                                .frame(width: 120, alignment: .leading)
                            
                            if let value = diagnostics[key] {
                                Text(String(describing: value))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    Divider()
                    
                    // Confirmation of invariants
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(OKColor.riskNominal)
                        Text("No prompts without user tap")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .padding(16)
                .background(OKColor.riskExtreme.opacity(0.05))
                .cornerRadius(12)
            }
            
            // Model Diagnostics (Phase 4A)
            modelDiagnosticsSection
        }
    }
    
    private var modelDiagnosticsSection: some View {
        let modelRouter = ModelRouter.shared
        let appleAvailability = modelRouter.appleOnDeviceAvailability
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain")
                    .font(.system(size: 16))
                    .foregroundColor(OKColor.riskExtreme)
                
                Text("DEBUG: Model Diagnostics")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Apple On-Device specific status
                Text("Apple On-Device Status")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(OKColor.textMuted)
                
                HStack {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 12))
                    Text(appleAvailability.isAvailable ? "Available" : "Unavailable")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(appleAvailability.isAvailable ? OKColor.riskNominal : OKColor.riskCritical)
                    Spacer()
                }
                
                if let reason = appleAvailability.reason, !appleAvailability.isAvailable {
                    Text("Reason: \(reason)")
                        .font(.caption2)
                        .foregroundColor(OKColor.riskWarning)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Divider()
                
                // Backend availability
                Text("All Backend Availability")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(OKColor.textMuted)
                
                ForEach(Array(modelRouter.backendAvailability.keys), id: \.self) { backend in
                    let availability = modelRouter.backendAvailability[backend]
                    HStack {
                        Text(backend.displayName)
                            .font(.caption)
                            .frame(width: 100, alignment: .leading)
                        
                        if availability?.isAvailable == true {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(OKColor.riskNominal)
                                Text("Available")
                                    .font(.caption2)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(OKColor.riskCritical)
                                Text("Unavailable")
                                    .font(.caption2)
                            }
                        }
                        
                        Spacer()
                    }
                }
                
                Divider()
                
                // Last generation info
                Text("Last Generation")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(OKColor.textMuted)
                
                HStack {
                    Text("Backend")
                        .font(.caption)
                        .foregroundColor(OKColor.textMuted)
                        .frame(width: 100, alignment: .leading)
                    Text(modelRouter.currentBackend.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                }
                
                HStack {
                    Text("Latency")
                        .font(.caption)
                        .foregroundColor(OKColor.textMuted)
                        .frame(width: 100, alignment: .leading)
                    Text("\(modelRouter.lastGenerationTimeMs)ms")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                }
                
                if let fallbackReason = modelRouter.lastFallbackReason {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fallback Reason:")
                            .font(.caption)
                            .foregroundColor(OKColor.textMuted)
                        Text(fallbackReason)
                            .font(.caption2)
                            .foregroundColor(OKColor.riskWarning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                Divider()
                
                // Invariants confirmation
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(OKColor.riskNominal)
                        Text("All generation is on-device")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(OKColor.riskNominal)
                        Text("No network calls in model pipeline")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(OKColor.riskNominal)
                        Text("Citations from selected context only")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(OKColor.riskNominal)
                        Text("Fallback to Deterministic if Apple unavailable")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding(16)
            .background(OKColor.riskExtreme.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Eval Harness Section (DEBUG)
    private var evalHarnessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "testtube.2")
                    .font(.system(size: 16))
                    .foregroundColor(OKColor.riskExtreme)
                
                Text("DEBUG: Model Evaluation")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                // Run Evaluation Button
                Button(action: runEvaluation) {
                    HStack {
                        if evalRunner.isRunning {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.circle.fill")
                        }
                        
                        Text(evalRunner.isRunning ? "Running..." : "Run Model Diagnostics")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(evalRunner.isRunning ? OKColor.textMuted.opacity(0.2) : OKColor.riskExtreme.opacity(0.1))
                    .foregroundColor(evalRunner.isRunning ? OKColor.textMuted : OKColor.riskExtreme)
                    .cornerRadius(10)
                }
                .disabled(evalRunner.isRunning)
                
                // Progress indicator
                if evalRunner.isRunning, let currentCase = evalRunner.currentCase {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Testing: \(currentCase.name)")
                            .font(.caption)
                            .foregroundColor(OKColor.textMuted)
                        
                        ProgressView(value: evalRunner.progress)
                            .tint(OKColor.riskExtreme)
                    }
                }
                
                // Results summary
                if let result = lastEvalResult {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Latest Results")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(OKColor.textMuted)
                            
                            Spacer()
                            
                            // Pass/Fail badge
                            HStack(spacing: 4) {
                                Image(systemName: result.passed == result.totalCases ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .font(.system(size: 10))
                                Text("\(result.passed)/\(result.totalCases)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(result.passed == result.totalCases ? OKColor.riskNominal : OKColor.riskWarning)
                        }
                        
                        // Metrics
                        HStack(spacing: 16) {
                            evalMetric(label: "Avg Latency", value: "\(result.averageLatencyMs)ms")
                            evalMetric(label: "Avg Conf", value: "\(Int(result.averageConfidence * 100))%")
                            evalMetric(label: "Fallback", value: "\(Int(result.fallbackRate * 100))%")
                        }
                        
                        // Detailed results toggle
                        Button(action: { showingEvalResults.toggle() }) {
                            HStack {
                                Text(showingEvalResults ? "Hide Details" : "Show Details")
                                    .font(.caption)
                                Image(systemName: showingEvalResults ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(OKColor.riskExtreme)
                        }
                        
                        // Detailed results list
                        if showingEvalResults {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(result.reports) { report in
                                    evalCaseRow(report: report)
                                }
                            }
                        }
                    }
                }
                
                // Invariants reminder
                Text("Uses synthetic context only — no user data")
                    .font(.caption2)
                    .foregroundColor(OKColor.textMuted)
                    .italic()
                
                Divider()
                
                // Fault Injection Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fault Injection Testing")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(OKColor.riskWarning)
                    
                    Toggle(isOn: $faultInjectionEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Fault Injection")
                                .font(.subheadline)
                            Text("Routes to test backend for eval only")
                                .font(.caption2)
                                .foregroundColor(OKColor.textMuted)
                        }
                    }
                    .tint(OKColor.riskWarning)
                    .onChange(of: faultInjectionEnabled) { _, newValue in
                        ModelRouter.shared.enableFaultInjection = newValue
                    }
                    
                    // Run fault injection tests button
                    Button(action: runFaultInjectionTests) {
                        HStack {
                            if evalRunner.isRunning {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "ant.circle.fill")
                            }
                            
                            Text(evalRunner.isRunning ? "Running..." : "Run Fault Tests")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(OKColor.riskWarning.opacity(0.1))
                        .foregroundColor(OKColor.riskWarning)
                        .cornerRadius(8)
                    }
                    .disabled(evalRunner.isRunning)
                    
                    // Fault injection results
                    if let report = lastFaultInjectionReport {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Fault Test Results: \(report.passCount)/\(report.totalCount)")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            ForEach(report.reports) { caseReport in
                                HStack(spacing: 4) {
                                    Image(systemName: caseReport.result.isPassing ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(caseReport.result.isPassing ? OKColor.riskNominal : OKColor.riskCritical)
                                    Text(caseReport.caseName)
                                        .font(.caption2)
                                    Spacer()
                                    if caseReport.timeoutOccurred {
                                        Text("⏱")
                                    }
                                    if !caseReport.validationPass {
                                        Text("⚠️")
                                    }
                                }
                            }
                        }
                        .padding(8)
                        .background(OKColor.riskWarning.opacity(0.05))
                        .cornerRadius(6)
                    }
                }
            }
            .padding(16)
            .background(OKColor.riskExtreme.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private func runFaultInjectionTests() {
        Task {
            lastFaultInjectionReport = await evalRunner.runFaultInjectionCases()
        }
    }
    
    private func evalMetric(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundColor(OKColor.textMuted)
        }
    }
    
    private func evalCaseRow(report: EvalCaseReport) -> some View {
        HStack(spacing: 8) {
            // Result icon
            Image(systemName: report.result.isPassing ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(report.result.isPassing ? OKColor.riskNominal : OKColor.riskCritical)
            
            // Case name
            VStack(alignment: .leading, spacing: 1) {
                Text(report.caseName)
                    .font(.caption)
                    .lineLimit(1)
                
                Text("\(report.confidencePercentage)% conf • \(report.formattedLatency)")
                    .font(.caption2)
                    .foregroundColor(OKColor.textMuted)
            }
            
            Spacer()
            
            // Backend badge
            Text(report.backendUsed.displayName)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(OKColor.textMuted.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
    
    private func runEvaluation() {
        Task {
            lastEvalResult = await evalRunner.runQuickEval()
        }
    }
    #endif
    
    // MARK: - Actions
    
    private func refreshPermissions() {
        isRefreshing = true
        permissionManager.refreshSystemPermissionStates()
        
        // Brief visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isRefreshing = false
        }
    }
    
    private func requestCalendar() {
        guard permissionManager.calendarState.requiresUserAction else {
            showingSettingsAlert = true
            return
        }
        
        isRequestingPermission = true
        Task {
            _ = await permissionManager.requestCalendarAccess()
            isRequestingPermission = false
        }
    }
    
    private func requestReminders() {
        guard permissionManager.remindersState.requiresUserAction else {
            showingSettingsAlert = true
            return
        }
        
        isRequestingPermission = true
        Task {
            _ = await permissionManager.requestRemindersAccess()
            isRequestingPermission = false
        }
    }
}

// MARK: - Color Extension for AuthorizationState

extension Color {
    init(_ colorName: String) {
        switch colorName {
        case "green": self = OKColor.riskNominal
        case "red": self = OKColor.riskCritical
        case "orange": self = OKColor.riskWarning
        case "blue": self = OKColor.actionPrimary
        case "gray": self = OKColor.textMuted
        default: self = OKColor.textMuted
        }
    }
}

#Preview {
    PrivacyControlsView()
        .environmentObject(AppState())
}
