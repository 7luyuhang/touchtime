//
//  ScrollTimeView.swift
//  touchtime
//
//  Created on 23/09/2025.
//

import SwiftUI

struct ScrollTimeView: View {
    @State private var timeOffset: TimeInterval = 0
    @State private var dragOffset: CGFloat = 0
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    
    // Calculate the adjusted time based on offset
    var adjustedTime: Date {
        Date().addingTimeInterval(timeOffset)
    }
    
    // Format time for display
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = use24HourFormat ? "HH:mm" : "h:mm a"
        return formatter.string(from: adjustedTime)
    }
    
    // Format date for display
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: adjustedTime)
    }
    
    // Calculate hours from drag offset
    func hoursFromOffset(_ offset: CGFloat) -> Double {
        return Double(offset) / 30.0 // 30 points = 1 hour
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Date display
            Text(dateString)
                .font(.caption)
                .foregroundColor(.secondary)
                .contentTransition(.numericText())
            
            // Time display with scroll indicator
            HStack(spacing: 20) {
                Image(systemName: "chevron.left")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .opacity(0.5)
                
                Text(timeString)
                    .font(.system(size: 48, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: timeString)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .opacity(0.5)
            }
            
            // Visual time adjustment indicator
            if dragOffset != 0 {
                let hours = hoursFromOffset(dragOffset)
                let sign = hours >= 0 ? "+" : ""
                Text("\(sign)\(String(format: "%.1f", hours)) hours")
                    .font(.caption2)
                    .foregroundColor(.accentColor)
                    .contentTransition(.numericText())
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
        )
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
                    
                    // Reset drag offset
                    withAnimation(.spring()) {
                        dragOffset = 0
                    }
                }
        )
    }
}

#Preview {
    ScrollTimeView()
        .padding()
}
