//
//  OnboardingView.swift
//  touchtime
//
//  Created on 2025.
//

import SwiftUI
import CoreHaptics
import VariableBlur

struct DotMatrixOverlay: View {
    let rows = 30
    let columns = 20
    let dotSize: CGFloat = 2.5
    let spacing: CGFloat = 10
    
    @State private var animatedDots = Set<Int>()
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let horizontalSpacing = width / CGFloat(columns)
            let verticalSpacing = height / CGFloat(rows)
            
            ZStack {
                ForEach(0..<rows * columns, id: \.self) { index in
                    let row = index / columns
                    let column = index % columns
                    let x = CGFloat(column) * horizontalSpacing + horizontalSpacing / 2
                    let y = CGFloat(row) * verticalSpacing + verticalSpacing / 2
                    
                    Circle()
                        .fill(Color.white.opacity(animatedDots.contains(index) ? 0.25 : 0.05))
                        .frame(width: dotSize, height: dotSize)
                        .position(x: x, y: y)
                        .blendMode(.plusLighter)
                }
            }
            .onAppear {
                animateRandomDots()
            }
        }
    }
    
    private func animateRandomDots() {
        Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { _ in
            withAnimation(.spring()) {
                // Remove some dots
                animatedDots = animatedDots.filter { _ in Bool.random() }
                // Add new random dots
                for _ in 0..<50 {
                    animatedDots.insert(Int.random(in: 0..<(rows * columns)))
                }
            }
        }
    }
}

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    var isReviewing: Bool = false  // True when showing from Settings
    @State private var animateIcon = false
    @State private var animateText = false
    @State private var animateButton = false
    @State private var currentPage = 1  // 1 for intro, 2 for features
    @State private var animateFeatures = false
    @State private var hapticEngine: CHHapticEngine?
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    
    // Prepare haptic engine
    func prepareHaptics() {
        guard hapticEnabled && CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Error creating haptic engine: \(error.localizedDescription)")
        }
    }
    
    // Play continuous subtle haptic pattern
    func playContinuousHaptic() {
        guard hapticEnabled && CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        guard let engine = hapticEngine else { return }
        
        do {
            // Create a continuous subtle haptic pattern
            var events = [CHHapticEvent]()
            
            // Create multiple short, light taps in succession for a continuous feel
            for i in 0..<8 {
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                
                let event = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [intensity, sharpness],
                    relativeTime: TimeInterval(i) * 0.05 // Events 50ms apart
                )
                events.append(event)
            }
            
            // Create and play the pattern
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play haptic: \(error.localizedDescription)")
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            SkyColorGradient(
                date: Date(),
                timeZoneIdentifier: TimeZone.current.identifier
            )
            .linearGradient()
            .blendMode(.plusLighter)
            .ignoresSafeArea()
            .blur(radius: 200)
            .opacity(0.35)
            
            // Dot Matrix Animation
            DotMatrixOverlay()
                .ignoresSafeArea()
                .blendMode(.plusLighter)
                .opacity(0.75)
                .opacity(animateIcon ? 1.0 : 0.0)
            
            // VariableBlur
            GeometryReader { geom in
                VariableBlurView(maxBlurRadius: 10, direction: .blurredBottomClearTop)
                    .frame(height: geom.safeAreaInsets.bottom + 100)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea()
            }
            
            VStack {
                Spacer()
                
                // Main Content Area - switches between intro and features
                if currentPage == 1 {
                    // Intro Page
                    VStack (spacing: 32) {
                        // App Icon
                        ZStack {
                            Image("TouchTimeAppIcon") // Background light
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .blur(radius: 100)
                                .blendMode(.plusLighter)
                                .scaleEffect(animateIcon ? 1.0 : 0.85)
                                .opacity(animateIcon ? 1.0 : 0.0)
                                .offset(y: animateText ? 0 : 50)
                                .animation(
                                    .bouncy(duration: 2.5), value: animateIcon
                                )
                            Image("TouchTimeAppIcon")
                                .resizable()
                                .scaledToFit()
                                .glassEffect(.clear.interactive(), in:
                                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                )
                                .frame(width: 100, height: 100)
                                .blur(radius: animateIcon ? 0 : 25)
                                .scaleEffect(animateIcon ? 1.0 : 0.5)
                                .opacity(animateIcon ? 1.0 : 0.0)
                                .offset(y: animateText ? 0 : 50)
                                .animation(
                                    .bouncy(duration: 1.0), value: animateIcon
                                )
                                .onTapGesture {
                                    if hapticEnabled {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                                        impactFeedback.impactOccurred()
                                    }
                                }
                        }
                        
                        VStack(spacing: 8) {
                            // App Name
                            Text("Touch Time")
                                .font(.system(size: 24).weight(.semibold))
                                .blur(radius: animateText ? 0 : 10)
                                .opacity(animateText ? 1.0 : 0.0)
                                .offset(y: animateText ? 0 : 75)
                                .animation(
                                    .smooth(duration: 1.0),value: animateText
                                )
                            // Description
                            Text("The world time flows within the delicate sky")
                                .foregroundStyle(.secondary)
                                .blendMode(.plusLighter)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                                .blur(radius: animateText ? 0 : 10)
                                .opacity(animateText ? 1.0 : 0.0)
                                .offset(y: animateText ? 0 : 75)
                                .animation(
                                    .smooth(duration: 1.0),value: animateText
                                )
                        }
                    }
                    .transition(.blurReplace())
                } else {
                    // Features Page
                    VStack(spacing: 16) {
                        FeatureRow(
                            icon: "clock",
                            title: String(localized: "450+ cities worldwide"),
                            isAnimated: animateFeatures
                        )
                        
                        FeatureRow(
                            icon: "hand.draw.fill",
                            title: String(localized: "Swipe to shift time zones and see the world in sync"),
                            isAnimated: animateFeatures
                        )
                        
                        FeatureRow(
                            icon: "globe.americas.fill",
                            title: String(localized: "Explore time through an immersive globe view"),
                            isAnimated: animateFeatures
                        )
                        
                        FeatureRow(
                            icon: "calendar",
                            title: String(localized: "Event plan across zones, effortlessly"),
                            isAnimated: animateFeatures
                        )
                        
                        Text("and much more...", comment: "Onboarding feature list ending")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .blendMode(.plusLighter)
                            .padding(.top, 8)
                        
                    }
                    .transition(.blurReplace().combined(with: .move(edge: .bottom)))
                    .padding(.horizontal, 32)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    // Continue / Get Started Button
                    Button(action: {
                        // Play continuous haptic when Continue is pressed (page 1)
                        if currentPage == 1 {
                            playContinuousHaptic()
                        } else if hapticEnabled {
                            // Play single impact feedback for Get Started (page 2)
                            let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                            impactFeedback.impactOccurred()
                        }
                        
                        if currentPage == 1 {
                            // Move to features page
                            withAnimation(.spring()) {
                                currentPage = 2
                                animateFeatures = true
                            }
                        } else {
                            // Complete onboarding
                            withAnimation(.spring()) {
                                hasCompletedOnboarding = true
                                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                            }
                        }
                    }) {
                        Text(currentPage == 1 ? "Continue" : "Get Started")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                Capsule()
                                    .fill(currentPage == 1 ? Color.black.opacity(0.25) : Color.blue.opacity(0.85))
                            )
                            .glassEffect(.clear.interactive())
                    }
                    
                    // Terms and Privacy - only show on features page
                    if currentPage == 2 {
                        VStack(spacing: 4) {
                            Text("By continuing, you agree to our")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 4) {
                                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .buttonStyle(.plain)
                                
                                Text("and")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Link("Privacy Policy", destination: URL(string: "https://www.handstime.app/privacy")!)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .buttonStyle(.plain)
                            }
                        }
                        .blendMode(.plusLighter)
                        .multilineTextAlignment(.center)
                        .transition(.blurReplace())
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, currentPage == 2 ? 0 : 16) // Continue = Bottom: 16
                .scaleEffect(animateButton ? 1.0 : 0.85)
                .opacity(animateButton ? 1.0 : 0.0)
                .animation(
                    .spring(duration: 1.0), value: animateButton
                )
  
            }
        }
        .onAppear {
            // Prepare haptic engine
            prepareHaptics()
            
            // Start animations
            animateIcon = true
            animateText = true
            animateButton = true
        }
        .onDisappear {
            // Stop and clean up haptic engine
            hapticEngine?.stop()
            hapticEngine = nil
        }
    }
}

// Feature Row Component
struct FeatureRow: View {
    let icon: String
    let title: String
    let isAnimated: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 22).weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
                .blendMode(.plusLighter)
                .frame(width: 40, height: 40)
            
            // Title
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            Capsule()
                .fill(.black.opacity(0.25))
                .glassEffect(.clear)
        )
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
        .preferredColorScheme(.dark)
}
