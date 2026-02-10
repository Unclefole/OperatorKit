import SwiftUI

// ============================================================================
// POLICY CALLOUT VIEW (Phase 10C)
//
// Inline callout shown when a policy blocks an action.
// Provides reason and link to edit policy.
//
// See: docs/SAFETY_CONTRACT.md (unchanged)
// ============================================================================

/// Callout shown when policy blocks an action
struct PolicyCalloutView: View {
    let decision: PolicyDecision
    let onEditPolicyTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised")
                    .font(.system(size: 20))
                    .foregroundColor(OKColor.riskWarning)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Blocked by Policy")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(decision.reason)
                        .font(.caption)
                        .foregroundColor(OKColor.textSecondary)
                }
                
                Spacer()
            }
            
            Button(action: onEditPolicyTapped) {
                Text("Edit Policy")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(OKColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(OKColor.actionPrimary)
                    .cornerRadius(8)
            }
            .accessibilityLabel("Edit execution policy")
        }
        .padding(16)
        .background(OKColor.riskWarning.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(OKColor.riskWarning.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Policy Status Badge

/// Badge showing current policy status
struct PolicyStatusBadge: View {
    let policy: OperatorPolicy
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: policy.enabled ? "shield.checkered" : "shield.slash")
                .font(.system(size: 10))
            
            Text(policy.enabled ? policy.statusText : "Disabled")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(badgeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.1))
        .cornerRadius(6)
        .accessibilityLabel("Policy: \(policy.enabled ? policy.statusText : "Disabled")")
    }
    
    private var badgeColor: Color {
        if !policy.enabled {
            return OKColor.textMuted
        }
        
        let blockedCount = [
            !policy.allowEmailDrafts,
            !policy.allowCalendarWrites,
            !policy.allowTaskCreation,
            !policy.allowMemoryWrites
        ].filter { $0 }.count
        
        if blockedCount == 0 {
            return OKColor.riskNominal
        } else if blockedCount == 4 {
            return OKColor.riskCritical
        } else {
            return OKColor.riskWarning
        }
    }
}

// MARK: - Capability Status Row

/// Row showing a capability's policy status
struct CapabilityStatusRow: View {
    let capability: PolicyCapability
    let decision: PolicyDecision
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: capability.icon)
                .font(.system(size: 16))
                .foregroundColor(decision.allowed ? OKColor.actionPrimary : OKColor.textMuted)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(capability.displayName)
                    .font(.subheadline)
                
                Text(decision.reason)
                    .font(.caption)
                    .foregroundColor(OKColor.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: decision.allowed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(decision.allowed ? OKColor.riskNominal : OKColor.riskCritical)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(capability.displayName): \(decision.allowed ? "Allowed" : "Blocked")")
    }
}

// MARK: - Preview

#Preview("Policy Callout") {
    VStack(spacing: 20) {
        PolicyCalloutView(
            decision: .deny(capability: .emailDrafts),
            onEditPolicyTapped: {}
        )
        
        PolicyCalloutView(
            decision: .denyDailyLimit(used: 5, max: 5),
            onEditPolicyTapped: {}
        )
    }
    .padding()
}

#Preview("Policy Status Badge") {
    VStack(spacing: 12) {
        PolicyStatusBadge(policy: .defaultPolicy)
        PolicyStatusBadge(policy: .restrictive)
        PolicyStatusBadge(policy: OperatorPolicy(enabled: false))
    }
    .padding()
}
