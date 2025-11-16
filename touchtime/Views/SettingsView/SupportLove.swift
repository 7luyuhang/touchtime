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

// Circular Icon for Tip Jar
struct CircularTipIcon: View {
    let systemName: String
    let topColor: Color
    let bottomColor: Color
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            topColor,
                            bottomColor
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
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
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    
    var body: some View {
        ZStack{
            
            // Black Background
            Color.black
                .ignoresSafeArea()
                .overlay(alignment: .top) {
                    // Gradient Background - 使用 overlay 避免影響佈局
                    if showExpandedFeatures {
                        VStack(spacing: 0) {
                            LinearGradient(
                                gradient: Gradient(colors: [Color.orange.opacity(0.25), Color.blue.opacity(0.25)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .blur(radius: 50)
                            .frame(width: 500)
                            .offset(y:-50)
                            
                            Color.clear
                        }
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .animation(.spring(), value: showExpandedFeatures)
                        .allowsHitTesting(false) // 確保不會攔截觸摸事件
                    }
                }
            
            // Particle Effect
            ParticleView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .opacity(0.75)
                .blendMode(.plusLighter)
            
            
            ScrollView {
                VStack(spacing: 16) {
                    
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
                                    CircularTipIcon(
                                        systemName: "heart.fill",
                                        topColor: .red,
                                        bottomColor: .yellow
                                    )
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
                                    CircularTipIcon(
                                        systemName: "heart.fill",
                                        topColor: .blue,
                                        bottomColor: .cyan
                                    )
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
                                        CircularTipIcon(
                                            systemName: "heart.fill",
                                            topColor: .orange,
                                            bottomColor: .blue
                                        )
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
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(LinearGradient(
                                            gradient: Gradient(colors: [Color.orange.opacity(0.5), Color.blue.opacity(0.5)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
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
            
            // Bottom Email Button (appears when expanded)
            if showExpandedFeatures {
                ZStack {
                    
                    // Background Gradient
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 0)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.black.opacity(0),
                                        Color.black.opacity(1.0)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 200)
                            .allowsHitTesting(false)
                    }
                    .ignoresSafeArea()
                    
                    
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 16) {
                            Button(action: {
                                if hapticEnabled {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                                    impactFeedback.impactOccurred()
                                }
                                // Open email
                                if let emailURL = URL(string: "mailto:7luyuhang@gmail.com") {
                                    UIApplication.shared.open(emailURL)
                                }
                            }) {
                                Text(String(localized: "Chat with me"))
                                    .font(.headline)
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .contentShape(Rectangle())
                                    .glassEffect(.clear
                                        .interactive()
                                        .tint(.white))
                            }
                            .padding(.horizontal)
                            .buttonStyle(.plain)
                            
                            Text(String(localized: "Open to any thoughts or feedback :)"))
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)
                                .blendMode(.plusLighter)
                        }
                    }
                    .transition(.blurReplace())
                }
            }
        }
    }
}

