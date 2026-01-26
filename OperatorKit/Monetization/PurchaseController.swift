import Foundation
import StoreKit

// ============================================================================
// PURCHASE CONTROLLER (Phase 10A)
//
// Handles purchase and restore flows using StoreKit 2.
// Exposes async status and maps errors to user-facing messages.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No "smart" copy or hype language
// ❌ No networking beyond StoreKit
// ❌ Does not affect execution behavior
// ✅ Plain error messages
// ✅ Local-only verification
//
// See: docs/SAFETY_CONTRACT.md (unchanged)
// ============================================================================

/// Controller for purchase operations
@MainActor
public final class PurchaseController: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = PurchaseController()
    
    // MARK: - Dependencies
    
    private let entitlementManager: EntitlementManager
    
    // MARK: - Published State
    
    @Published public private(set) var purchaseState: PurchaseState = .idle
    
    // MARK: - Initialization
    
    private init(entitlementManager: EntitlementManager = .shared) {
        self.entitlementManager = entitlementManager
    }
    
    // MARK: - Purchase
    
    /// Purchases a product
    /// - Parameter product: The StoreKit Product to purchase
    /// - Returns: Whether the purchase was successful
    @discardableResult
    public func purchase(_ product: Product) async -> Bool {
        purchaseState = .purchasing
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    // Finish the transaction
                    await transaction.finish()
                    
                    // Update entitlements
                    _ = await entitlementManager.checkCurrentEntitlements()
                    
                    purchaseState = .success(productId: product.id)
                    logDebug("Purchase successful: \(product.id)", category: .monetization)
                    return true
                    
                case .unverified(_, let error):
                    purchaseState = .failed(message: "Could not verify purchase. Please try again.")
                    logError("Purchase verification failed: \(error.localizedDescription)", category: .monetization)
                    return false
                }
                
            case .userCancelled:
                purchaseState = .cancelled
                logDebug("Purchase cancelled by user", category: .monetization)
                return false
                
            case .pending:
                // Transaction needs approval (e.g., Ask to Buy)
                purchaseState = .idle
                logDebug("Purchase pending approval", category: .monetization)
                return false
                
            @unknown default:
                purchaseState = .failed(message: "An unexpected error occurred.")
                return false
            }
            
        } catch StoreKitError.userCancelled {
            purchaseState = .cancelled
            return false
            
        } catch {
            purchaseState = .failed(message: mapErrorToUserMessage(error))
            logError("Purchase failed: \(error.localizedDescription)", category: .monetization)
            return false
        }
    }
    
    /// Purchases a product by ID
    /// - Parameter productId: The product identifier
    /// - Returns: Whether the purchase was successful
    @discardableResult
    public func purchase(productId: String) async -> Bool {
        guard let product = entitlementManager.product(for: productId) else {
            purchaseState = .failed(message: "Product not available. Please try again later.")
            return false
        }
        
        return await purchase(product)
    }
    
    // MARK: - Restore
    
    /// Restores previous purchases
    /// - Returns: Whether restore was successful
    @discardableResult
    public func restore() async -> Bool {
        purchaseState = .restoring
        
        do {
            try await entitlementManager.restorePurchases()
            
            // Check if we now have an active subscription
            if entitlementManager.isPro {
                purchaseState = .success(productId: entitlementManager.status.productId ?? "restored")
                return true
            } else {
                // No active subscription found, but restore completed
                purchaseState = .idle
                return true
            }
            
        } catch {
            purchaseState = .failed(message: "Could not restore purchases. Please try again.")
            logError("Restore failed: \(error.localizedDescription)", category: .monetization)
            return false
        }
    }
    
    // MARK: - State Management
    
    /// Resets the purchase state to idle
    public func resetState() {
        purchaseState = .idle
    }
    
    /// Clears any error state
    public func clearError() {
        if case .failed = purchaseState {
            purchaseState = .idle
        }
    }
    
    // MARK: - Error Mapping
    
    /// Maps StoreKit errors to plain user-facing messages
    /// No hype, no "smart" copy — just facts
    private func mapErrorToUserMessage(_ error: Error) -> String {
        if let storeKitError = error as? StoreKitError {
            switch storeKitError {
            case .userCancelled:
                return "" // Don't show message for cancellation
            case .networkError:
                return "Could not connect to the App Store. Check your connection and try again."
            case .systemError:
                return "A system error occurred. Please try again."
            case .notAvailableInStorefront:
                return "This product is not available in your region."
            case .notEntitled:
                return "You are not entitled to this product."
            @unknown default:
                return "Purchase could not be completed."
            }
        }
        
        // Generic error
        return "Purchase could not be completed."
    }
}

// MARK: - Purchase Result Helpers

extension PurchaseController {
    
    /// Whether a purchase or restore is in progress
    public var isProcessing: Bool {
        purchaseState.isLoading
    }
    
    /// Current error message, if any
    public var errorMessage: String? {
        purchaseState.errorMessage
    }
    
    /// Whether the last operation was successful
    public var wasSuccessful: Bool {
        if case .success = purchaseState {
            return true
        }
        return false
    }
}
