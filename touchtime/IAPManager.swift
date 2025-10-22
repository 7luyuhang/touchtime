//
//  IAPManager.swift
//  touchtime
//
//  Created on 23/10/2025.
//

import SwiftUI
import Combine
import StoreKit

// MARK: - IAP Manager for Tips
@MainActor
class IAPManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchaseState: PurchaseState = .idle
    @Published var hasCompletedPurchase = false
    
    private let productID = "com.time.tip.small"
    private var updateListenerTask: Task<Void, Never>? = nil
    
    enum PurchaseState: Equatable {
        case idle
        case loading
        case purchasing
        case success(String)
        case failed(String)
    }
    
    init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        Task {
            await fetchProducts()
            await updatePurchaseStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // Fetch products from App Store
    @MainActor
    func fetchProducts() async {
        purchaseState = .loading
        do {
            let products = try await Product.products(for: [productID])
            self.products = products
            purchaseState = .idle
        } catch {
            print("Failed to fetch products: \(error)")
            purchaseState = .failed("Unable to load tip options")
        }
    }
    
    // Purchase product
    @MainActor
    func purchase(_ product: Product) async {
        purchaseState = .purchasing
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Verify the transaction
                do {
                    let transaction = try checkVerified(verification)
                    // Transaction successfully verified
                    await transaction.finish()
                    await updatePurchaseStatus()
                    purchaseState = .success("Thank you for your support.")
                    
                    // Reset state after 3 seconds
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        purchaseState = .idle
                    }
                } catch {
                    // Transaction failed verification
                    purchaseState = .failed("Transaction couldn't be verified")
                    print("Transaction verification failed: \(error)")
                }
                
            case .pending:
                // Transaction is pending (e.g., waiting for parental approval)
                purchaseState = .idle
                
            case .userCancelled:
                // User cancelled the purchase
                purchaseState = .idle
                
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed("Purchase failed. Please try again.")
            print("Purchase error: \(error)")
        }
    }
    
    // Get formatted price for product
    func formattedPrice(for product: Product) -> String {
        product.displayPrice
    }
    
    // Listen for transaction updates
    private func listenForTransactions() -> Task<Void, Never> {
        return Task.detached {
            // Iterate through any transactions that don't come from a direct call to `purchase()`
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    
                    // Deliver products to the user
                    await self.updatePurchaseStatus()
                    
                    // Always finish a transaction
                    await transaction.finish()
                } catch {
                    // StoreKit has a transaction that fails verification
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }
    
    // Update purchase status based on current entitlements
    @MainActor
    func updatePurchaseStatus() async {
        var hasActivePurchase = false
        
        // Check for existing purchases
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productID == productID {
                    hasActivePurchase = true
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }
        
        hasCompletedPurchase = hasActivePurchase
    }
    
    // Verify transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
