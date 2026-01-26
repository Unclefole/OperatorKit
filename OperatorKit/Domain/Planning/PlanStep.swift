import Foundation

/// A single step in an execution plan
struct PlanStep: Identifiable, Equatable {
    let id: UUID
    let stepNumber: Int
    let title: String
    let description: String
    let requiresPermission: PermissionType?
    let estimatedConfidence: Double
    
    enum PermissionType: String {
        case calendar = "Calendar Access"
        case email = "Email Access"
        case files = "File Access"
        case reminders = "Reminders Access"
        case contacts = "Contacts Access"
    }
    
    init(
        id: UUID = UUID(),
        stepNumber: Int,
        title: String,
        description: String,
        requiresPermission: PermissionType? = nil,
        estimatedConfidence: Double = 0.9
    ) {
        self.id = id
        self.stepNumber = stepNumber
        self.title = title
        self.description = description
        self.requiresPermission = requiresPermission
        self.estimatedConfidence = estimatedConfidence
    }
}
