//
//  TipJarSection.swift
//  touchtime
//
//  Created on 22/10/2025.
//

import SwiftUI
import StoreKit

struct TipJarSection: View {
    @StateObject private var iapManager = IAPManager()
    
    var body: some View {
        Section {
            if iapManager.purchaseState == .loading {
                HStack {
                    ProgressView()
                    Text("Loading...")
                        .foregroundStyle(.secondary)
                }
            } else if !iapManager.products.isEmpty {
                ForEach(iapManager.products, id: \.id) { product in
                    TipButton(product: product, iapManager: iapManager)
                }
            } else {
                Text("Unable to load tip options")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Support")
        }
    }
}

struct TipButton: View {
    let product: Product
    let iapManager: IAPManager
    
    var tipInfo: (name: String, iconColor: (top: Color, bottom: Color)) {
        switch product.id {
        case "com.time.tip.small":
            return ("Small Tip", (top: .red, bottom: .pink))
        case "com.time.tip.medium":
            return ("Medium Tip", (top: .blue, bottom: .cyan))
        case "com.time.tip.large":
            return ("Large Tip", (top: .yellow, bottom: .orange))
        default:
            return ("Tip", (top: .red, bottom: .pink))
        }
    }
    
    var body: some View {
        HStack {
            HStack(spacing: 12) {
                SystemIconImage(
                    systemName: "heart.fill",
                    topColor: tipInfo.iconColor.top,
                    bottomColor: tipInfo.iconColor.bottom
                )
                Text(tipInfo.name)
                    .tint(.primary)
            }
            
            Spacer()
            
            if iapManager.purchaseState == .purchasing {
                ProgressView()
            } else {
                Button(action: {
                    Task {
                        await iapManager.purchase(product)
                    }
                }) {
                    Text(iapManager.formattedPrice(for: product))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.clear.interactive())
                }
                .disabled(iapManager.purchaseState == .purchasing)
            }
        }
    }
}
