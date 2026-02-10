import SwiftUI

// ============================================================================
// FIRST WEEK TIPS VIEW (Phase 10Q)
//
// Read-only panel with gentle guidance for first-week users.
// Dismissible. Never modal. Never blocking.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No blocking behavior
// ❌ No restrictions
// ❌ No modal presentation
// ✅ Dismissible
// ✅ Gentle guidance only
// ✅ App Store safe copy
//
// See: docs/APP_REVIEW_PACKET.md
// ============================================================================

struct FirstWeekTipsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firstWeekStore = FirstWeekStore.shared
    
    var body: some View {
        NavigationView {
            List {
                // Welcome Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "hand.wave")
                                .font(.title2)
                                .foregroundColor(OKColor.actionPrimary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Welcome to OperatorKit")
                                    .font(.headline)
                                
                                if firstWeekStore.isFirstWeek {
                                    Text("Day \(firstWeekStore.daysSinceInstall + 1) of 7")
                                        .font(.caption)
                                        .foregroundColor(OKColor.textSecondary)
                                }
                            }
                        }
                        
                        Text("Here are some things to keep in mind as you get started.")
                            .font(.subheadline)
                            .foregroundColor(OKColor.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
                
                // Tips Section
                Section {
                    ForEach(Array(FirstWeekTips.tips.enumerated()), id: \.offset) { index, tip in
                        TipRow(number: index + 1, tip: tip)
                    }
                } header: {
                    Text("Getting Started Tips")
                }
                
                // Core Principles Section
                Section {
                    PrincipleRow(
                        icon: "doc.text",
                        title: "Draft-First",
                        description: "Every action starts as a draft you can review"
                    )
                    
                    PrincipleRow(
                        icon: "hand.raised",
                        title: "Approval Required",
                        description: "Nothing executes without your explicit approval"
                    )
                    
                    PrincipleRow(
                        icon: "eye",
                        title: "Full Transparency",
                        description: "You always see exactly what will happen"
                    )
                    
                    PrincipleRow(
                        icon: "square.and.arrow.up",
                        title: "Export Anytime",
                        description: "You can export proof of all actions"
                    )
                } header: {
                    Text("Core Principles")
                }
            }
            .navigationTitle("First Week Tips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OKColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Tip Row

private struct TipRow: View {
    let number: Int
    let tip: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(OKColor.textPrimary)
                .frame(width: 24, height: 24)
                .background(OKColor.actionPrimary)
                .clipShape(Circle())
            
            Text(tip)
                .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Principle Row

private struct PrincipleRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(OKColor.riskNominal)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Inline Tips Banner

struct FirstWeekTipsBanner: View {
    @StateObject private var firstWeekStore = FirstWeekStore.shared
    @State private var showingTips = false
    @State private var dismissed = false

    /// DETERMINISM FIX: Select tip based on day of year instead of random
    private var deterministicTip: String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = (dayOfYear - 1) % FirstWeekTips.shortTips.count
        return FirstWeekTips.shortTips[index]
    }

    var body: some View {
        if firstWeekStore.isFirstWeek && !dismissed {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "lightbulb")
                        .foregroundColor(OKColor.riskWarning)
                    
                    Text("First week tip: \(deterministicTip)")
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                    
                    Spacer()
                    
                    Button {
                        showingTips = true
                    } label: {
                        Text("More")
                            .font(.caption)
                    }
                    
                    Button {
                        dismissed = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(OKColor.textSecondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(OKColor.riskWarning.opacity(0.1))
            }
            .sheet(isPresented: $showingTips) {
                FirstWeekTipsView()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    FirstWeekTipsView()
}
