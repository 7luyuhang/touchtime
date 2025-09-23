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
    
    // Calculate hours from drag offset
    func hoursFromOffset(_ offset: CGFloat) -> Double {
        return Double(offset) / 30.0 // 30 points = 1 hour
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Scroll indicator bar
            HStack(spacing: 16) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .opacity(0.6)
                
                // Visual drag indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 100, height: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor)
                            .frame(width: 40, height: 4)
                            .offset(x: dragOffset / 5) // Move indicator based on drag
                    )
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .opacity(0.6)
            }
            
            // Time adjustment indicator
            if dragOffset != 0 {
                let hours = hoursFromOffset(dragOffset)
                let sign = hours >= 0 ? "+" : ""
                Text("\(sign)\(String(format: "%.1f", hours)) hours")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: hours)
            } else {
                Text("Swipe to adjust time")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .opacity(0.6)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .glassEffect(.clear)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                    let hours = hoursFromOffset(dragOffset)
                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                        timeOffset = hours * 3600 // Convert hours to seconds
                    }
                }
                .onEnded { _ in
                    // Add haptic feedback when releasing
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                    
                    // Reset drag offset but keep timeOffset
                    withAnimation(.spring()) {
                        dragOffset = 0
                    }
                }
        )
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var offset: TimeInterval = 0
        var body: some View {
            ScrollTimeView(timeOffset: $offset)
                .padding()
        }
    }
    return PreviewWrapper()
}
