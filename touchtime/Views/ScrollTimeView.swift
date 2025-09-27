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
    @Binding var showButtons: Bool
    @Binding var worldClocks: [WorldClock]
    @State private var dragOffset: CGFloat = 0
    @State private var eventStore = EKEventStore()
    @State private var showTimePicker = false
    @State private var showShareSheet = false
    @State private var currentDate = Date()
    @Namespace private var glassNamespace
    
    // Calculate hours from drag offset
    func hoursFromOffset(_ offset: CGFloat) -> Double {
        return Double(offset) / 15.0 // 15 points = 1 hour
    }
    
    // Show share sheet with city selection
    func showShareCities() {
        // Update current date
        currentDate = Date()
        // Show the share sheet
        showShareSheet = true
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
                        Button(action: showShareCities) {
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
                            // During dragging - ZStack with dots and chevrons
                            ZStack {
                                // Dots indicator in the background
                                HStack(spacing: 8) {
                                    ForEach(0..<24) { index in
                                        Capsule()
                                            .fill(.primary.opacity({
                                                // Calculate opacity based on distance from center
                                                let center = 11.5 // Center of 24 items (0-23)
                                                let distance = abs(Double(index) - center)
                                                let maxDistance = 11.5
                                                let opacity = 1.0 * (1 - (distance / maxDistance)) // From 1 at center to 0 at edges
                                                return opacity
                                            }()))
                                            .frame(width: 2, height: 12)
                                            .blur(radius: {
                                                // Calculate blur based on distance from center
                                                let center = 11.5 // Center of 24 items (0-23)
                                                let distance = abs(Double(index) - center)
                                                let maxDistance = 11.5
                                                let blurAmount = (distance / maxDistance) * 1 // Max blur of 1
                                                return blurAmount
                                            }())
                                    }
                                }
                                
                                // Chevrons in the foreground
                                HStack {
                                    Image(systemName: "chevron.backward")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                        .id("chevron.left.dragging")
                                        .transition(.blurReplace)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                        .id("chevron.right.dragging")
                                        .transition(.blurReplace)
                                }
                            }
                            
                        } else if timeOffset != 0 {
                            let totalHours = timeOffset / 3600
                            let isPositive = totalHours >= 0
                            let absoluteHours = abs(totalHours)
                            let hours = Int(absoluteHours)
                            let minutes = Int((absoluteHours - Double(hours)) * 60)
                            let sign = isPositive ? "+" : "-"
                            
                            Spacer()
                            
                            // Final time text (tappable)
                            Button(action: {
                                showTimePicker = true
                            }) {
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
                                .foregroundColor(.primary)
                                .monospacedDigit()
                            }
                            .buttonStyle(.plain)
                            .transition(.blurReplace)
                            
                            Spacer()
                            
                        } else {
                            // Slide to Adjust Time
                            Image(systemName: "chevron.backward")
                                .fontWeight(.semibold)
                                .foregroundStyle(.tertiary)
                                .id("chevron.left.idle")
                                .transition(.blurReplace)
                            
                            Spacer()
                            
                            Text("Slide to Adjust")
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .transition(.blurReplace)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .fontWeight(.semibold)
                                .foregroundStyle(.tertiary)
                                .id("chevron.right.idle")
                                .transition(.blurReplace)
                        }
                    }
                    .padding(.horizontal) // Chevron paddings
                    .font(.subheadline)
                
                    .animation(.spring(duration: 0.25), value: dragOffset)
                    .animation(.spring(duration: 0.25), value: timeOffset)
                
                .frame(maxWidth: showButtons ? nil : .infinity)
                .frame(height: 52)
                .padding(.horizontal, showButtons ? 24 : 0)
                .contentShape(Rectangle())
                .glassEffect(.regular.interactive())
                .glassEffectID("mainContent", in: glassNamespace)
            
                
                // Reset button (right side)
                if showButtons {
                    Button(action: resetTimeOffset) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 20))
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .frame(width: 52, height: 52)
                    }
                    .buttonStyle(.plain)
                    .clipShape(Circle())
                    .glassEffect(.regular.interactive())
                    .glassEffectID("resetButton", in: glassNamespace)
                    .glassEffectTransition(.matchedGeometry)
                }
            }
            .animation(.spring(), value: showButtons)
        }
        
        // Overall composer
        .padding(.horizontal,5)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Prevent dragging after buttons appear
                    guard !showButtons else { return }
                    
                    dragOffset = value.translation.width
                    let hours = hoursFromOffset(dragOffset)
                    timeOffset = hours * 3600 // Convert hours to seconds
                }
                .onEnded { _ in
                    // Prevent drag end action if buttons are already showing
                    guard !showButtons else { return }
                    
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
        .sheet(isPresented: $showTimePicker) {
            TimeOffsetPickerView(
                timeOffset: $timeOffset,
                showTimePicker: $showTimePicker
            )
        }
        .sheet(isPresented: $showShareSheet) {
            ShareCitiesSheet(
                worldClocks: $worldClocks,
                showSheet: $showShareSheet,
                currentDate: currentDate,
                timeOffset: timeOffset
            )
        }
    }
}
