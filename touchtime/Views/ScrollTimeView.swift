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
        HStack {
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
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.caption)
                    Text("Swipe to adjust time")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .contentShape(Rectangle()) // Ensure entire area is tappable/draggable
        .glassEffect(.regular.interactive())
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
