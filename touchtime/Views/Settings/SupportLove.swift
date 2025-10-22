//
//  TipJarSection.swift
//  touchtime
//
//  Created on 22/10/2025.
//

import SwiftUI
import StoreKit
import UIKit

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
            
            // Gradient Background
            if showExpandedFeatures {
                VStack(spacing: 0) {
                    LinearGradient(
                        gradient: Gradient(colors: [Color.indigo.opacity(0.25), Color.pink.opacity(0.25)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blur(radius: 50)
                    
                    Color.clear
                }
                .ignoresSafeArea()
                .transition(.opacity)
                .animation(.spring(), value: showExpandedFeatures)
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
                    
                    Text("Thank you for your attention and support, love you!")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 16)
                    
                    
                    if iapManager.purchaseState == .loading {
                        HStack {
                            ProgressView()
                            Text("Loading...")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .glassEffect(.clear)
                        
                    } else if !iapManager.products.isEmpty {
                        // Small Tip HStack
                        if let smallTip = iapManager.products.first(where: { $0.id == "com.time.tip.small" }) {
                            HStack {
                                HStack(spacing: 12) {
                                    SystemIconImage(
                                        systemName: "heart.fill",
                                        topColor: .red,
                                        bottomColor: .pink
                                    )
                                    Text("Small Tip")
                                        .foregroundStyle(.primary)
                                }
                                
                                Spacer()
                                
                                if iapManager.purchaseState == .purchasing {
                                    ProgressView()
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
                                            .font(.subheadline.weight(.semibold))
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
                            .glassEffect(.clear)
                        }
                        
                        // Medium Tip HStack
                        if let mediumTip = iapManager.products.first(where: { $0.id == "com.time.tip.medium" }) {
                            HStack {
                                HStack(spacing: 12) {
                                    SystemIconImage(
                                        systemName: "heart.fill",
                                        topColor: .blue,
                                        bottomColor: .cyan
                                    )
                                    Text("Medium Tip")
                                        .foregroundStyle(.primary)
                                }
                                
                                Spacer()
                                
                                if iapManager.purchaseState == .purchasing {
                                    ProgressView()
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
                                            .font(.subheadline.weight(.semibold))
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
                            .glassEffect(.clear)
                        }
                        
                        // Large Tip HStack (Hidden initially, shown when expanded)
                        if showExpandedFeatures {
                            if let largeTip = iapManager.products.first(where: { $0.id == "com.time.tip.large" }) {
                                HStack {
                                    HStack(spacing: 12) {
                                        SystemIconImage(
                                            systemName: "heart.fill",
                                            topColor: .indigo,
                                            bottomColor: .pink
                                        )
                                        Text("Large Tip")
                                            .foregroundStyle(.primary)
                                    }
                                    
                                    Spacer()
                                    
                                    if iapManager.purchaseState == .purchasing {
                                        ProgressView()
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
                                                .font(.subheadline.weight(.semibold))
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
                                            gradient: Gradient(colors: [Color.indigo.opacity(0.5), Color.pink.opacity(0.5)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .glassEffect(.clear, in: Capsule(style: .continuous))
                                )
                                .transition(.blurReplace.combined(with: .move(edge: .top)))
                                
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
                                Text(showExpandedFeatures ? "Show less" : "Support even more")
                                    .id(showExpandedFeatures)
                                    .font(.subheadline.weight(.semibold))
                                    .transition(.blurReplace)
                                
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .blendMode(.plusLighter)
                                    .rotationEffect(.degrees(showExpandedFeatures ? -90 : 0))
                            }
                            .foregroundStyle(.white)
                            .blendMode(.plusLighter)
                            .padding(.vertical, 15)
                            .padding(.horizontal, 20)
                            .clipShape(.capsule)
                            .glassEffect(.clear.interactive())
                        }
                        .buttonStyle(.plain)
                        
                        
                        // Unable Loading
                    } else {
                        Text("Unable to load tip options")
                            .foregroundStyle(.secondary)
                            .padding()
                            .glassEffect(.clear)
                    }
                }
                .padding()
                
            }
            
            // Title
            .navigationTitle("Support & Love")
            .navigationBarTitleDisplayMode(.inline)
            
            // Bottom Email Button (appears when expanded)
            if showExpandedFeatures {
                VStack {
                    Spacer()
                    
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
                        Text("Chat with me")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .glassEffect(.clear
                                .interactive()
                                .tint(.white))
                    }
                    .padding(.horizontal)
                    .buttonStyle(.plain)
                }
                .transition(.blurReplace())
            }
        }
    }
}

