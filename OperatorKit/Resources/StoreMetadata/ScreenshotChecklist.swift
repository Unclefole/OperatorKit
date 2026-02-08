import Foundation

// ============================================================================
// SCREENSHOT CHECKLIST (Phase 10J)
//
// Screenshot requirements and caption templates for App Store submission.
// All captions are generic and content-free.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No user content in captions
// ❌ No specific names, emails, or events
// ❌ No identifiable information
// ✅ Generic, illustrative captions
// ✅ Content-free templates
//
// See: docs/APP_STORE_SUBMISSION_CHECKLIST.md
// ============================================================================

// MARK: - Screenshot Checklist

public enum ScreenshotChecklist {
    
    // MARK: - Device Sizes
    
    /// Required screenshot sizes
    public static let requiredSizes: [ScreenshotSize] = [
        ScreenshotSize(
            name: "iPhone 6.7\"",
            displayName: "iPhone 15 Pro Max / 15 Plus / 14 Pro Max",
            pixelSize: "1290 x 2796",
            required: true
        ),
        ScreenshotSize(
            name: "iPhone 6.5\"",
            displayName: "iPhone 14 Plus / 13 Pro Max / 12 Pro Max / 11 Pro Max / XS Max",
            pixelSize: "1284 x 2778",
            required: true
        ),
        ScreenshotSize(
            name: "iPhone 5.5\"",
            displayName: "iPhone 8 Plus / 7 Plus / 6s Plus",
            pixelSize: "1242 x 2208",
            required: false // Optional but recommended
        )
    ]
    
    // MARK: - Screenshot Shots
    
    /// Required screenshots in order
    public static let requiredShots: [ScreenshotShot] = [
        ScreenshotShot(
            order: 1,
            name: "Onboarding",
            scene: "First onboarding screen",
            captionTemplate: "Your on-device productivity assistant",
            notes: "Show welcome screen with app icon and tagline"
        ),
        ScreenshotShot(
            order: 2,
            name: "Intent Input",
            scene: "Intent input with sample request",
            captionTemplate: "Type any request in plain language",
            notes: "Use generic sample: 'Draft an email about tomorrow's meeting'"
        ),
        ScreenshotShot(
            order: 3,
            name: "Draft Review",
            scene: "Draft being reviewed",
            captionTemplate: "Review every action before it runs",
            notes: "Show draft card with placeholder content"
        ),
        ScreenshotShot(
            order: 4,
            name: "Approval",
            scene: "Approval confirmation",
            captionTemplate: "You're always in control",
            notes: "Show approval dialog with Run/Edit/Cancel options"
        ),
        ScreenshotShot(
            order: 5,
            name: "Memory",
            scene: "Saved items list",
            captionTemplate: "Remember your preferences",
            notes: "Show memory list with generic items"
        ),
        ScreenshotShot(
            order: 6,
            name: "Quality & Trust",
            scene: "Quality dashboard",
            captionTemplate: "Verify what runs on your device",
            notes: "Show quality metrics without specific data"
        ),
        ScreenshotShot(
            order: 7,
            name: "Pricing",
            scene: "Pricing screen",
            captionTemplate: "Start free, upgrade anytime",
            notes: "Show all three tiers with clear pricing"
        ),
        ScreenshotShot(
            order: 8,
            name: "Help Center",
            scene: "Help & Support",
            captionTemplate: "Help when you need it",
            notes: "Show FAQ list or support options"
        )
    ]
    
    // MARK: - Caption Validation
    
    /// Forbidden content in captions
    public static let forbiddenCaptionContent: [String] = [
        "@", // Email addresses
        ".com",
        "John",
        "Jane",
        "Smith",
        "example",
        "test",
        "demo",
        "fake",
        "sample@",
        "user@"
    ]
    
    /// Validates all captions
    public static func validateCaptions() -> [String] {
        var violations: [String] = []
        
        for shot in requiredShots {
            for forbidden in forbiddenCaptionContent {
                if shot.captionTemplate.lowercased().contains(forbidden.lowercased()) {
                    violations.append("Caption '\(shot.name)' contains forbidden content: '\(forbidden)'")
                }
            }
            
            // Check PricingCopy banned words
            let copyViolations = PricingCopy.validate(shot.captionTemplate)
            for violation in copyViolations {
                violations.append("Caption '\(shot.name)': \(violation)")
            }
        }
        
        return violations
    }
    
    // MARK: - Checklist Generation
    
    /// Generates printable checklist
    public static func generateChecklist() -> String {
        var result = """
        ============================================================
        OPERATORKIT SCREENSHOT CHECKLIST
        ============================================================
        
        REQUIRED SIZES:
        
        """
        
        for size in requiredSizes {
            let marker = size.required ? "[REQUIRED]" : "[OPTIONAL]"
            result += """
            \(marker) \(size.name)
                Device: \(size.displayName)
                Pixels: \(size.pixelSize)
            
            """
        }
        
        result += """
        
        ============================================================
        SCREENSHOTS (in order)
        ============================================================
        
        """
        
        for shot in requiredShots {
            result += """
            \(shot.order). \(shot.name)
               Scene: \(shot.scene)
               Caption: "\(shot.captionTemplate)"
               Notes: \(shot.notes)
            
            """
        }
        
        result += """
        
        ============================================================
        CONTENT GUIDELINES
        ============================================================
        
        DO:
        ✓ Use generic, illustrative content
        ✓ Show app features clearly
        ✓ Keep captions short and factual
        ✓ Use consistent styling
        
        DON'T:
        ✗ Include real names or emails
        ✗ Show identifiable information
        ✗ Use hype language
        ✗ Make security claims
        
        ============================================================
        """
        
        return result
    }
}

// MARK: - Screenshot Size

public struct ScreenshotSize {
    public let name: String
    public let displayName: String
    public let pixelSize: String
    public let required: Bool
}

// MARK: - Screenshot Shot

public struct ScreenshotShot {
    public let order: Int
    public let name: String
    public let scene: String
    public let captionTemplate: String
    public let notes: String
}

// MARK: - Screenshot Status

public struct ScreenshotStatus {
    public let size: ScreenshotSize
    public let shots: [ShotStatus]
    
    public var completedCount: Int {
        shots.filter { $0.isComplete }.count
    }
    
    public var totalCount: Int {
        shots.count
    }
    
    public var isComplete: Bool {
        completedCount == totalCount
    }
}

public struct ShotStatus {
    public let shot: ScreenshotShot
    public let isComplete: Bool
    public let notes: String?
}
