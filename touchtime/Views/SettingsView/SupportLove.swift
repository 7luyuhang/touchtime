//
//  TipJarSection.swift
//  touchtime
//
//  Created on 22/10/2025.
//

import SwiftUI
import StoreKit
import UIKit
import Shimmer

// Circular glass icon for Tip Jar, optionally filled with a color
struct CircularTipIcon: View {
    let systemName: String
    var fill: Color = .clear
    
    var body: some View {
        ZStack {
            Circle()
                .fill(fill)
                .frame(width: 28, height: 28)
                .glassEffect(.clear, in: Circle())
                
            Image(systemName: systemName)
                .font(.system(size: 15))
                .fontWeight(.medium)
                .foregroundStyle(.white)
        }
    }
}

// Main Tip Jar View for navigation
struct TipJarView: View {
    @StateObject private var iapManager = IAPManager()
    @Environment(\.dismiss) private var dismiss
    @State private var showExpandedFeatures = false
    @State private var heartBurst = 0
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    
    private static let heartEmojis = ["❤️", "🧡", "💛", "💚", "🩵", "💙", "💜", "🩷"]
    
    var body: some View {
        ZStack{
            
            // Pink to Black Gradient Background
            LinearGradient(colors: [.pink.opacity(0.25), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    heartEmblem
                    
                    Text(String(localized: "Thank you for your attention, love you. Your support means the world."))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 16)
                    
                    
                    if iapManager.purchaseState == .loading {
                        HStack {
                            ProgressView()
                        }
                        .padding()
                        .glassEffect(.clear)
                        
                    } else if !iapManager.products.isEmpty {
                        // Small Tip HStack
                        if let smallTip = iapManager.products.first(where: { $0.id == "com.time.tip.small" }) {
                            HStack {
                                HStack(spacing: 12) {
                                    CircularTipIcon(systemName: "heart.fill")
                                    Text(String(localized: "Small Tip"))
                                        .foregroundStyle(.primary)
                                }
                                
                                Spacer()
                                
                                if iapManager.purchaseState == .purchasing {
                                    ProgressView()
                                        .padding(.vertical, 8)
                                        .blendMode(.plusLighter)
                                } else {
                                    Button(action: {
                                        if hapticEnabled {
                                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                            impactFeedback.impactOccurred()
                                        }
                                        Task {
                                            await iapManager.purchase(smallTip)
                                        }
                                    }) {
                                        Text(iapManager.formattedPrice(for: smallTip))
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .glassEffect(.clear.interactive())
                                    }
                                    .disabled(iapManager.purchaseState == .purchasing)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.black.opacity(0.25))
                                    .glassEffect(.clear, in: Capsule(style: .continuous))
                            )
                        }
                        
                        // Medium Tip HStack
                        if let mediumTip = iapManager.products.first(where: { $0.id == "com.time.tip.medium" }) {
                            HStack {
                                HStack(spacing: 12) {
                                    CircularTipIcon(systemName: "heart.fill")
                                    Text(String(localized: "Medium Tip"))
                                        .foregroundStyle(.primary)
                                }
                                
                                Spacer()
                                
                                if iapManager.purchaseState == .purchasing {
                                    ProgressView()
                                        .padding(.vertical, 8)
                                        .blendMode(.plusLighter)
                                } else {
                                    Button(action: {
                                        if hapticEnabled {
                                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                            impactFeedback.impactOccurred()
                                        }
                                        Task {
                                            await iapManager.purchase(mediumTip)
                                        }
                                    }) {
                                        Text(iapManager.formattedPrice(for: mediumTip))
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .glassEffect(.clear.interactive())
                                    }
                                    .disabled(iapManager.purchaseState == .purchasing)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.black.opacity(0.25))
                                    .glassEffect(.clear, in: Capsule(style: .continuous))
                            )
                        }
                        
                        // Large Tip HStack (Hidden initially, shown when expanded)
                        if showExpandedFeatures {
                            if let largeTip = iapManager.products.first(where: { $0.id == "com.time.tip.large" }) {
                                HStack {
                                    HStack(spacing: 12) {
                                        CircularTipIcon(systemName: "heart.fill", fill: .pink.opacity(0.5))
                                        Text(String(localized: "Large Tip"))
                                            .foregroundStyle(.primary)
                                    }
                                    
                                    Spacer()
                                    
                                    if iapManager.purchaseState == .purchasing {
                                        ProgressView()
                                            .padding(.vertical, 8)
                                            .blendMode(.plusLighter)
                                    } else {
                                        Button(action: {
                                            if hapticEnabled {
                                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                                impactFeedback.impactOccurred()
                                            }
                                            Task {
                                                await iapManager.purchase(largeTip)
                                            }
                                        }) {
                                            Text(iapManager.formattedPrice(for: largeTip))
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .glassEffect(.clear.interactive())
                                        }
                                        .disabled(iapManager.purchaseState == .purchasing)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                // Hearts rise out of the row and blur out over the tip
                                // above, fully dissolved before the top of their frame
                                .background(alignment: .bottom) {
                                    EmojiParticlesView(
                                        emojis: Self.heartEmojis,
                                        burst: heartBurst,
                                        dissolveDistance: 72
                                    )
                                    .frame(height: 180)
                                    .clipped()
                                }
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.pink.opacity(0.5))
                                        .glassEffect(.clear, in: Capsule(style: .continuous))
                                )
                                .transition(.blurReplace.combined(with: .move(edge: .top)).combined(with: .scale))
                                
                            }
                        }
                        
                        // Explore More Button - Always at the bottom
                        Button(action: {
                            
                            // Add soft haptic feedback
                            if hapticEnabled {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                                impactFeedback.impactOccurred()
                            }
                            
                            withAnimation(.bouncy()) {
                                showExpandedFeatures.toggle()
                            }
                        }) {
                            HStack(spacing: 10) {
                                Group {
                                    if showExpandedFeatures {
                                        Text(String(localized: "Show Less"))
                                            .font(.subheadline.weight(.semibold))
                                            .transition(.blurReplace())
                                    } else {
                                        Text(String(localized: "Support More"))
                                            .font(.subheadline.weight(.semibold))
                                            .transition(.blurReplace())
                                            .shimmering(
                                                animation: .easeInOut(duration: 1.5).repeatForever(autoreverses: false)
                                            )
                                            .blendMode(.plusLighter)
                                    }
                                }
                                .id(showExpandedFeatures)
                                
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .blendMode(.plusLighter)
                                    .rotationEffect(.degrees(showExpandedFeatures ? -90 : 0))
                            }
                            .foregroundStyle(.white)
                            .padding(.vertical, 15)
                            .padding(.horizontal, 20)
                            .clipShape(.capsule)
                            .glassEffect(.clear.interactive())
                        }
                        .buttonStyle(.plain)
                        
                        // Unable Loading
                    } else {
                        HStack {
                            ProgressView()
                        }
                        .padding()
                        .glassEffect(.clear)
//                        Text("Nothing here.")
//                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            // Title
            .navigationTitle(String(localized: "Support & Love"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        if hapticEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        // Hearts float up the Large tip as it's revealed. Bumped after the
        // expand is applied, once the row's particle view exists to see it.
        .onChange(of: showExpandedFeatures) { _, isExpanded in
            if isExpanded {
                heartBurst += 1
            }
        }
    }

    // MARK: - Heart Emblem

    /// The Lifetime store's app icon emblem with the SF Symbol heart subtracted
    /// in place of the icon's circle.
    private var heartEmblem: some View {
        let plate = RoundedRectangle(cornerRadius: 26, style: .continuous)
            .subtracting(
                HeartShape()
                    .scale(0.6)
                    // Nudged down toward its center of mass: the lobes outweigh
                    // the point, so a box-centered heart reads high
                    .offset(y: 3)
            )

        return plate
            .fill(Color.white.opacity(0.05))
            .glassEffect(.clear, in: plate)
            .frame(width: 100, height: 100)
    }
}

// MARK: - Heart Shape

/// Outline of the SF Symbol `heart.fill` (regular weight) as a `Shape`, since
/// `subtracting` and `glassEffect(in:)` only take shapes, not symbol images.
/// Fits the rect at the symbol's aspect ratio, centered.
private struct HeartShape: Shape {
    /// Width / height of the symbol's outline
    private static let aspectRatio: CGFloat = 1.0817

    func path(in rect: CGRect) -> Path {
        let width = min(rect.width, rect.height * Self.aspectRatio)
        let height = width / Self.aspectRatio
        let origin = CGPoint(x: rect.midX - width / 2, y: rect.midY - height / 2)

        // Outline points in a unit square, scaled into the fitted frame
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * width, y: origin.y + y * height)
        }

        var path = Path()
        path.move(to: point(0.5000, 1.0000))
        path.addCurve(to: point(0.5368, 0.9853), control1: point(0.5106, 1.0000), control2: point(0.5257, 0.9924))
        path.addCurve(to: point(1.0000, 0.3290), control1: point(0.8202, 0.7892), control2: point(1.0000, 0.5610))
        path.addCurve(to: point(0.7195, 0.0000), control1: point(1.0000, 0.1362), control2: point(0.8776, 0.0000))
        path.addCurve(to: point(0.5000, 0.1487), control1: point(0.6213, 0.0000), control2: point(0.5458, 0.0588))
        path.addCurve(to: point(0.2805, 0.0000), control1: point(0.4552, 0.0594), control2: point(0.3787, 0.0000))
        path.addCurve(to: point(0.0000, 0.3290), control1: point(0.1224, 0.0000), control2: point(0.0000, 0.1362))
        path.addCurve(to: point(0.4637, 0.9853), control1: point(0.0000, 0.5610), control2: point(0.1798, 0.7892))
        path.addCurve(to: point(0.5000, 1.0000), control1: point(0.4743, 0.9924), control2: point(0.4894, 1.0000))
        path.closeSubpath()
        return path
    }
}
