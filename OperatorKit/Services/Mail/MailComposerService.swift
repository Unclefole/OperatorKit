import Foundation
import MessageUI
import SwiftUI

/// Service for presenting email composer (DRAFT ONLY)
/// INVARIANT: App NEVER sends emails automatically
/// INVARIANT: User must manually tap Send in the composer
/// INVARIANT: Composer is only presented after explicit approval
@MainActor
final class MailComposerService: NSObject, ObservableObject {
    
    static let shared = MailComposerService()
    
    // MARK: - Published State
    
    @Published private(set) var canSendMail: Bool = false
    @Published private(set) var isPresenting: Bool = false
    @Published private(set) var lastResult: MailComposeResult?
    
    // MARK: - Callback
    
    private var completionHandler: ((MailComposeResult) -> Void)?
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        updateCanSendMail()
    }
    
    // MARK: - Capability Check
    
    func updateCanSendMail() {
        canSendMail = MFMailComposeViewController.canSendMail()
        log("Mail composer available: \(canSendMail)")
    }
    
    // MARK: - Present Composer
    
    /// Presents the mail composer with draft content
    /// INVARIANT: User must manually tap Send - app cannot send automatically
    /// INVARIANT: Only called after explicit user approval
    func presentComposer(
        draft: Draft,
        from viewController: UIViewController,
        completion: @escaping (MailComposeResult) -> Void
    ) {
        guard canSendMail else {
            log("Cannot send mail - no mail accounts configured")
            completion(.failed(reason: "No mail accounts configured on this device"))
            return
        }
        
        guard !isPresenting else {
            log("Mail composer already presenting")
            completion(.failed(reason: "Mail composer already open"))
            return
        }
        
        // Verify this is an email draft
        guard draft.type == .email else {
            log("Draft is not an email type")
            completion(.failed(reason: "Draft is not an email"))
            return
        }
        
        log("Presenting mail composer for draft: \(draft.title)")
        
        completionHandler = completion
        isPresenting = true
        
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = self
        
        // Populate draft content - USER MUST MANUALLY SEND
        if let recipient = draft.content.recipient {
            composer.setToRecipients([recipient])
        }
        
        if let subject = draft.content.subject {
            composer.setSubject(subject)
        }
        
        // Set body with signature
        var body = draft.content.body
        if let signature = draft.content.signature {
            body += "\n\n\(signature)"
        }
        composer.setMessageBody(body, isHTML: false)
        
        // Present composer - USER CONTROLS SENDING
        viewController.present(composer, animated: true)
    }
    
    /// Present composer using SwiftUI hosting
    func presentComposer(
        draft: Draft,
        completion: @escaping (MailComposeResult) -> Void
    ) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            completion(.failed(reason: "Unable to find root view controller"))
            return
        }
        
        // Find the topmost presented view controller
        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }
        
        presentComposer(draft: draft, from: topViewController, completion: completion)
    }
}

// MARK: - MFMailComposeViewControllerDelegate

extension MailComposerService: MFMailComposeViewControllerDelegate {
    
    nonisolated func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith result: MFMailComposeResult,
        error: Error?
    ) {
        Task { @MainActor in
            controller.dismiss(animated: true)
            isPresenting = false
            
            let composeResult: MailComposeResult
            
            switch result {
            case .cancelled:
                log("Mail composer cancelled by user")
                composeResult = .cancelled
                
            case .saved:
                log("Mail draft saved by user")
                composeResult = .savedToDrafts
                
            case .sent:
                // User manually tapped Send
                log("Mail sent by user")
                composeResult = .sentByUser
                
            case .failed:
                let reason = error?.localizedDescription ?? "Unknown error"
                logError("Mail composer failed: \(reason)")
                composeResult = .failed(reason: reason)
                
            @unknown default:
                composeResult = .failed(reason: "Unknown result")
            }
            
            lastResult = composeResult
            completionHandler?(composeResult)
            completionHandler = nil
        }
    }
}

// MARK: - Mail Compose Result

enum MailComposeResult: Equatable {
    case cancelled
    case savedToDrafts
    case sentByUser  // User manually tapped Send
    case failed(reason: String)
    
    var displayMessage: String {
        switch self {
        case .cancelled:
            return "Email cancelled"
        case .savedToDrafts:
            return "Email saved to Drafts"
        case .sentByUser:
            return "Email sent"
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }
    
    var isSuccess: Bool {
        switch self {
        case .sentByUser, .savedToDrafts:
            return true
        case .cancelled, .failed:
            return false
        }
    }
    
    static func == (lhs: MailComposeResult, rhs: MailComposeResult) -> Bool {
        switch (lhs, rhs) {
        case (.cancelled, .cancelled):
            return true
        case (.savedToDrafts, .savedToDrafts):
            return true
        case (.sentByUser, .sentByUser):
            return true
        case (.failed(let l), .failed(let r)):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - SwiftUI View Representable

/// SwiftUI wrapper for presenting mail composer with Draft
private struct DraftMailComposerView: UIViewControllerRepresentable {
    let draft: Draft
    let onDismiss: (MailComposeResult) -> Void
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        
        // Populate draft content
        if let recipient = draft.content.recipient {
            composer.setToRecipients([recipient])
        }
        
        if let subject = draft.content.subject {
            composer.setSubject(subject)
        }
        
        var body = draft.content.body
        if let signature = draft.content.signature {
            body += "\n\n\(signature)"
        }
        composer.setMessageBody(body, isHTML: false)
        
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: DraftMailComposerView
        
        init(_ parent: DraftMailComposerView) {
            self.parent = parent
        }
        
        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            let composeResult: MailComposeResult
            
            switch result {
            case .cancelled:
                composeResult = .cancelled
            case .saved:
                composeResult = .savedToDrafts
            case .sent:
                composeResult = .sentByUser
            case .failed:
                composeResult = .failed(reason: error?.localizedDescription ?? "Unknown error")
            @unknown default:
                composeResult = .failed(reason: "Unknown result")
            }
            
            parent.onDismiss(composeResult)
        }
    }
}

// MARK: - Mail Composer Sheet Modifier

struct MailComposerSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let draft: Draft?
    let onResult: (MailComposeResult) -> Void
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                if let draft = draft, MFMailComposeViewController.canSendMail() {
                    DraftMailComposerView(draft: draft) { result in
                        isPresented = false
                        onResult(result)
                    }
                    .ignoresSafeArea()
                } else {
                    // Fallback if mail is not available
                    VStack(spacing: 20) {
                        Image(systemName: "envelope.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("Mail Not Available")
                            .font(.headline)
                        
                        Text("Please configure a mail account in Settings to send emails.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Button("Dismiss") {
                            isPresented = false
                            onResult(.failed(reason: "Mail not configured"))
                        }
                        .padding()
                    }
                    .padding(40)
                }
            }
    }
}

extension View {
    func mailComposerSheet(
        isPresented: Binding<Bool>,
        draft: Draft?,
        onResult: @escaping (MailComposeResult) -> Void
    ) -> some View {
        modifier(MailComposerSheetModifier(isPresented: isPresented, draft: draft, onResult: onResult))
    }
}
