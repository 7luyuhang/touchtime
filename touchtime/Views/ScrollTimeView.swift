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
        let totalHours = timeOffset / 3600
        let isPositive = totalHours >= 0
        let absoluteHours = abs(totalHours)
        let hours = Int(absoluteHours)
        let minutes = Int((absoluteHours - Double(hours)) * 60)
        let sign = isPositive ? "+" : "-"
        
        var timeString = ""
        if hours > 0 {
            timeString += "\(hours) \(hours == 1 ? "hour" : "hours")"
            if minutes > 0 {
                timeString += " "
            }
        }
        if minutes > 0 {
            timeString += "\(minutes) \(minutes == 1 ? "min" : "mins")"
        }
        if hours == 0 && minutes == 0 {
            timeString = "0 mins"
        }
        
        let message = "Time adjusted by \(sign)\(timeString)"
        
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
            // More button with menu (left side)
            if showButtons {
                Menu {
                    Button(action: shareTimeAdjustment) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive())
                .transition(.blurReplace.combined(with: .scale))
            }
                
                // Main content
                HStack {
                // Time adjustment indicator
                if dragOffset != 0 {
                    let totalHours = hoursFromOffset(dragOffset)
                    let isPositive = totalHours >= 0
                    let absoluteHours = abs(totalHours)
                    let hours = Int(absoluteHours)
                    let minutes = Int((absoluteHours - Double(hours)) * 60)
                    let sign = isPositive ? "+" : "-"
                    
                    HStack(spacing: 4) {
                        Text(sign)
                        if hours > 0 {
                            Text("\(hours)")
                            Text(hours == 1 ? "hour" : "hours")
                        }
                        if minutes > 0 {
                            Text("\(minutes)")
                            Text(minutes == 1 ? "min" : "mins")
                        }
                        if hours == 0 && minutes == 0 {
                            Text("0 mins")
                        }
                    }
                    .font(.subheadline)
                    .contentTransition(.numericText())
                    .animation(.spring(), value: totalHours)
                        
                } else if timeOffset != 0 {
                    let totalHours = timeOffset / 3600
                    let isPositive = totalHours >= 0
                    let absoluteHours = abs(totalHours)
                    let hours = Int(absoluteHours)
                    let minutes = Int((absoluteHours - Double(hours)) * 60)
                    let sign = isPositive ? "+" : "-"
                    
                    HStack(spacing: 4) {
                        Text(sign)
                        if hours > 0 {
                            Text("\(hours)")
                            Text(hours == 1 ? "hour" : "hours")
                        }
                        if minutes > 0 {
                            Text("\(minutes)")
                            Text(minutes == 1 ? "min" : "mins")
                        }
                        if hours == 0 && minutes == 0 {
                            Text("0 mins")
                        }
                    }
                    .font(.subheadline)
                        
                    } else {
                        HStack {
                            Image(systemName: "chevron.backward")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("Swipe to Adjust")
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
                .padding(.horizontal, showButtons ? 24 : 0)
                .contentShape(Rectangle())
                .glassEffect(.regular.interactive())
                .animation(.spring(), value: showButtons)
            
                
                // Reset button (right side)
                if showButtons {
                    Button(action: resetTimeOffset) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 20))
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                            .frame(width: 52, height: 52)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive().tint(.yellow))
                    .transition(.blurReplace.combined(with: .scale))
                }
            }
        .padding(.horizontal, 16)
        .animation(.spring(), value: showButtons)
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
