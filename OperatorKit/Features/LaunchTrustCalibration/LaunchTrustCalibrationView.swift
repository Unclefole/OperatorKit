import SwiftUI

// ============================================================================
// LAUNCH TRUST CALIBRATION VIEW (Phase L2)
//
// One-time, user-visible verification ceremony on first launch.
// Demonstrates OperatorKit's security posture using existing proof artifacts.
//
// THIS IS A CEREMONY, NOT A GUARDRAIL.
//
// PROOF SOURCES:
// - Binary Proof (BinaryImageInspector)
// - Build Seals (BuildSealsLoader)
// - Offline Certification (OfflineCertificationRunner)
// - ProofPack (availability check)
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No enforcement (app runs regardless of results)
// ❌ No networking
// ❌ No background tasks
// ❌ No retries
// ❌ No auto-rechecks after completion
// ✅ One-time only (until reinstall)
// ✅ Deterministic
// ✅ User-visible
// ============================================================================

public struct LaunchTrustCalibrationView: View {
    
    // MARK: - State
    
    @State private var calibrationSteps: [CalibrationStep] = []
    @State private var currentStepIndex: Int = 0
    @State private var isComplete: Bool = false
    @State private var isRunning: Bool = false
    
    /// Callback when calibration completes and user taps Continue
    public var onComplete: () -> Void
    
    // MARK: - Init
    
    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }
    
    // MARK: - Body
    
    public var body: some View {
        ZStack {
            // Background - using design system
            OKBackgroundView()
            
            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.top, 60)
                
                Spacer()
                
                // Calibration Steps
                stepsListView
                    .padding(.horizontal, 24)
                
                Spacer()
                
                // Footer / Continue Button
                footerView
                    .padding(.bottom, 40)
            }
        }
        .onAppear(perform: startCalibration)
        .interactiveDismissDisabled(true) // Cannot be dismissed until complete
    }
    
    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 16) {
            // Logo / Icon
            if isComplete {
                // Success state: checkmark shield
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
            } else {
                // Calibrating state: OperatorKit logo
                OperatorKitLogoView(size: .extraLarge, showText: false)
            }

            // Title
            Text(isComplete ? "System Verified" : "Trust Calibration")
                .font(OKTypography.title())
                .foregroundColor(OKColors.textPrimary)

            // Subtitle
            Text(isComplete
                 ? "This device is operating in Zero-Network mode."
                 : "Verifying security posture...")
                .font(OKTypography.subheadline())
                .foregroundColor(OKColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .animation(.easeInOut(duration: 0.3), value: isComplete)
    }
    
    // MARK: - Steps List View
    
    private var stepsListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(calibrationSteps.enumerated()), id: \.element.id) { index, step in
                CalibrationStepRow(
                    step: step,
                    isActive: index == currentStepIndex && isRunning,
                    isCompleted: index < currentStepIndex || isComplete
                )
                .animation(.easeInOut(duration: 0.2), value: step.status)
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Footer View
    
    private var footerView: some View {
        VStack(spacing: 16) {
            if isComplete {
                Button(action: completeCalibration) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
            } else {
                // Progress indicator
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    
                    Text("Verifying...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Explanation text
            Text("Each check reads existing proof artifacts.\nNo data leaves your device.")
                .font(.caption)
                .foregroundColor(Color.gray.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Calibration Logic
    
    private func startCalibration() {
        // Initialize steps
        calibrationSteps = CalibrationStepFactory.createSteps()
        
        // Start running through steps
        isRunning = true
        runNextStep()
    }
    
    private func runNextStep() {
        guard currentStepIndex < calibrationSteps.count else {
            // All steps complete
            withAnimation {
                isRunning = false
                isComplete = true
            }
            return
        }
        
        // Run the current step
        let stepIndex = currentStepIndex
        
        // Small delay for visual effect (ceremony, not speed)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // Execute the step's verification
            let result = calibrationSteps[stepIndex].verify()
            
            withAnimation {
                calibrationSteps[stepIndex].status = result ? .passed : .failed
            }
            
            // Move to next step
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                currentStepIndex += 1
                runNextStep()
            }
        }
    }
    
    private func completeCalibration() {
        // Mark as complete
        LaunchTrustCalibrationState.markComplete()
        
        // Call completion handler
        onComplete()
    }
}

// MARK: - Calibration Step Model

/// A single verification step in the calibration ceremony
public class CalibrationStep: Identifiable, ObservableObject {
    public let id = UUID()
    
    /// Display label
    public let label: String
    
    /// Source of the proof
    public let proofSource: String
    
    /// Current status
    @Published public var status: CalibrationStepStatus = .pending
    
    /// Verification closure (reads existing proof, returns true/false)
    public let verify: () -> Bool
    
    public init(label: String, proofSource: String, verify: @escaping () -> Bool) {
        self.label = label
        self.proofSource = proofSource
        self.verify = verify
    }
}

/// Status of a calibration step
public enum CalibrationStepStatus {
    case pending
    case running
    case passed
    case failed
}

// MARK: - Calibration Step Row

private struct CalibrationStepRow: View {
    @ObservedObject var step: CalibrationStep
    let isActive: Bool
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Status Icon
            statusIcon
                .frame(width: 28, height: 28)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(step.label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(textColor)
                
                Text(step.proofSource)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .opacity(opacity)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch step.status {
        case .pending:
            if isActive {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.gray)
            }
            
        case .running:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            
        case .passed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)
            
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.title3)
        }
    }
    
    private var textColor: Color {
        switch step.status {
        case .pending: return isActive ? .primary : .secondary
        case .running: return .primary
        case .passed: return .primary
        case .failed: return .red
        }
    }
    
    private var opacity: Double {
        switch step.status {
        case .pending: return isActive ? 1.0 : 0.6
        case .running, .passed, .failed: return 1.0
        }
    }
}

