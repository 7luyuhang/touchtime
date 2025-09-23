//
//  ScrollTimeView.swift
//  touchtime
//
//  Created on 23/09/2025.
//

import SwiftUI

struct ScrollTimeView: View {
    @Binding var timeOffset: TimeInterval
    @State private var dragOffset: CGFloat = 0
    @State private var showButtons: Bool = false
    
    // Calculate hours from drag offset
    func hoursFromOffset(_ offset: CGFloat) -> Double {
        return Double(offset) / 30.0 // 30 points = 1 hour
    }
    
    // Share the current time adjustment
    func shareTimeAdjustment() {
        let hours = timeOffset / 3600
        let sign = hours >= 0 ? "+" : ""
        let message = "Time adjusted by \(sign)\(String(format: "%.1f", hours)) hours"
        
        let activityController = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityController, animated: true)
        }
    }
    
    // Reset time offset
    func resetTimeOffset() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        withAnimation(.spring()) {
            timeOffset = 0
            dragOffset = 0
            showButtons = false
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Share button (left side)
            if showButtons {
                Button(action: shareTimeAdjustment) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 52, height: 52)
                        .glassEffect(.regular)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .transition(.blurReplace.combined(with: .scale))
            }
            
            // Main content
            HStack {
                // Time adjustment indicator
                if dragOffset != 0 {
                    let hours = hoursFromOffset(dragOffset)
                    let sign = hours >= 0 ? "+" : ""
                    
                    Text("\(sign)\(String(format: "%.1f", hours)) hours")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.5), value: hours)
            
                } else if timeOffset != 0 && !showButtons {
                    let hours = timeOffset / 3600
                    let sign = hours >= 0 ? "+" : ""
                    
                    Text("\(sign)\(String(format: "%.1f", hours)) hours")
                        .font(.subheadline)
                        .foregroundColor(.accentColor.opacity(0.7))
                        
                } else {
                    HStack {
                        Image(systemName: "chevron.backward")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("Swipe to adjust")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: showButtons ? nil : .infinity)
            .frame(height: 52)
            .padding(.horizontal, showButtons ? 20 : 0)
            .contentShape(Rectangle())
            .glassEffect(.regular.interactive())
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showButtons)
            
            // Reset button (right side)
            if showButtons {
                Button(action: resetTimeOffset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 52, height: 52)
                        .glassEffect(.regular)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .transition(.blurReplace.combined(with: .scale))
            }
        }
        .padding(.horizontal, showButtons ? 8 : 0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showButtons)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                    let hours = hoursFromOffset(dragOffset)
                    
                    withAnimation(.interactiveSpring()) {
                        timeOffset = hours * 3600 // Convert hours to seconds
                    }
                }
                .onEnded { _ in
                    // Add haptic feedback when releasing
                    let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                    
                    // Show buttons after drag ends
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showButtons = true
                        dragOffset = 0
                    }
                    
                    // Hide buttons after a delay if no offset
                    if timeOffset == 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.spring()) {
                                showButtons = false
                            }
                        }
                    }
                }
        )
    }
}
