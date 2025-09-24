//
//  ScrollTimeView.swift
//  touchtime
//
//  Created on 23/09/2025.
//

import SwiftUI
import EventKit

struct ScrollTimeView: View {
    @Binding var timeOffset: TimeInterval
    @State private var dragOffset: CGFloat = 0
    @State private var showButtons: Bool = false
    @State private var eventStore = EKEventStore()
    @Namespace private var glassNamespace
    
    // Calculate hours from drag offset
    func hoursFromOffset(_ offset: CGFloat) -> Double {
        return Double(offset) / 15.0 // 15 points = 1 hour
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
        if hours > 0 && minutes > 0 {
            timeString = "\(hours)h \(minutes)m"
        } else if hours > 0 {
            timeString = "\(hours)h"
        } else if minutes > 0 {
            timeString = "\(minutes)m"
        } else {
            timeString = "0m"
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
    
    // Add to Calendar
    func addToCalendar() {
        // Request calendar permission
        eventStore.requestFullAccessToEvents { granted, error in
            if granted && error == nil {
                // Create event
                let event = EKEvent(eventStore: eventStore)
                
                // Set event properties
                event.title = "Adjusted Time Event"
                
                // Calculate the adjusted start time
                let currentDate = Date()
                let startDate = currentDate.addingTimeInterval(timeOffset)
                event.startDate = startDate
                
                // Set end date (1 hour duration by default)
                event.endDate = startDate.addingTimeInterval(3600)
                
                // Add notes about the time adjustment
                let totalHours = timeOffset / 3600
                let isPositive = totalHours >= 0
                let absoluteHours = abs(totalHours)
                let hours = Int(absoluteHours)
                let minutes = Int((absoluteHours - Double(hours)) * 60)
                let sign = isPositive ? "+" : "-"
                
                var timeString = ""
                if hours > 0 && minutes > 0 {
                    timeString = "\(hours)h \(minutes)m"
                } else if hours > 0 {
                    timeString = "\(hours)h"
                } else if minutes > 0 {
                    timeString = "\(minutes)m"
                } else {
                    timeString = "0m"
                }
                
                event.notes = "Time adjusted by \(sign)\(timeString) from current time"
                
                // Set calendar (default calendar)
                event.calendar = eventStore.defaultCalendarForNewEvents
                
                // Save event
                do {
                    try eventStore.save(event, span: .thisEvent)
                    
                    // Provide haptic feedback on success
                    DispatchQueue.main.async {
                        let impactFeedback = UINotificationFeedbackGenerator()
                        impactFeedback.prepare()
                        impactFeedback.notificationOccurred(.success)
                    }
                } catch {
                    print("Failed to save event: \(error.localizedDescription)")
                    // Provide haptic feedback on error
                    DispatchQueue.main.async {
                        let impactFeedback = UINotificationFeedbackGenerator()
                        impactFeedback.prepare()
                        impactFeedback.notificationOccurred(.error)
                    }
                }
            } else {
                print("Calendar access denied or error: \(String(describing: error))")
                // Provide haptic feedback on permission denied
                DispatchQueue.main.async {
                    let impactFeedback = UINotificationFeedbackGenerator()
                    impactFeedback.prepare()
                    impactFeedback.notificationOccurred(.warning)
                }
            }
        }
    }
    
    // Reset time offset
    func resetTimeOffset() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        // Hide buttons with morph animation after reset
        withAnimation(.spring()) {
            timeOffset = 0
            dragOffset = 0
            showButtons = false
        }
    }
    
    var body: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 16) {
                // More button with menu (left side)
                if showButtons {
                    Menu {
                        Button(action: shareTimeAdjustment) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        
                        Divider()
                        
                        Button(action: addToCalendar) {
                            Label("Add to Calendar", systemImage: "calendar.badge.plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20))
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .frame(width: 52, height: 52)
                    }
                    .buttonStyle(.plain)
                    .clipShape(Circle())
                    .glassEffect(.regular.interactive())
                    .glassEffectID("moreButton", in: glassNamespace)
                    .glassEffectTransition(.matchedGeometry)
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
                    
                    Text({
                        var result = sign
                        if hours > 0 && minutes > 0 {
                            result += "\(hours)h \(minutes)m"
                        } else if hours > 0 {
                            result += "\(hours)h"
                        } else if minutes > 0 {
                            result += "\(minutes)m"
                        } else {
                            result += "0m"
                        }
                        return result
                    }())
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .contentTransition(.numericText())
                    .animation(.spring(), value: totalHours)
                        
                } else if timeOffset != 0 {
                    let totalHours = timeOffset / 3600
                    let isPositive = totalHours >= 0
                    let absoluteHours = abs(totalHours)
                    let hours = Int(absoluteHours)
                    let minutes = Int((absoluteHours - Double(hours)) * 60)
                    let sign = isPositive ? "+" : "-"
                    
                    Text({
                        var result = sign
                        if hours > 0 && minutes > 0 {
                            result += "\(hours)h \(minutes)m"
                        } else if hours > 0 {
                            result += "\(hours)h"
                        } else if minutes > 0 {
                            result += "\(minutes)m"
                        } else {
                            result += "0m"
                        }
                        return result
                    }())
                    .font(.subheadline)
                    .fontWeight(.medium)
                        
                    } else {
                        // Swipe to Adjust Time
                        HStack {
                            Image(systemName: "chevron.backward")
                                .fontWeight(.semibold)
                                .foregroundStyle(.tertiary)
                                
                            Spacer()
                            
                            Text("Slide to Adjust")
                            .foregroundColor(.secondary)
                            
                            Spacer()
                            Image(systemName: "chevron.right")
                                .fontWeight(.semibold)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal)
                        .font(.subheadline)
                        
                    }
                }
                .frame(maxWidth: showButtons ? nil : .infinity)
                .frame(height: 52)
                .padding(.horizontal, showButtons ? 24 : 0)
                .contentShape(Rectangle())
                .glassEffect(.regular.interactive())
                .glassEffectID("mainContent", in: glassNamespace)
                .animation(.spring(), value: showButtons)
            
                
                // Reset button (right side)
                if showButtons {
                    Button(action: resetTimeOffset) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 20))
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                            .frame(width: 52, height: 52)
                    }
                    .buttonStyle(.plain)
                    .clipShape(Circle())
                    .glassEffect(.regular.interactive().tint(.yellow))
                    .glassEffectID("resetButton", in: glassNamespace)
                    .glassEffectTransition(.matchedGeometry)
                }
            }
        }
        
        // Overall composer
        .padding(.horizontal, 16)
        .animation(.spring(), value: showButtons)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                    let hours = hoursFromOffset(dragOffset)
                    
                    // Hide buttons when starting a new drag with morph animation
                    if showButtons {
                        withAnimation(.spring()) {
                            showButtons = false
                        }
                    }
                    
                    withAnimation(.spring()) {
                        timeOffset = hours * 3600 // Convert hours to seconds
                    }
                }
                .onEnded { _ in
                    // Add haptic feedback when releasing
                    let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                    
                    // Show buttons after drag ends with morph animation
                    withAnimation(.spring()) {
                        showButtons = true
                        dragOffset = 0
                    }
                }
        )
    }
}
