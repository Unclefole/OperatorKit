import Foundation
import StoreKit

// ============================================================================
// ENTITLEMENT MANAGER (Phase 10A)
//
// StoreKit 2 wrapper for local-only entitlement resolution.
// Determines subscription tier from on-device transaction data.
//
// CONSTRAINTS (ABSOLUTE):
// ❌ No networking beyond StoreKit
// ❌ No accounts or server receipts
// ❌ No crash on StoreKit errors (fail closed to .free)
// ❌ Does not affect execution behavior
// ✅ Local-only verification
// ✅ Cached status with re-check on app launch
//
// See: docs/SAFETY_CONTRACT.md (unchanged)
// ============================================================================

/// Manages subscription entitlements using StoreKit 2
@MainActor
public final class EntitlementManager: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = EntitlementManager()
    
    // MARK: - Published State
    
    @Published public private(set) var status: SubscriptionStatus = .free
    @Published public private(set) var products: [Product] = []
    @Published public private(set) var isLoading: Bool = false
    
    // MARK: - Storage
    
    private let statusStorageKey = "com.operatorkit.subscriptionStatus"
    private let defaults: UserDefaults
    
    // MARK: - Transaction Listener
    
    private var transactionListener: Task<Void, Error>?
    
    // MARK: - Initialization
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadCachedStatus()
        startTransactionListener()
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Fetch Products

    /// Tracks the last fetch error for diagnostics
    @Published public private(set) var lastFetchError: String?

    /// Whether products failed to load (not just empty)
    @Published public private(set) var productsFetchFailed: Bool = false

    /// Fetches products from the App Store
    public func fetchProducts() async {
        isLoading = true
        lastFetchError = nil
        productsFetchFailed = false
        defer { isLoading = false }

        let requestedIds = StoreKitProductIDs.allProducts
        logDebug("StoreKit: Requesting \(requestedIds.count) products: \(requestedIds.joined(separator: ", "))", category: .monetization)

        do {
            let storeProducts = try await Product.products(for: requestedIds)

            // Sort by display order
            products = storeProducts.sorted { first, second in
                let firstIndex = StoreKitProductIDs.displayOrder.firstIndex(of: first.id) ?? Int.max
                let secondIndex = StoreKitProductIDs.displayOrder.firstIndex(of: second.id) ?? Int.max
                return firstIndex < secondIndex
            }

            // Structured logging
            if products.isEmpty {
                logError("StoreKit: Product.products returned EMPTY array", category: .monetization)
                logError("StoreKit: Check App Store Connect: 1) Products exist 2) Ready for Sale 3) Bundle ID matches 4) Agreements signed", category: .monetization)
                lastFetchError = "No products returned from App Store"
                productsFetchFailed = true
                // NOTE: No assertion - empty products is expected before App Store Connect setup
            } else {
                logDebug("StoreKit: Successfully fetched \(products.count) products:", category: .monetization)
                for product in products {
                    logDebug("  - \(product.id): \(product.displayName) @ \(product.displayPrice)", category: .monetization)
                }
            }
        } catch {
            products = []
            productsFetchFailed = true
            lastFetchError = error.localizedDescription

            logError("StoreKit: Product fetch FAILED: \(error.localizedDescription)", category: .monetization)
            logError("StoreKit: Error type: \(type(of: error))", category: .monetization)

            // More specific error logging
            if let storeKitError = error as? StoreKitError {
                switch storeKitError {
                case .networkError(let underlying):
                    logError("StoreKit: Network error - \(underlying.localizedDescription)", category: .monetization)
                case .systemError(let underlying):
                    logError("StoreKit: System error - \(underlying.localizedDescription)", category: .monetization)
                case .notAvailableInStorefront:
                    logError("StoreKit: Products not available in this storefront", category: .monetization)
                default:
                    logError("StoreKit: Other StoreKit error", category: .monetization)
                }
            }
            // NOTE: No assertion - network failures are expected in development
        }
    }
    
    // MARK: - Check Current Entitlements
    
    /// Checks current entitlements from StoreKit
    /// - Returns: Current subscription status
    public func checkCurrentEntitlements() async -> SubscriptionStatus {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Check for active subscription entitlements
            // Prioritize Team > Pro > Free
            var foundTeam: (String, Date?)? = nil
            var foundPro: (String, Date?)? = nil
            
            for await result in Transaction.currentEntitlements {
                switch result {
                case .verified(let transaction):
                    if StoreKitProductIDs.isTeamSubscription(transaction.productID) {
                        // Found active Team subscription
                        foundTeam = (transaction.productID, transaction.expirationDate)
                    } else if StoreKitProductIDs.isProSubscription(transaction.productID) {
                        // Found active Pro subscription
                        foundPro = (transaction.productID, transaction.expirationDate)
                    }
                    
                case .unverified(_, let error):
                    logWarning("Unverified transaction: \(error.localizedDescription)", category: .monetization)
                    // Continue checking other transactions
                }
            }
            
            // Return highest tier found
            if let (productId, renewalDate) = foundTeam {
                let newStatus = SubscriptionStatus.team(
                    productId: productId,
                    renewalDate: renewalDate
                )
                updateStatus(newStatus)
                logDebug("Found active Team subscription: \(productId)", category: .monetization)
                return newStatus
            }
            
            if let (productId, renewalDate) = foundPro {
                let newStatus = SubscriptionStatus.pro(
                    productId: productId,
                    renewalDate: renewalDate
                )
                updateStatus(newStatus)
                logDebug("Found active Pro subscription: \(productId)", category: .monetization)
                return newStatus
            }
            
            // No active subscription found
            let freeStatus = SubscriptionStatus.free
            updateStatus(freeStatus)
            logDebug("No active subscription found, tier: free", category: .monetization)
            return freeStatus
            
        } catch {
            logError("Error checking entitlements: \(error.localizedDescription)", category: .monetization)
            // Fail closed to free tier
            let freeStatus = SubscriptionStatus.free
            updateStatus(freeStatus)
            return freeStatus
        }
    }
    
    /// Refreshes subscription status (call on app launch)
    public func refreshStatus() async {
        _ = await checkCurrentEntitlements()
    }
    
    // MARK: - Restore Purchases
    
    /// Restores purchases from the App Store
    public func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Sync with App Store
            try await AppStore.sync()
            
            // Re-check entitlements
            _ = await checkCurrentEntitlements()
            
            logDebug("Purchases restored successfully", category: .monetization)
        } catch {
            logError("Failed to restore purchases: \(error.localizedDescription)", category: .monetization)
            throw SubscriptionError.purchaseFailed(underlying: error)
        }
    }
    
    // MARK: - Transaction Listener
    
    /// Starts listening for transaction updates
    private func startTransactionListener() {
        transactionListener = Task.detached { [weak self] in
            for await result in Transaction.updates {
                await self?.handleTransactionUpdate(result)
            }
        }
    }
    
    /// Handles a transaction update
    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            // Finish the transaction
            await transaction.finish()
            
            // Re-check entitlements
            _ = await checkCurrentEntitlements()
            
            logDebug("Transaction update processed: \(transaction.productID)", category: .monetization)
            
        case .unverified(_, let error):
            logWarning("Unverified transaction update: \(error.localizedDescription)", category: .monetization)
        }
    }
    
    // MARK: - Status Persistence
    
    /// Loads cached status from UserDefaults
    private func loadCachedStatus() {
        guard let data = defaults.data(forKey: statusStorageKey) else {
            status = .free
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            status = try decoder.decode(SubscriptionStatus.self, from: data)
            logDebug("Loaded cached subscription status: \(status.tier)", category: .monetization)
        } catch {
            logError("Failed to decode cached status: \(error.localizedDescription)", category: .monetization)
            status = .free
        }
    }
    
    /// Updates and persists status
    private func updateStatus(_ newStatus: SubscriptionStatus) {
        status = newStatus
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(newStatus)
            defaults.set(data, forKey: statusStorageKey)
        } catch {
            logError("Failed to cache subscription status: \(error.localizedDescription)", category: .monetization)
        }
    }
    
    // MARK: - Convenience
    
    /// Current subscription tier
    public var currentTier: SubscriptionTier {
        status.tier
    }
    
    /// Whether user has Pro subscription
    public var isPro: Bool {
        (status.tier == .pro || status.tier == .team) && status.isActive
    }
    
    /// Whether user has Team subscription (Phase 10E)
    public var isTeam: Bool {
        status.tier == .team && status.isActive
    }
    
    /// Whether user has team features (Phase 10E)
    public var hasTeamFeatures: Bool {
        status.tier.hasTeamFeatures && status.isActive
    }
    
    /// Whether user has cloud sync (Phase 10D)
    public var hasCloudSync: Bool {
        status.tier.hasCloudSync && status.isActive
    }
    
    /// Get product by ID
    public func product(for productId: String) -> Product? {
        products.first { $0.id == productId }
    }
}

