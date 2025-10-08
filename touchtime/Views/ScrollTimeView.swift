//
//  ScrollTimeView.swift
//  touchtime
//
//  Created on 23/09/2025.
//

import SwiftUI
import EventKit
import EventKitUI
import CoreHaptics

struct ScrollTimeView: View {
    @Binding var timeOffset: TimeInterval
    @Binding var showButtons: Bool
    @Binding var worldClocks: [WorldClock]
    @State private var dragOffset: CGFloat = 0
    @State private var eventStore = EKEventStore()
    @State private var showTimePicker = false
    @State private var showEventEditor = false
    @State private var eventToEdit: EKEvent?
    @State private var hapticEngine: CHHapticEngine?
    @State private var lastHapticOffset: CGFloat = 0
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @Namespace private var glassNamespace
    
    // Calculate hours from drag offset
    func hoursFromOffset(_ offset: CGFloat) -> Double {
        return Double(offset) / 15.0 // 15 points = 1 hour
    }
    
    // Prepare haptic engine
    func prepareHaptics() {
        guard hapticEnabled && CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("There was an error creating the haptic engine: \(error.localizedDescription)")
        }
    }
    
    // Play tick haptic feedback (simulating physical detent/notch)
    func playTickHaptic(intensity: Float = 0.5) {
        guard hapticEnabled && CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            // Create a sharp, short haptic event to simulate a tick/detent
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25)
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
            
            let tickEvent = CHHapticEvent(eventType: .hapticTransient,
                                          parameters: [sharpness, intensity],
                                          relativeTime: 0)
            
            let pattern = try CHHapticPattern(events: [tickEvent], parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play tick haptic: \(error.localizedDescription)")
        }
    }
    
    // Check if we should play haptic based on offset change
    func checkAndPlayHapticTick() {
        // Since 15 points = 1 hour
        let tickInterval: CGFloat = 7.5
        
        // Calculate how many ticks we've passed
        let currentTicks = Int(dragOffset / tickInterval)
        let lastTicks = Int(lastHapticOffset / tickInterval)
        
        // If we've crossed a tick boundary
        if currentTicks != lastTicks {
            // Play consistent haptic for all ticks
            playTickHaptic(intensity: 0.5)
            lastHapticOffset = dragOffset
        }
    }
    
    // Add to Calendar - opens system event editor
    func addToCalendar() {
        // Request calendar permission
        eventStore.requestFullAccessToEvents { granted, error in
            if granted && error == nil {
                DispatchQueue.main.async {
                    // Create event with adjusted time
                    let event = EKEvent(eventStore: self.eventStore)
                    
                    // Calculate the adjusted start time
                    let currentDate = Date()
                    let startDate = currentDate.addingTimeInterval(self.timeOffset)
                    event.startDate = startDate
                    
                    // Set end date (1 hour duration by default)
                    event.endDate = startDate.addingTimeInterval(3600)
                    
                    // Set calendar (default calendar)
                    event.calendar = self.eventStore.defaultCalendarForNewEvents
                    
                    // Store the event and show the editor
                    self.eventToEdit = event
                    self.showEventEditor = true
                }
            } else {
                print("Calendar access denied or error: \(String(describing: error))")
                // Provide haptic feedback on permission denied if enabled
                if hapticEnabled {
                    DispatchQueue.main.async {
                        let impactFeedback = UINotificationFeedbackGenerator()
                        impactFeedback.prepare()
                        impactFeedback.notificationOccurred(.warning)
                    }
                }
            }
        }
    }
    
    // Reset time offset
    func resetTimeOffset() {
        // Provide haptic feedback if enabled
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
        
        // Reset all states and hide buttons
        withAnimation(.spring()) {
            timeOffset = 0
            dragOffset = 0
            lastHapticOffset = 0
            showButtons = false
        }
    }
    
    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                
                // Add to Calendar button (left side)
                if showButtons {
                    Button(action: addToCalendar) {
                        Image(systemName: "plus")
                            .font(.system(size: 20))
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .frame(width: 52, height: 52)
                    }
                    .buttonStyle(.plain)
                    .clipShape(Circle())
                    .contentShape(Circle()) // Ensure the entire circle is tappable
                    .glassEffect(.regular.interactive())
                    .glassEffectID("calendarButton", in: glassNamespace)
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
                                    Image(systemName: "chevron.left")
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
                            
                            Image(systemName: "chevron.left")
                                .fontWeight(.semibold)
                                .foregroundColor(isPositive ? .primary.opacity(0.5) : .primary)
                                .padding(.leading, -8)
                            
                            Spacer()
                            
                            // Final time text (tappable) - without sign
                            Button(action: {
                                showTimePicker = true
                            }) {
                                Text({
                                    var result = ""
                                    if hours > 0 && minutes > 0 {
                                        result = "\(hours)h \(minutes)m"
                                    } else if hours > 0 {
                                        result = "\(hours)h"
                                    } else if minutes > 0 {
                                        result = "\(minutes)m"
                                    } else {
                                        result = "0m"
                                    }
                                    return result
                                }())
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .monospacedDigit()
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .transition(.blurReplace)
                            
                            Spacer()
                            
                            // Right Icon
                            Image(systemName: "chevron.right")
                                .fontWeight(.semibold)
                                .foregroundColor(isPositive ?  .primary : .primary.opacity(0.5))
                                .padding(.trailing, -8)
                            
                        } else {
                            // Slide to Adjust Time
                            Image(systemName: "chevron.left")
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
                    .padding(.horizontal, (timeOffset == 0 || dragOffset != 0) ? 16 : 0)
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
                    Button(action: {
                        // Ensure the action is called on the main thread
                        DispatchQueue.main.async {
                            resetTimeOffset()
                        }
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 20))
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                    }
                    .buttonStyle(.plain)
                    .clipShape(Circle())
                    .contentShape(Circle()) // Ensure the entire circle is tappable
                    .glassEffect(.regular.interactive().tint(.blue))
                    .glassEffectID("resetButton", in: glassNamespace)
                    .glassEffectTransition(.matchedGeometry)
                }
            }
            .animation(.spring(), value: showButtons)
        }
        
        // Overall composer
        .padding(.horizontal,5)
        .gesture(
            showButtons ? nil : DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                    let hours = hoursFromOffset(dragOffset)
                    timeOffset = hours * 3600 // Convert hours to seconds
                    
                    // Check and play haptic tick when crossing time marks
                    checkAndPlayHapticTick()
                }
                .onEnded { _ in
                    // Reset last haptic offset
                    lastHapticOffset = 0
                    
                    // Add final impact feedback when releasing if enabled
                    if hapticEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.prepare()
                        impactFeedback.impactOccurred()
                    }
                    
                    // Show buttons after drag ends with morph animation
                    withAnimation(.spring()) {
                        showButtons = true
                        dragOffset = 0
                    }
                }
        )
        .onAppear {
            // Prepare haptic engine when view appears
            prepareHaptics()
        }
        .sheet(isPresented: $showTimePicker) {
            TimeOffsetPickerView(
                timeOffset: $timeOffset,
                showTimePicker: $showTimePicker,
                showButtons: $showButtons
            )
        }
        .sheet(isPresented: $showEventEditor) {
            EventEditView(
                event: $eventToEdit,
                isPresented: $showEventEditor,
                eventStore: eventStore
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Event Editor View
struct EventEditView: UIViewControllerRepresentable {
    @Binding var event: EKEvent?
    @Binding var isPresented: Bool
    let eventStore: EKEventStore
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    
    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let eventEditViewController = EKEventEditViewController()
        eventEditViewController.event = event
        eventEditViewController.eventStore = eventStore
        eventEditViewController.editViewDelegate = context.coordinator
        
        return eventEditViewController
    }
    
    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, EKEventEditViewDelegate {
        let parent: EventEditView
        
        init(_ parent: EventEditView) {
            self.parent = parent
        }
        
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            parent.isPresented = false
            
            // Provide haptic feedback based on action if enabled
            if parent.hapticEnabled {
                DispatchQueue.main.async {
                    let impactFeedback = UINotificationFeedbackGenerator()
                    impactFeedback.prepare()
                    
                    switch action {
                    case .saved:
                        impactFeedback.notificationOccurred(.success)
                    case .deleted:
                        impactFeedback.notificationOccurred(.warning)
                    case .canceled:
                        // No haptic for cancel
                        break
                    @unknown default:
                        break
                    }
                }
            }
        }
    }
}
