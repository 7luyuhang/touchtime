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
import StoreKit

struct ScrollTimeView: View {
    @Binding var timeOffset: TimeInterval
    @Binding var showButtons: Bool
    @Binding var worldClocks: [WorldClock]
    @State private var dragOffset: CGFloat = 0
    @State private var accumulatedOffset: TimeInterval = 0 // For continuous scroll mode
    @State private var eventStore = EKEventStore()
    @State private var showTimePicker = false
    @State private var showEventEditor = false
    @State private var eventToEdit: EKEvent?
    @State private var hapticEngine: CHHapticEngine?
    @State private var lastHapticOffset: CGFloat = 0
    @State private var hapticPlayer: CHHapticPatternPlayer?
    @State private var inertiaTimer: Timer?
    @State private var inertiaVelocity: CGFloat = 0
    @State private var lastInertiaHapticOffset: TimeInterval = 0
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("defaultEventDuration") private var defaultEventDuration: Double = 3600 // Default 1 hour in seconds
    @AppStorage("showCitiesInNotes") private var showCitiesInNotes = true
    @AppStorage("selectedCitiesForNotes") private var selectedCitiesForNotes: String = ""
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("selectedCalendarIdentifier") private var selectedCalendarIdentifier: String = ""
    @AppStorage("hasRequestedReviewAfterFirstReset") private var hasRequestedReviewAfterFirstReset = false
    @AppStorage("resetCount") private var resetCount: Int = 0
    @AppStorage("continuousScrollMode") private var continuousScrollMode = false
    @Environment(\.requestReview) private var requestReview
    @Namespace private var glassNamespace
    @State private var showCalendarPermissionAlert = false
    
    // Calculate hours from drag offset
    func hoursFromOffset(_ offset: CGFloat) -> Double {
        return Double(offset) / 15.0 // 15 points = 1 hour
    }
    
    // Prepare haptic engine with proper lifecycle management
    func prepareHaptics() {
        guard hapticEnabled && CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            // Create engine if it doesn't exist
            if hapticEngine == nil {
                hapticEngine = try CHHapticEngine()
                
                // Set up handlers for engine lifecycle events
                // Note: We capture the engine itself, not self (since self is a struct)
                let engine = hapticEngine
                
                hapticEngine?.stoppedHandler = { reason in
                    print("Haptic engine stopped: \(reason.rawValue)")
                    // Try to restart the engine
                    DispatchQueue.main.async {
                        do {
                            try engine?.start()
                            print("Haptic engine restarted after stop")
                        } catch {
                            print("Failed to restart haptic engine: \(error.localizedDescription)")
                        }
                    }
                }
                
                hapticEngine?.resetHandler = {
                    print("Haptic engine reset")
                    // Try to restart the engine after reset  
                    DispatchQueue.main.async {
                        do {
                            try engine?.start()
                            print("Haptic engine restarted after reset")
                        } catch {
                            print("Failed to restart haptic engine: \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            // Start the engine
            try hapticEngine?.start()
            
            // Pre-create the haptic pattern player for better performance
            prepareHapticPlayer()
            
        } catch {
            print("Error creating/starting haptic engine: \(error.localizedDescription)")
        }
    }
    
    // Restart haptic engine when it stops
    func restartHapticEngine() {
        guard hapticEnabled && CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            try hapticEngine?.start()
            // Recreate the player after restart
            prepareHapticPlayer()
            print("Haptic engine restarted successfully")
        } catch {
            print("Failed to restart haptic engine: \(error.localizedDescription)")
        }
    }
    
    // Pre-create haptic pattern player for reuse
    func prepareHapticPlayer() {
        guard let engine = hapticEngine else { return }
        
        do {
            // Create a reusable pattern for tick feedback
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.20)
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.50)
            
            let tickEvent = CHHapticEvent(eventType: .hapticTransient,
                                          parameters: [sharpness, intensity],
                                          relativeTime: 0)
            
            let pattern = try CHHapticPattern(events: [tickEvent], parameters: [])
            hapticPlayer = try engine.makePlayer(with: pattern)
        } catch {
            print("Failed to create haptic player: \(error.localizedDescription)")
        }
    }
    
    // Play tick haptic feedback (simulating physical detent/notch)
    func playTickHaptic(intensity: Float = 0.50) {
        guard hapticEnabled && CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        // Ensure engine is running before playing
        ensureHapticEngineRunning()
        
        do {
            if let player = hapticPlayer {
                // Use existing player for better performance
                try player.start(atTime: CHHapticTimeImmediate)
            } else {
                // Fallback: Create new player if needed
                guard let engine = hapticEngine else { return }
                
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.20)
                let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
                
                let tickEvent = CHHapticEvent(eventType: .hapticTransient,
                                              parameters: [sharpness, intensityParam],
                                              relativeTime: 0)
                
                let pattern = try CHHapticPattern(events: [tickEvent], parameters: [])
                let newPlayer = try engine.makePlayer(with: pattern)
                try newPlayer.start(atTime: CHHapticTimeImmediate)
            }
        } catch {
            print("Failed to play tick haptic: \(error.localizedDescription)")
            // Try to recover by restarting the engine
            restartHapticEngine()
        }
    }
    
