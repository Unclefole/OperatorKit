import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var memoryStore = MemoryStore.shared
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Navigation Header
                headerView
                
                // Status Strip (Phase 5C) - shows errors from previous flow
                FlowStatusStripView(onRecoveryAction: handleRecoveryAction)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Main Input Card
                        inputCard
                        
                        // Recent Operations Section
                        recentOperationsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
                
                Spacer()
            }
            
            // Bottom Floating Section
            VStack {
                Spacer()
                bottomSection
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Recovery Action Handler (Phase 5C)
    private func handleRecoveryAction(_ action: OperatorKitUserFacingError.RecoveryAction) {
        switch action {
        case .viewMemory:
            appState.navigateTo(.memory)
        case .openSettings:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        default:
            appState.clearError()
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("OperatorKit")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            Button(action: {
                appState.navigateTo(.privacy)
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Input Card
    private var inputCard: some View {
        Button(action: {
            appState.startNewOperation()
        }) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    // App Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "mic.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    
                    Text("OperatorKit")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.5))
                }
                
                // Text Input Field
                HStack {
                    Text("What do you want handled?")
                        .font(.body)
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(UIColor.systemGroupedBackground))
                .cornerRadius(12)
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Recent Operations Section
    private var recentOperationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Text("Recent Operations")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    appState.navigateTo(.memory)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text("History")
                            .font(.subheadline)
                    }
                    .foregroundColor(.gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(UIColor.systemGroupedBackground))
                    .cornerRadius(16)
                }
            }
            
            // Operations List
            VStack(spacing: 0) {
                ForEach(Array(memoryStore.items.prefix(3).enumerated()), id: \.element.id) { index, item in
                    RecentOperationRow(item: item)
                    
                    if index < min(2, memoryStore.items.count - 1) {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        }
    }
    
    // MARK: - Bottom Section
    private var bottomSection: some View {
        VStack(spacing: 20) {
            // Microphone Button
            Button(action: {
                appState.startNewOperation()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 64, height: 64)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                    
                    Image(systemName: "mic.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
            }
            
            // Quick Action Buttons
            HStack(spacing: 12) {
                QuickActionButton(
                    icon: "doc.text.fill",
                    title: "Handle a\nMeeting",
                    action: {
                        let intent = IntentRequest(rawText: "Handle my meeting", intentType: .summarizeMeeting)
                        appState.selectedIntent = intent
                        appState.navigateTo(.intentInput)
                    }
                )
                QuickActionButton(
                    icon: "envelope.fill",
                    title: "Handle\nan Email",
                    action: {
                        let intent = IntentRequest(rawText: "Draft an email", intentType: .draftEmail)
                        appState.selectedIntent = intent
                        appState.navigateTo(.intentInput)
                    }
                )
                QuickActionButton(
                    icon: "doc.fill",
                    title: "Handle a\nDocument",
                    action: {
                        let intent = IntentRequest(rawText: "Review a document", intentType: .reviewDocument)
                        appState.selectedIntent = intent
                        appState.navigateTo(.intentInput)
                    }
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .padding(.top, 12)
        .background(
            Color.white
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
        )
    }
}

// MARK: - Recent Operation Row
struct RecentOperationRow: View {
    let item: PersistedMemoryItem
    
    private var icon: String {
        switch item.type {
        case .draftedEmail, .sentEmail:
            return "envelope.fill"
        case .summary:
            return "doc.text.fill"
        case .actionItems:
            return "checkmark.square.fill"
        case .reminder:
            return "bell.fill"
        case .documentReview:
            return "doc.text.magnifyingglass"
        }
    }
    
    private var iconColor: Color {
        switch item.type {
        case .draftedEmail, .sentEmail:
            return .blue
        case .actionItems:
            return .green
        case .summary, .documentReview:
            return .orange
        case .reminder:
            return .purple
        }
    }
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(item.preview)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                    
                    Text(item.formattedDate)
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
