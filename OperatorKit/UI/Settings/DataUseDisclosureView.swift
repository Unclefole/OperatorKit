import SwiftUI

/// Static data use disclosure view for App Store compliance (Phase 6A)
/// This view explains OperatorKit's data practices in plain language
/// No functional logic — purely informational
struct DataUseDisclosureView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Introduction
                    introductionSection
                    
                    Divider()
                    
                    // What data can be accessed
                    dataAccessSection
                    
                    Divider()
                    
                    // When access happens
                    whenAccessSection
                    
                    Divider()
                    
                    // What never happens
                    neverHappensSection
                    
                    Divider()
                    
                    // User control guarantees
                    userControlSection
                    
                    Divider()
                    
                    // On-device processing
                    onDeviceSection
                    
                    Divider()
                    
                    // Contact information
                    contactSection
                }
                .padding(20)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Data Use")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Introduction
    
    private var introductionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How OperatorKit Uses Your Data")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("This document explains what data OperatorKit can access, when access occurs, and what protections are in place. OperatorKit is designed to give you control over every action.")
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Data Access Section
    
    private var dataAccessSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "What Data Can Be Accessed", icon: "doc.text.magnifyingglass")
            
            dataAccessRow(
                title: "Calendar Events",
                description: "Event titles, times, locations, and participant names from calendars you have access to.",
                permission: "Requires Calendar permission"
            )
            
            dataAccessRow(
                title: "Reminders",
                description: "Reminder titles, notes, and due dates from your Reminders app.",
                permission: "Requires Reminders permission"
            )
            
            dataAccessRow(
                title: "Email Drafts",
                description: "OperatorKit can open the system email composer with pre-filled content. It cannot read your existing emails or send emails automatically.",
                permission: "Uses system Mail composer"
            )
            
            Text("OperatorKit does not access: Photos, Contacts (beyond calendar participants), Location, Health data, Financial data, Browsing history, or any other personal information.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }
    
    // MARK: - When Access Happens
    
    private var whenAccessSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "When Access Happens", icon: "clock")
            
            whenAccessRow(
                title: "Only When You Explicitly Select",
                description: "OperatorKit only reads data that you manually select. You choose which calendar events, reminders, or files to include as context for your request."
            )
            
            whenAccessRow(
                title: "Only After Permission Granted",
                description: "Before accessing any system data, you must grant permission through the standard iOS permission dialog. You can revoke permission at any time in Settings."
            )
            
            whenAccessRow(
                title: "Only During Active Use",
                description: "OperatorKit accesses data only while you are actively using the app and have selected specific items. There is no background data collection."
            )
        }
    }
    
    // MARK: - What Never Happens
    
    private var neverHappensSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "What Never Happens", icon: "xmark.shield")
            
            neverHappensRow("OperatorKit never sends data over the network")
            neverHappensRow("OperatorKit never accesses data in the background")
            neverHappensRow("OperatorKit never takes actions without your approval")
            neverHappensRow("OperatorKit never sends emails automatically")
            neverHappensRow("OperatorKit never creates reminders without your confirmation")
            neverHappensRow("OperatorKit never modifies calendar events without your confirmation")
            neverHappensRow("OperatorKit never reads data you have not selected")
            neverHappensRow("OperatorKit never shares data with third parties")
            neverHappensRow("OperatorKit never uses data for advertising")
        }
    }
    
    // MARK: - User Control Section
    
    private var userControlSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Your Control", icon: "person.crop.circle.badge.checkmark")
            
            controlRow(
                title: "Approval Required",
                description: "Every action requires your explicit approval before execution. You review the draft and the list of actions before anything happens."
            )
            
            controlRow(
                title: "Write Confirmation",
                description: "Actions that create or modify data (reminders, calendar events) require a second confirmation step. This ensures you have reviewed the exact details."
            )
            
            controlRow(
                title: "Draft-First Design",
                description: "OperatorKit always generates a draft for your review. You can edit, reject, or approve the draft before any action is taken."
            )
            
            controlRow(
                title: "Revocable Permissions",
                description: "You can revoke any permission at any time through iOS Settings. OperatorKit will clearly indicate when a permission is needed and why."
            )
        }
    }
    
    // MARK: - On-Device Section
    
    private var onDeviceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "On-Device Processing", icon: "iphone")
            
            Text("All text generation and processing in OperatorKit happens entirely on your device.")
                .font(.body)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                onDeviceRow("Draft generation uses on-device models only")
                onDeviceRow("No data is sent to external servers")
                onDeviceRow("No cloud processing is used")
                onDeviceRow("Your requests and context stay on your device")
                onDeviceRow("Memory and audit trails are stored locally")
            }
            
            Text("When the preferred on-device model is unavailable, OperatorKit uses a deterministic template-based fallback that also runs entirely on your device.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }
    
    // MARK: - Contact Section
    
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Questions", icon: "questionmark.circle")
            
            Text("If you have questions about how OperatorKit handles your data, please contact us through the App Store or visit our support page.")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.blue)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
    
    private func dataAccessRow(title: String, description: String, permission: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(permission)
                .font(.caption2)
                .foregroundColor(.blue)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(8)
    }
    
    private func whenAccessRow(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 22)
        }
    }
    
    private func neverHappensRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "xmark.circle")
                .font(.system(size: 14))
                .foregroundColor(.red)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func controlRow(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 22)
        }
    }
    
    private func onDeviceRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.green)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview

#Preview {
    DataUseDisclosureView()
}