    // Ensure haptic engine is running before use
    func ensureHapticEngineRunning() {
        guard hapticEnabled && CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        // Check if engine exists and is running
        if hapticEngine == nil {
            prepareHaptics()
        } else {
            // Check if engine is stopped and restart if needed
            do {
                // This will throw if engine is not running
                try hapticEngine?.start()
            } catch {
                // Engine was stopped, restart it
                restartHapticEngine()
            }
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
    
    // Check if we should play haptic based on time offset change (for inertia scroll)
    func checkAndPlayInertiaHapticTick() {
        // Play haptic every 30 minutes (1800 seconds) during inertia
        let tickInterval: TimeInterval = 1800
        
        let currentTicks = Int(timeOffset / tickInterval)
        let lastTicks = Int(lastInertiaHapticOffset / tickInterval)
        
        if currentTicks != lastTicks {
            playTickHaptic(intensity: 0.35) // Lighter haptic during inertia
            lastInertiaHapticOffset = timeOffset
        }
    }
    
    // Stop any ongoing inertia animation
    func stopInertia() {
        inertiaTimer?.invalidate()
        inertiaTimer = nil
        inertiaVelocity = 0
    }
    
    // Start inertia scroll animation
    func startInertiaScroll(velocity: CGFloat) {
        // Stop any existing inertia
        stopInertia()
        
        // Only start inertia if velocity is significant enough
        guard abs(velocity) > 200 else { return }
        
        // Cap the initial velocity to prevent extreme scrolling
        let maxVelocity: CGFloat = 1000
        inertiaVelocity = min(max(velocity, -maxVelocity), maxVelocity)
        
        // Initialize haptic tracking
        lastInertiaHapticOffset = timeOffset
        
        // Use a timer for smooth deceleration (60 fps)
        let frameInterval: TimeInterval = 1.0 / 60.0
        
        // Create timer and add to .common mode so it continues running during List scrolling
        let timer = Timer(timeInterval: frameInterval, repeats: true) { [self] timer in
            let decelerationRate: CGFloat = 0.96
            inertiaVelocity *= decelerationRate
            
            // Stop when velocity is negligible
            if abs(inertiaVelocity) < 5 {
                timer.invalidate()
                inertiaTimer = nil
                return
            }
            
            // Calculate time change from velocity
            // velocity is in points/second, convert to hours then to seconds
            let deltaPoints = inertiaVelocity * CGFloat(frameInterval)
            let deltaHours = hoursFromOffset(deltaPoints)
            let deltaSeconds = deltaHours * 3600
            
            // Update offsets
            accumulatedOffset += deltaSeconds
            timeOffset = accumulatedOffset
            
            // Play haptic during inertia scroll
            checkAndPlayInertiaHapticTick()
        }
        RunLoop.current.add(timer, forMode: .common)
        inertiaTimer = timer
    }
    
    // Generate notes text with selected cities and their times
    func generateCityNotesText() -> String? {
        guard showCitiesInNotes && !selectedCitiesForNotes.isEmpty else { return nil }
        
        let selectedIds = selectedCitiesForNotes.split(separator: ",").map { String($0) }
        let selectedClocks = worldClocks.filter { clock in
            selectedIds.contains(clock.id.uuidString)
        }
        
        guard !selectedClocks.isEmpty else { return nil }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        let adjustedDate = Date().addingTimeInterval(timeOffset)
        
        var notesText = String(localized: "Time in other cities:") + "\n"
        
        for clock in selectedClocks {
            formatter.timeZone = TimeZone(identifier: clock.timeZoneIdentifier)
            
            if use24HourFormat {
                formatter.dateFormat = "HH:mm"
            } else {
                formatter.dateFormat = "h:mm a"
            }
            
            let timeString = formatter.string(from: adjustedDate)
            
            // Format date - use different format for Chinese locale
            formatter.locale = Locale.current
            if Locale.current.language.languageCode?.identifier == "zh" {
                formatter.dateFormat = "MMMd日 E"
            } else {
                formatter.dateFormat = "E, d MMM"
            }
            let dateString = formatter.string(from: adjustedDate)
            
            // Reset locale for next iteration
            formatter.locale = Locale(identifier: "en_US_POSIX")
            
            notesText += "\n\(clock.localizedCityName): \(timeString) · \(dateString)"
        }
        
        return notesText
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
                    
                    // Set end date with user-configured default duration
                    event.endDate = startDate.addingTimeInterval(self.defaultEventDuration)
                    
                    // Set calendar - use selected calendar if available, otherwise default
                    if !self.selectedCalendarIdentifier.isEmpty,
                       let selectedCalendar = self.eventStore.calendars(for: .event).first(where: { $0.calendarIdentifier == self.selectedCalendarIdentifier }) {
                        event.calendar = selectedCalendar
                    } else {
                        event.calendar = self.eventStore.defaultCalendarForNewEvents
                    }
                    
                    // Add notes with selected cities and their times
                    if let notesText = self.generateCityNotesText() {
                        event.notes = notesText
                    }
                    
                    // Store the event and show the editor
                    self.eventToEdit = event
                    self.showEventEditor = true
                }
            } else {
                print("Calendar access denied or error: \(String(describing: error))")
                DispatchQueue.main.async {
                    // Show permission alert
                    self.showCalendarPermissionAlert = true
                    
                    // Provide haptic feedback on permission denied if enabled
                    if self.hapticEnabled {
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
        // Stop any ongoing inertia animation
        stopInertia()
        
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
            lastInertiaHapticOffset = 0
            accumulatedOffset = 0 // Reset accumulated offset for continuous mode
            showButtons = false
        }
        
        // Increase reset count
        resetCount += 1
        
        // Request app review after 3 resets
        let reviewRequestThreshold = 3
        if resetCount >= reviewRequestThreshold && !hasRequestedReviewAfterFirstReset {
            hasRequestedReviewAfterFirstReset = true
            // Delay the review request slightly to allow the UI animation to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                requestReview()
            }
        }
    }
    
    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                
                // Add to Calendar button (left side)
                if showButtons {
                    Button(action: addToCalendar) {
                        Image(systemName: "plus")
                            .font(.system(size: 20))
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(width: 52, height: 52)
                    }
                    .buttonStyle(.plain)
                    .clipShape(Circle())
                    .contentShape(Circle()) // Ensure the entire circle is tappable
                    .glassEffect(.regular.interactive().tint(.blue.opacity(0.85)))
                    .glassEffectID("calendarButton", in: glassNamespace)
                    .glassEffectTransition(.matchedGeometry)
                }
                    
                    // Main content
                    HStack {
                        // Time adjustment indicator
                        if dragOffset != 0 || (continuousScrollMode && timeOffset != 0) {
                            // During dragging or in continuous mode with offset - ZStack with dots and chevrons
                            ZStack {
                                // Static dots indicator - doesn't re-render
                                ScrollTimeDotsIndicator()
                                
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
                            
                        } else if timeOffset != 0 && !continuousScrollMode {
                            // Only show time text in normal mode, not in continuous scroll mode
                            let totalHours = timeOffset / 3600
                            let isPositive = totalHours >= 0
                            let absoluteHours = abs(totalHours)
                            let days = Int(absoluteHours / 24)
                            let hours = Int(absoluteHours) % 24
                            let minutes = Int((absoluteHours - Double(Int(absoluteHours))) * 60)
                            
                            
                            // Final time text (tappable) - with sign
                            Button(action: {
                                showTimePicker = true
                            }) {
                                Text({
                                    let sign = isPositive ? "+" : "-"
                                    var result = ""
                                    if days > 0 {
                                        result = String(format: String(localized: "%dd"), days)
                                        if hours > 0 {
                                            result += " " + String(format: String(localized: "%dh"), hours)
                                        }
                                        if minutes > 0 {
                                            result += " " + String(format: String(localized: "%02dm"), minutes)
                                        }
                                    } else if hours > 0 && minutes > 0 {
                                        result = String(format: String(localized: "%dh %02dm"), hours, minutes)
                                    } else if hours > 0 {
                                        result = String(format: String(localized: "%dh"), hours)
                                    } else if minutes > 0 {
                                        result = String(format: String(localized: "%02dm"), minutes)
                                    } else {
                                        result = String(localized: "00m")
                                    }
                                    return sign + result
                                }())
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .monospacedDigit()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .transition(.blurReplace())
                            
                        } else {
                            
                            // Default State
                            // Slide to Adjust Time
                            Image(systemName: "chevron.left")
                                .fontWeight(.semibold)
                                .foregroundStyle(.tertiary)
                                .id("chevron.left.idle")
                                .transition(.blurReplace())
                                .blendMode(.plusLighter)
                            
                            Spacer()
                            
                            Text("Slide to Adjust")
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .transition(.blurReplace())
                                .blendMode(.plusLighter)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .fontWeight(.semibold)
                                .foregroundStyle(.tertiary)
                                .id("chevron.right.idle")
                                .transition(.blurReplace())
                                .blendMode(.plusLighter)
                        }
                    }
                    .padding(.horizontal, (timeOffset == 0 || dragOffset != 0 || continuousScrollMode) ? 16 : 0)
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
                            .foregroundStyle(.primary)
                            .frame(width: 52, height: 52)
                    }
                    .buttonStyle(.plain)
                    .clipShape(Circle())
                    .contentShape(Circle()) // Ensure the entire circle is tappable
                    .glassEffect(.regular.interactive())
                    .glassEffectID("resetButton", in: glassNamespace)
                    .glassEffectTransition(.matchedGeometry)
                }
            }
            .animation(.spring(), value: showButtons)
        }
        
        // Overall composer
        .padding(.horizontal, 5)
        .overlay(alignment: .top) {
            // Reset button for continuous scroll mode
            if continuousScrollMode && timeOffset != 0 && !showButtons {
                Button(action: {
                    DispatchQueue.main.async {
                        resetTimeOffset()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.footnote.weight(.semibold))
                        
                        Text({
                            let totalHours = timeOffset / 3600
                            let isPositive = totalHours >= 0
                            let absoluteHours = abs(totalHours)
                            let days = Int(absoluteHours / 24)
                            let hours = Int(absoluteHours) % 24
                            let minutes = Int((absoluteHours - Double(Int(absoluteHours))) * 60)
                            
                            let sign = isPositive ? "+" : "-"
                            var result = ""
                            if days > 0 {
                                result = String(format: String(localized: "%dd"), days)
                                if hours > 0 {
                                    result += " " + String(format: String(localized: "%dh"), hours)
                                }
                                if minutes > 0 {
                                    result += " " + String(format: String(localized: "%02dm"), minutes)
                                }
                            } else if hours > 0 && minutes > 0 {
                                result = String(format: String(localized: "%dh %02dm"), hours, minutes)
                            } else if hours > 0 {
                                result = String(format: String(localized: "%dh"), hours)
                            } else if minutes > 0 {
                                result = String(format: String(localized: "%02dm"), minutes)
                            } else {
                                result = String(localized: "00m")
                            }
                            return sign + result
                        }())
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .clipShape(Capsule())
                .contentShape(Capsule())
                .glassEffect(.regular.interactive())
                .highPriorityGesture(DragGesture())
                .transition(.blurReplace.combined(with: .scale).combined(with: .move(edge: .bottom)).combined(with: .opacity))
                .offset(y: -52)
            }
        }
        .animation(.spring(), value: continuousScrollMode)
        .animation(.spring(), value: timeOffset != 0)
        .gesture(
            showButtons ? nil : DragGesture()
                .onChanged { value in
                    // Stop any ongoing inertia when user starts dragging again
                    if continuousScrollMode {
                        stopInertia()
                    }
                    
                    dragOffset = value.translation.width
                    let hours = hoursFromOffset(dragOffset)
                    
                    if continuousScrollMode {
                        // In continuous mode, add to accumulated offset
                        timeOffset = accumulatedOffset + hours * 3600
                    } else {
                        timeOffset = hours * 3600 // Convert hours to seconds
                    }
                    
                    // Check and play haptic tick when crossing time marks
                    checkAndPlayHapticTick()
                }
                .onEnded { value in
                    // Reset last haptic offset
                    lastHapticOffset = 0
                    
                    // Add final impact feedback when releasing if enabled
                    if hapticEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.prepare()
                        impactFeedback.impactOccurred()
                    }
                    
                    if continuousScrollMode {
                        // In continuous mode, accumulate the offset and reset drag
                        let hours = hoursFromOffset(dragOffset)
                        accumulatedOffset += hours * 3600
                        
                        // Calculate velocity for inertia (points per second)
                        let velocity = value.velocity.width
                        
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                        
                        // Start inertia animation with the release velocity
                        startInertiaScroll(velocity: velocity)
                    } else {
                        // Show buttons after drag ends with morph animation
                        withAnimation(.spring()) {
                            showButtons = true
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            // Prepare haptic engine when view appears
            prepareHaptics()
        }
        .onDisappear {
            // Stop any ongoing inertia animation
            stopInertia()
            // Stop the haptic engine to save resources
            hapticEngine?.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Restart haptic engine when app comes to foreground
            if hapticEnabled {
                restartHapticEngine()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            // Stop inertia animation when app goes to background
            stopInertia()
            // Stop haptic engine when app goes to background
            hapticEngine?.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetScrollTime"))) { _ in
            // Stop any ongoing inertia animation
            stopInertia()
            // Reset drag offset when cities are reset
            withAnimation(.spring()) {
                dragOffset = 0
                lastHapticOffset = 0
                lastInertiaHapticOffset = 0
                accumulatedOffset = 0 // Reset accumulated offset for continuous mode
            }
        }
        .onChange(of: timeOffset) { oldValue, newValue in
            // Sync accumulatedOffset when timeOffset is changed externally (e.g., from CityTimeAdjustmentSheet)
            // Only sync when not currently dragging (dragOffset == 0) and in continuous scroll mode
            if continuousScrollMode && dragOffset == 0 {
                accumulatedOffset = newValue
            }
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
        .alert("", isPresented: $showCalendarPermissionAlert) {
            Button(String(localized: "Cancel"), role: .cancel) { }
            Button(String(localized: "Go to Settings")) {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
        } message: {
            Text("Please allow calendar access in Settings to add events.")
        }
    }
}

// MARK: - Static Dots Indicator
struct ScrollTimeDotsIndicator: View {
    // Pre-calculated static values - computed once
    private static let dotData: [(opacity: Double, blur: CGFloat)] = {
        let center = 11.5
        let maxDistance = 11.5
        return (0..<24).map { index in
            let distance = abs(Double(index) - center)
            let opacity = 1.0 - (distance / maxDistance)
            let blur = CGFloat((distance / maxDistance) * 1.0)
            return (opacity, blur)
        }
    }()
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<24, id: \.self) { index in
                Capsule()
                    .fill(.primary.opacity(Self.dotData[index].opacity))
                    .frame(width: 2, height: 12)
                    .blur(radius: Self.dotData[index].blur)
            }
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
