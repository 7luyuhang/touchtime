//
//  LifetimeStoreView.swift
//  touchtime
//
//  Created on 01/03/2026.
//

import SwiftUI
import StoreKit
import UIKit
import Shimmer

struct LifetimeStoreView: View {
    private static let productID = "com.time.lifetime"

    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasLifetimeAccess") private var hasLifetimeAccess = false
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @State private var product: Product?
    @State private var purchaseState: PurchaseState = .loading
    @State private var isRestoring = false

    enum PurchaseState: Equatable {
        case idle
        case loading
        case purchasing
    }

    var body: some View {
        ZStack {
            
            ParticleView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .opacity(0.75)
                .blendMode(.plusLighter)

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 16) {
                        Text(String(localized: "Unlock the experience with all complications, available time, and more."))
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        if purchaseState == .loading {
                            ProgressView()
                                .padding()
                        }
                        
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height, alignment: .center)
                }
            }
        }
        .task {
            await refreshLifetimeStatus()
            guard !hasLifetimeAccess else {
                dismiss()
                return
            }
            await loadProduct()
        }
        .task {
            for await result in Transaction.updates {
                do {
                    let transaction = try checkVerified(result)

                    if transaction.productID == Self.productID {
                        await refreshLifetimeStatus()
                    }

                    await transaction.finish()
                } catch {
                    print("Failed to process transaction update: \(error)")
                }
            }
        }
        .onChange(of: hasLifetimeAccess) { _, newValue in
            if newValue {
                dismiss()
            }
        }
        .presentationDetents([.medium])
        .safeAreaInset(edge: .bottom) {
            bottomActions
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if hapticEnabled {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var bottomActions: some View {
        VStack(spacing: 16) {
            purchaseButton
            footerActions
        }
        .padding(.horizontal, 24)
    }

    private var purchaseButton: some View {
        Group {
            if purchaseState == .purchasing {
                ProgressView() // Purchasing Loading Button
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .glassEffect(.clear.tint(.white.opacity(0.10)), in: Capsule(style: .continuous))
                
            } else if let product {
                Button {
                    if hapticEnabled {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                    
                    Task {
                        await purchase(product)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Lifetime")
                            .font(.headline)
                        Text(product.displayPrice)
                            .font(.headline)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .contentShape(Capsule(style: .continuous))
                    .glassEffect(.clear.tint(.white), in: Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(purchaseState == .purchasing)
            }
        }
    }

    // Footer Actions
    private var footerActions: some View {
        HStack(spacing: 6) {
            Link(String(localized: "Privacy Policy"), destination: URL(string: "https://www.handstime.app/privacy")!)
                .buttonStyle(.plain)

            Text("·")
                .foregroundStyle(.secondary)

            Button {
                if hapticEnabled {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }

                Task {
                    await restorePurchases()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(String(localized: "Restore Purchases"))

                    if isRestoring {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isRestoring)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .blendMode(.plusLighter)
    }

    @MainActor
    private func loadProduct() async {
        purchaseState = .loading

        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
            purchaseState = product == nil
            ? .idle
            : .idle
            if product == nil {
                print("Unable to load lifetime option.")
            }
        } catch {
            print("Failed to load lifetime product: \(error)")
            print("Unable to load lifetime option.")
            purchaseState = .idle
        }
    }

    @MainActor
    private func purchase(_ product: Product) async {
        guard purchaseState != .purchasing else { return }

        purchaseState = .purchasing

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                do {
                    let transaction = try checkVerified(verification)
                    await transaction.finish()
                    await refreshLifetimeStatus()
                    purchaseState = .idle
                } catch {
                    print("Transaction verification failed: \(error)")
                    print("Transaction couldn't be verified.")
                    purchaseState = .idle
                }

            case .pending:
                print("Purchase is pending approval.")
                purchaseState = .idle

            case .userCancelled:
                purchaseState = .idle

            @unknown default:
                purchaseState = .idle
            }
        } catch {
            print("Purchase error: \(error)")
            print("Purchase failed. Please try again.")
            purchaseState = .idle
        }
    }

    @MainActor
    private func restorePurchases() async {
        guard !isRestoring else { return }

        isRestoring = true

        do {
            try await AppStore.sync()
            await refreshLifetimeStatus()
            if hasLifetimeAccess {
                dismiss()
                return
            }
            print("No lifetime purchase found.")
        } catch {
            print("Failed to restore purchases: \(error)")
        }

        isRestoring = false
    }

    @MainActor
    private func refreshLifetimeStatus() async {
        var isUnlocked = false

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                guard transaction.revocationDate == nil else { continue }

                if transaction.productID == Self.productID {
                    isUnlocked = true
                    break
                }
            } catch {
                print("Failed to verify lifetime entitlement: \(error)")
            }
        }

        hasLifetimeAccess = isUnlocked
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
