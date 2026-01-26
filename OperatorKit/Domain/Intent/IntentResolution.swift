import Foundation

/// Result of resolving an intent with confidence
struct IntentResolution {
    let request: IntentRequest
    let confidence: Double
    let suggestedWorkflow: String?
    
    var isHighConfidence: Bool {
        confidence >= 0.8
    }
    
    var isMediumConfidence: Bool {
        confidence >= 0.5 && confidence < 0.8
    }
    
    var isLowConfidence: Bool {
        confidence < 0.5
    }
}