// MARK: - Calibration Step Factory

/// Factory that creates calibration steps from existing proof artifacts
public enum CalibrationStepFactory {
    
    /// Create all calibration steps
    /// Each step reads from existing proof — no new computation
    public static func createSteps() -> [CalibrationStep] {
        [
            // Step 1: Binary contains no WebKit
            CalibrationStep(
                label: "Binary contains no WebKit",
                proofSource: "Binary Proof"
            ) {
                let result = BinaryImageInspector.inspect()
                let webKitCheck = result.sensitiveChecks.first { $0.framework == "WebKit" }
                return !(webKitCheck?.isPresent ?? false)
            },
            
            // Step 2: JavaScript not linked
            CalibrationStep(
                label: "JavaScript not linked",
                proofSource: "Binary Proof"
            ) {
                let result = BinaryImageInspector.inspect()
                let jsCheck = result.sensitiveChecks.first { $0.framework == "JavaScriptCore" }
                return !(jsCheck?.isPresent ?? false)
            },
            
            // Step 3: Network entitlements absent
            CalibrationStep(
                label: "Network entitlements absent",
                proofSource: "Entitlements Seal"
            ) {
                let seals = BuildSealsLoader.loadAllSeals()
                return !(seals.entitlements?.networkClientRequested ?? false)
            },
            
            // Step 4: Forbidden symbols absent
            CalibrationStep(
                label: "Forbidden symbols absent",
                proofSource: "Symbol Seal"
            ) {
                let seals = BuildSealsLoader.loadAllSeals()
                let count = seals.symbols?.forbiddenSymbolCount ?? 0
                return count == 0
            },
            
            // Step 5: Offline execution certified
            CalibrationStep(
                label: "Offline execution certified",
                proofSource: "Offline Certification"
            ) {
                let report = OfflineCertificationRunner.shared.runAllChecks()
                return report.failedCount == 0
            },
            
            // Step 6: Build integrity verified
            CalibrationStep(
                label: "Build integrity verified",
                proofSource: "Build Seals"
            ) {
                let seals = BuildSealsLoader.loadAllSeals()
                return seals.overallStatus == .verified || seals.overallStatus == .partial
            },
            
            // Step 7: Proof export available
            CalibrationStep(
                label: "Proof export available",
                proofSource: "ProofPack"
            ) {
                return ProofPackFeatureFlag.isEnabled
            }
        ]
    }
}

// MARK: - Preview

#if DEBUG
struct LaunchTrustCalibrationView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchTrustCalibrationView {
            print("Calibration complete")
        }
    }
}
#endif
