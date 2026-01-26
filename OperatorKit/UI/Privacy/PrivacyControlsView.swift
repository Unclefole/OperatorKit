import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import EventKit

/// Displays and manages privacy controls
/// INVARIANT: No auto-requesting permissions - user must tap to request
/// Shows distinct permission states: Not Determined, Denied, Authorized, Restricted, Write-Only
struct PrivacyControlsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var permissionManager = PermissionManager.shared
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
            // Background
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Privacy Summary
                        privacySummaryCard
                        
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
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
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
    private var headerView: some View {
        HStack {
            Button(action: {
                appState.navigateBack()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Text("Privacy Controls")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            // Refresh button
            Button(action: refreshPermissions) {
                if isRefreshing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
            .disabled(isRefreshing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Privacy Summary Card
    private var privacySummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 28))
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Data Stays on Your Device")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("OperatorKit works entirely on-device. Nothing leaves your phone.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
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
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
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
                .foregroundColor(.gray)
            
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
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Last Refreshed")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(formattedRefreshTime)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            Button(action: refreshPermissions) {
                Text("Refresh Now")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            .disabled(isRefreshing)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
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
                    iconColor: .red,
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
                    iconColor: .orange,
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
                    iconColor: .blue,
                    title: "Mail",
                    subtitle: "Open email composer with drafts",
                    state: permissionManager.canSendMail ? .authorized : .denied,
                    onRequest: nil,
                    isLoading: false,
                    isMailPermission: true
                )
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            
            // Data access helper text
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                Text("OperatorKit only accesses data when you explicitly select it.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                    .foregroundColor(.gray)
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
            .foregroundColor(.green)
            
        case .writeOnly:
            // Blue pencil
            HStack(spacing: 4) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 14))
                Text("Write Only")
                    .font(.caption)
            }
            .foregroundColor(.blue)
            
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
                .foregroundColor(.red)
            }
            
        case .restricted:
            // Orange lock
            HStack(spacing: 4) {
                Image(systemName: "lock.circle.fill")
                    .font(.system(size: 14))
                Text("Restricted")
                    .font(.caption)
            }
            .foregroundColor(.orange)
            
        case .notDetermined:
            // Blue Allow access button
            if let onRequest = onRequest {
                Button(action: onRequest) {
                    Text("Allow access")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(16)
                }
            } else {
                Text("Not enabled")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
        case .unknown:
            // Gray question mark
            HStack(spacing: 4) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 14))
                Text("Unknown")
                    .font(.caption)
            }
            .foregroundColor(.gray)
        }
    }
    
    // MARK: - Data Usage Section
    private var dataUsageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Usage")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 0) {
                dataRow(
                    icon: "icloud.slash",
                    iconColor: .purple,
                    title: "No Cloud Upload",
                    subtitle: "All processing happens on your device"
                )
                
                Divider().padding(.leading, 56)
                
                dataRow(
                    icon: "eye.slash",
                    iconColor: .blue,
                    title: "No Tracking",
                    subtitle: "We don't collect analytics or user data"
                )
                
                Divider().padding(.leading, 56)
                
                dataRow(
                    icon: "lock.shield",
                    iconColor: .green,
                    title: "Encrypted Storage",
                    subtitle: "Your memory items are encrypted locally"
                )
                
                Divider().padding(.leading, 56)
                
                // Full Data Use Disclosure link (Phase 6A)
                Button(action: {
                    showingDataUseDisclosure = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Full Data Use Disclosure")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("Detailed explanation of how your data is used")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
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
                            .foregroundColor(.purple)
                            .frame(width: 44, height: 44)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quality & Trust")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("View your local feedback and calibration data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
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
                    .foregroundColor(.purple)
                    .frame(width: 44, height: 44)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reviewer Help")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("Test plan and guarantees overview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
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
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.green)
        }
        .padding(16)
    }
    
    // MARK: - On-Device Model Section (Phase 4A)
    private var onDeviceModelSection: some View {
        let modelRouter = ModelRouter.shared
        let appleAvailability = modelRouter.appleOnDeviceAvailability
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cpu")
                    .font(.system(size: 20))
                    .foregroundColor(.indigo)
                
                Text("On-Device Intelligence")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 0) {
                // Current backend
                modelBackendRow()
                
                Divider().padding(.leading, 56)
                
                // Apple On-Device status
                appleOnDeviceStatusRow(isAvailable: appleAvailability.isAvailable)
                
                Divider().padding(.leading, 56)
                
                // Network status (always off)
                dataRow(
                    icon: "wifi.slash",
                    iconColor: .green,
                    title: "Network Disabled",
                    subtitle: "All AI runs locally on your device"
                )
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
    
    private func modelBackendRow() -> some View {
        let modelRouter = ModelRouter.shared
        let currentBackend = modelRouter.currentBackend
        
        return HStack(spacing: 12) {
            Image(systemName: modelBackendIcon(currentBackend))
                .font(.system(size: 20))
                .foregroundColor(.indigo)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Active Model")
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(currentBackend.displayName)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Backend status badge
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("On-Device")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(16)
    }
    
    private func appleOnDeviceStatusRow(isAvailable: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "apple.logo")
                .font(.system(size: 20))
                .foregroundColor(isAvailable ? .green : .gray)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple On-Device")
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(isAvailable ? "Available (iOS 18.1+ with Apple Intelligence)" : "Not available on this device/OS")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Availability badge
            HStack(spacing: 4) {
                Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 12))
                Text(isAvailable ? "Available" : "Unavailable")
                    .font(.caption2)
            }
            .foregroundColor(isAvailable ? .green : .gray)
        }
        .padding(16)
    }
    
    private func modelBackendIcon(_ backend: ModelBackend) -> String {
        switch backend {
        case .appleOnDevice:
            return "apple.logo"
        case .coreML:
            return "brain"
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
                    .foregroundColor(.blue)
                
                Text("Subscription")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 0) {
                // Current tier row
                HStack(spacing: 12) {
                    Image(systemName: appState.isPro ? "star.fill" : "person.fill")
                        .font(.system(size: 20))
                        .foregroundColor(appState.isPro ? .blue : .gray)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current Plan")
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Text(appState.currentTier.displayName)
                            .font(.caption)
                            .foregroundColor(.gray)
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
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.isPro ? "Manage Subscription" : "Upgrade to Pro")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text(appState.isPro ? "View plan details and renewal date" : "Remove limits and get more done")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .sheet(isPresented: $showingSubscription) {
            if appState.isPro {
                NavigationView {
                    SubscriptionStatusView()
                        .environmentObject(appState)
                }
            } else {
                UpgradeView()
                    .environmentObject(appState)
            }
        }
    }
    
    // MARK: - Diagnostics Section (Phase 10B)
    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 20))
                    .foregroundColor(.purple)
                
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
                            .foregroundColor(.purple)
                            .frame(width: 44, height: 44)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("View Diagnostics")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("Execution stats, limits, and system status")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
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
                    .foregroundColor(.teal)
                
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
                            .foregroundColor(.teal)
                            .frame(width: 44, height: 44)
                            .background(Color.teal.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Customer Proof Dashboard")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("Safety verification, audit trail, exports")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .sheet(isPresented: $showingCustomerProof) {
            CustomerProofView()
        }
    }
    
    // MARK: - Policy Section (Phase 10C)
    private var policySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 20))
                    .foregroundColor(.indigo)
                
                Text("Execution Policy")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 0) {
                // Current policy status
                HStack(spacing: 12) {
                    Image(systemName: "hand.raised")
                        .font(.system(size: 20))
                        .foregroundColor(.indigo)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current Policy")
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Text(OperatorPolicyStore.shared.policySummary())
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    PolicyStatusBadge(policy: OperatorPolicyStore.shared.currentPolicy)
                }
                .padding(16)
                
                Divider().padding(.leading, 56)
                
                // Edit policy link
                Button(action: {
                    showingPolicyEditor = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18))
                            .foregroundColor(.indigo)
                            .frame(width: 44, height: 44)
                            .background(Color.indigo.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Edit Policy")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("Configure what OperatorKit can do")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
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
                    .foregroundColor(.cyan)
                
                Text("Cloud Sync (Optional)")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 0) {
                // Sync status
                HStack(spacing: 12) {
                    Image(systemName: syncEnabled ? "icloud.fill" : "icloud.slash")
                        .font(.system(size: 20))
                        .foregroundColor(syncEnabled ? .cyan : .gray)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(syncEnabled ? "Sync Enabled" : "Sync Disabled")
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Text(syncEnabled ? "Metadata-only packets can be uploaded" : "All data stays on your device")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text(syncEnabled ? "ON" : "OFF")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(syncEnabled ? .cyan : .gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((syncEnabled ? Color.cyan : Color.gray).opacity(0.1))
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
                            .foregroundColor(.cyan)
                            .frame(width: 44, height: 44)
                            .background(Color.cyan.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sync Settings")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("Sign in, view staged packets, upload")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
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
                    .foregroundColor(.orange)
                
                Text("Team")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 0) {
                // Team status
                HStack(spacing: 12) {
                    Image(systemName: TeamStore.shared.hasTeam ? "person.3.fill" : "person.3")
                        .font(.system(size: 20))
                        .foregroundColor(TeamStore.shared.hasTeam ? .orange : .gray)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if let team = TeamStore.shared.currentTeam {
                            Text(team.name)
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Role: \(team.memberRole.displayName)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            Text("No Team")
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Share governance artifacts with your team")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    if EntitlementManager.shared.hasTeamFeatures {
                        Text("Team Tier")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
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
                            .foregroundColor(.orange)
                            .frame(width: 44, height: 44)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Team Settings")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("Manage team, members, and shared artifacts")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .sheet(isPresented: $showingTeamSettings) {
            TeamSettingsView()
        }
    }
    
    // MARK: - Subscription Section (Phase 10G)
    @State private var showingSubscriptionStatus: Bool = false
    
    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "creditcard")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                
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
                            .foregroundColor(.gray)
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
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Manage Subscription")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("View plans, usage, and billing")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
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
        case .free: return .gray
        case .pro: return .blue
        case .team: return .orange
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
                    .foregroundColor(.blue)
                
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
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Help Center")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("FAQ, troubleshooting, contact support")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
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
                    .foregroundColor(.purple)
                
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
                            .foregroundColor(.purple)
                            .frame(width: 44, height: 44)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Re-run Onboarding")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("Review safety model and features")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
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
                    .foregroundColor(.orange)
                
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
                            .foregroundColor(.orange)
                            .frame(width: 44, height: 44)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Submission Readiness")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("Review notes, screenshots, exports")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
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
                    .foregroundColor(.purple)
                
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
                            .foregroundColor(.purple)
                            .frame(width: 44, height: 44)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Conversion Summary")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("Funnel counts and rates (local-only)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
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
                    .foregroundColor(.blue)
                
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
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Team Sales Kit")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("Procurement, trials, and rollout")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .sheet(isPresented: $showingTeamSalesKit) {
            TeamSalesKitView()
        }
    }
    #endif
    
    // MARK: - Guarantees Section
    private var guaranteesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                
                Text("What OperatorKit Will Never Do")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                guaranteeRow("Take action without your explicit approval")
                guaranteeRow("Access your data in the background")
                guaranteeRow("Send emails, create events, or write reminders silently")
                guaranteeRow("Skip showing you what will happen")
                guaranteeRow("Use context you haven't selected")
                guaranteeRow("Send your data to the cloud or any server")
                guaranteeRow("Let Siri execute actions—it only opens OperatorKit")
                guaranteeRow("Perform write operations without a second confirmation")
            }
            .padding(16)
            .background(Color.green.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private func guaranteeRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.green)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
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
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange)
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
                            .foregroundColor(.secondary)
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
                            .foregroundColor(.orange)
                        
                        Text("Synthetic data active. Context Picker will show demo items. No real EventKit access in demo mode.")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            
            Text("Demo mode uses synthetic data for QA and TestFlight testing. It does not access real user data and audit trails are marked as synthetic.")
                .font(.caption)
                .foregroundColor(.secondary)
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
                        .foregroundColor(.purple)
                    
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
                                .foregroundColor(.gray)
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
                            .foregroundColor(.green)
                        Text("No prompts without user tap")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .padding(16)
                .background(Color.purple.opacity(0.05))
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
                    .foregroundColor(.indigo)
                
                Text("DEBUG: Model Diagnostics")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Apple On-Device specific status
                Text("Apple On-Device Status")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                
                HStack {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 12))
                    Text(appleAvailability.isAvailable ? "Available" : "Unavailable")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(appleAvailability.isAvailable ? .green : .red)
                    Spacer()
                }
                
                if let reason = appleAvailability.reason, !appleAvailability.isAvailable {
                    Text("Reason: \(reason)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Divider()
                
                // Backend availability
                Text("All Backend Availability")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                
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
                                    .foregroundColor(.green)
                                Text("Available")
                                    .font(.caption2)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.red)
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
                    .foregroundColor(.gray)
                
                HStack {
                    Text("Backend")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(width: 100, alignment: .leading)
                    Text(modelRouter.currentBackend.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                }
                
                HStack {
                    Text("Latency")
                        .font(.caption)
                        .foregroundColor(.gray)
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
                            .foregroundColor(.gray)
                        Text(fallbackReason)
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                Divider()
                
                // Invariants confirmation
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("All generation is on-device")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("No network calls in model pipeline")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("Citations from selected context only")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("Fallback to Deterministic if Apple unavailable")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding(16)
            .background(Color.indigo.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Eval Harness Section (DEBUG)
    private var evalHarnessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "testtube.2")
                    .font(.system(size: 16))
                    .foregroundColor(.purple)
                
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
                    .background(evalRunner.isRunning ? Color.gray.opacity(0.2) : Color.purple.opacity(0.1))
                    .foregroundColor(evalRunner.isRunning ? .gray : .purple)
                    .cornerRadius(10)
                }
                .disabled(evalRunner.isRunning)
                
                // Progress indicator
                if evalRunner.isRunning, let currentCase = evalRunner.currentCase {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Testing: \(currentCase.name)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        ProgressView(value: evalRunner.progress)
                            .tint(.purple)
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
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            // Pass/Fail badge
                            HStack(spacing: 4) {
                                Image(systemName: result.passed == result.totalCases ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .font(.system(size: 10))
                                Text("\(result.passed)/\(result.totalCases)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(result.passed == result.totalCases ? .green : .orange)
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
                            .foregroundColor(.purple)
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
                    .foregroundColor(.gray)
                    .italic()
                
                Divider()
                
                // Fault Injection Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fault Injection Testing")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    
                    Toggle(isOn: $faultInjectionEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Fault Injection")
                                .font(.subheadline)
                            Text("Routes to test backend for eval only")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .tint(.orange)
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
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
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
                                        .foregroundColor(caseReport.result.isPassing ? .green : .red)
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
                        .background(Color.orange.opacity(0.05))
                        .cornerRadius(6)
                    }
                }
            }
            .padding(16)
            .background(Color.purple.opacity(0.05))
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
                .foregroundColor(.gray)
        }
    }
    
    private func evalCaseRow(report: EvalCaseReport) -> some View {
        HStack(spacing: 8) {
            // Result icon
            Image(systemName: report.result.isPassing ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(report.result.isPassing ? .green : .red)
            
            // Case name
            VStack(alignment: .leading, spacing: 1) {
                Text(report.caseName)
                    .font(.caption)
                    .lineLimit(1)
                
                Text("\(report.confidencePercentage)% conf • \(report.formattedLatency)")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Backend badge
            Text(report.backendUsed.displayName)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.1))
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
        case "green": self = .green
        case "red": self = .red
        case "orange": self = .orange
        case "blue": self = .blue
        case "gray": self = .gray
        default: self = .gray
        }
    }
}

#Preview {
    PrivacyControlsView()
        .environmentObject(AppState())
}
