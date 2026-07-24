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
import Combine
import QuartzCore

struct ScrollTimeView: View {
    enum ExpandedControlsMode {
        case alarmTimerClose
        case timerControls
    }

    private let minuteStep: TimeInterval = 60
    private let controlHeight: CGFloat = 52

    @Binding var timeOffset: TimeInterval
    @Binding var showButtons: Bool
    @Binding var worldClocks: [WorldClock]
    var enableDoubleTapExpandedControls: Bool = false
    var expandedControlsMode: ExpandedControlsMode = .alarmTimerClose
    var onAlarmTap: (() -> Void)? = nil
    var onTimerTap: (() -> Void)? = nil
    var onTimerResetTap: (() -> Void)? = nil
    var onTimerPlayPauseTap: (() -> Void)? = nil
    var timerPlayPauseSymbol: String = "play.fill"
    var timerPlayPauseTitle: String? = nil
    var onExpandControlsByDoubleTap: (() -> Void)? = nil
    @State private var dragOffset: CGFloat = 0
    @State private var accumulatedOffset: TimeInterval = 0
    @State private var eventStore = EKEventStore()
    @State private var showEventEditor = false
    @State private var eventToEdit: EKEvent?
    @State private var hapticEngine: CHHapticEngine?
    @State private var lastHapticOffset: CGFloat = 0
    @State private var hapticPlayer: CHHapticPatternPlayer?
    @State private var inertiaVelocity: CGFloat = 0
    @State private var lastInertiaHapticOffset: TimeInterval = 0
    @State private var inertiaActive = false
    // Latest offset requested by an in-progress scrub / inertia frame. It is
    // flushed to the shared `timeOffset` binding at most once per display frame
    // (via `frameDriver`), so the city list re-renders no more than once per frame
    // even though the drag gesture and inertia integrator fire far more often.
    @State private var pendingScrubOffset: TimeInterval?
    @State private var isDragging = false
    @State private var frameDriver = ScrollTimeFrameDriver()
    @State private var showTimeOffsetAdjustmentSheet = false
    @State private var pendingOffsetDirection: ScrollTimeOffsetDirection = .increase
    @State private var pendingOffsetHours = 0
    @State private var pendingOffsetMinutes = 0
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("defaultEventDuration") private var defaultEventDuration: Double = 3600 // Default 1 hour in seconds
    @AppStorage("showCitiesInNotes") private var showCitiesInNotes = false
    @AppStorage("selectedCitiesForNotes") private var selectedCitiesForNotes: String = ""
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("selectedCalendarIdentifier") private var selectedCalendarIdentifier: String = ""
    @AppStorage("addMeetLinkToEvents") private var addMeetLinkToEvents = false
    @AppStorage("hasRequestedReviewAfterFirstReset") private var hasRequestedReviewAfterFirstReset = false
    @AppStorage("resetCount") private var resetCount: Int = 0
    @AppStorage("continuousScrollMode") private var continuousScrollMode = true
    @Environment(\.requestReview) private var requestReview
    @Namespace private var glassNamespace
    @State private var showCalendarPermissionAlert = false
    @ObservedObject private var googleMeet = GoogleMeetManager.shared
    
    // Calculate hours from drag offset
    func hoursFromOffset(_ offset: CGFloat) -> Double {
        return Double(offset) / 15.0 // 15 points = 1 hour
    }

    private func snappedToWholeMinute(_ offset: TimeInterval) -> TimeInterval {
        (offset / minuteStep).rounded(.towardZero) * minuteStep
    }

    private func commitTimeOffset(_ rawOffset: TimeInterval) {
        let snappedOffset = snappedToWholeMinute(rawOffset)
        if snappedOffset != timeOffset {
            timeOffset = snappedOffset
        }
    }
    
    // Format time offset into a human-readable string (e.g., "+1h 30m", "-2d 3h")
    func formattedTimeOffset(_ offset: TimeInterval) -> String {
        let totalMinutes = Int(abs(offset).rounded() / 60)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60
        
        let sign = offset >= 0 ? "+" : "-"
        let result: String
        
        if days > 0 {
            if hours > 0 {
                result = String(format: String(localized: "%dd %dh %02dm"), days, hours, minutes)
            } else {
                result = String(format: String(localized: "%dd %02dm"), days, minutes)
            }
        } else if hours > 0 {
            result = String(format: String(localized: "%dh %02dm"), hours, minutes)
        } else {
            result = String(format: String(localized: "%02dm"), minutes)
        }
        
        return sign + result
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
        
        let currentTicks = Int(accumulatedOffset / tickInterval)
        let lastTicks = Int(lastInertiaHapticOffset / tickInterval)
        
        if currentTicks != lastTicks {
            playTickHaptic(intensity: 0.35) // Lighter haptic during inertia
            lastInertiaHapticOffset = accumulatedOffset
        }
    }
    
    // Stop any ongoing inertia animation
    func stopInertia() {
        inertiaActive = false
        inertiaVelocity = 0
        // If the user isn't actively dragging there is no more work for the
        // per-frame driver, so drop any pending push and shut it down.
        if !isDragging {
            pendingScrubOffset = nil
            frameDriver.stop()
        }
    }
    
    // Start inertia scroll animation
    func startInertiaScroll(velocity: CGFloat) {
        // Cancel any existing inertia, but keep the frame driver alive — we are
        // about to need it again (either for inertia or to flush the final drag
        // position).
        inertiaActive = false
        inertiaVelocity = 0
        
        // Only start inertia if velocity is significant enough
        guard abs(velocity) > 200 else { return }
        
        // Cap the initial velocity to prevent extreme scrolling
        let maxVelocity: CGFloat = 1000
        inertiaVelocity = min(max(velocity, -maxVelocity), maxVelocity)
        
        // Initialize haptic tracking
        lastInertiaHapticOffset = accumulatedOffset
        
        // Advance the inertia from the shared per-frame driver so the list still
        // sees at most one update per frame.
        inertiaActive = true
        frameDriver.start()
    }
    
    // Per-frame integration of the inertia velocity. Expressed in real time so it
    // keeps the previous 0.96-per-frame-at-60fps feel identically on 60 Hz and
    // 120 Hz (ProMotion) displays.
    private func advanceInertia(dt: CFTimeInterval) {
        guard inertiaActive else { return }
        
        let decelerationPerSecond = pow(0.96, 60.0)
        inertiaVelocity *= CGFloat(pow(decelerationPerSecond, Double(dt)))
        
        // Stop when velocity is negligible
        if abs(inertiaVelocity) < 5 {
            inertiaActive = false
            inertiaVelocity = 0
            return
        }
        
        // velocity is in points/second, convert to hours then to seconds
        let deltaPoints = inertiaVelocity * CGFloat(dt)
        let deltaSeconds = hoursFromOffset(deltaPoints) * 3600
        
        accumulatedOffset += deltaSeconds
        pendingScrubOffset = accumulatedOffset
        
        // Play haptic during inertia scroll
        checkAndPlayInertiaHapticTick()
    }
    
    // Called once per display frame by `frameDriver`: advance inertia (if any) and
    // push the most recent offset to the list a single time.
    private func handleFrameTick(dt: CFTimeInterval) {
        advanceInertia(dt: dt)
        
        if let pending = pendingScrubOffset {
            pendingScrubOffset = nil
            commitTimeOffset(pending)
        }
        
        // No drag, no inertia, nothing buffered → nothing to do; stop the driver.
        if !isDragging && !inertiaActive && pendingScrubOffset == nil {
            frameDriver.stop()
        }
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
            guard granted, error == nil else {
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
                return
            }

            Task { @MainActor in
                await self.prepareAndPresentEvent()
            }
        }
    }

    // Build the event (notes + optional Google Meet link) and present the editor
    @MainActor
    private func prepareAndPresentEvent() async {
        // Create event with adjusted time
        let event = EKEvent(eventStore: eventStore)

        // Calculate the adjusted start time
        let startDate = Date().addingTimeInterval(timeOffset)
        event.startDate = startDate

        // Set end date with user-configured default duration
        event.endDate = startDate.addingTimeInterval(defaultEventDuration)

        // Set calendar - use selected calendar if available, otherwise default
        if !selectedCalendarIdentifier.isEmpty,
           let selectedCalendar = eventStore.calendars(for: .event).first(where: { $0.calendarIdentifier == selectedCalendarIdentifier }) {
            event.calendar = selectedCalendar
        } else {
            event.calendar = eventStore.defaultCalendarForNewEvents
        }

        // Build notes: selected cities and their times first, then a Google Meet
        // link on its own line below them.
        var noteSections: [String] = []
        if let cityNotes = generateCityNotesText() {
            noteSections.append(cityNotes)
        }
        if addMeetLinkToEvents,
           googleMeet.isSignedIn,
           let meetLink = try? await googleMeet.createMeetLink() {
            noteSections.append(String(localized: "Google Meet:") + "\n" + meetLink)
        }
        if !noteSections.isEmpty {
            event.notes = noteSections.joined(separator: "\n\n")
        }

        // Store the event and show the editor
        eventToEdit = event
        showEventEditor = true
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
    
    // MARK: - Sub Views
    
    /// Dragging indicator with dots and chevrons
    @ViewBuilder
    private var draggingIndicator: some View {
        ZStack {
            ScrollTimeDotsIndicator()
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
    }
    
    /// Default "Slide to Adjust" indicator
    @ViewBuilder
    private var defaultSlideIndicator: some View {
        Image(systemName: "chevron.left")
            .fontWeight(.semibold)
            .foregroundStyle(.tertiary)
            .id("chevron.left.idle")
            .transition(.blurReplace())
            .blendMode(.plusLighter)
        
        Spacer()
        
        Text("Slide to Adjust")
            .foregroundStyle(.secondary)
            .fontWeight(.medium)
            .transition(.blurReplace().combined(with: .move(edge: .top)))
            .blendMode(.plusLighter)
        
        Spacer()
        
        Image(systemName: "chevron.right")
            .fontWeight(.semibold)
            .foregroundStyle(.tertiary)
            .id("chevron.right.idle")
            .transition(.blurReplace())
            .blendMode(.plusLighter)
    }
    
    private func triggerControlHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle = .soft) {
        guard hapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }

    private func expandActionButtons() {
        guard enableDoubleTapExpandedControls else { return }
        stopInertia()
        withAnimation(.spring()) {
            dragOffset = 0
            showButtons = true
        }
        triggerControlHaptic(style: .rigid)
    }

    private func collapseActionButtons() {
        withAnimation(.spring()) {
            showButtons = false
        }
    }

    private func handleAlarmAction() {
        if let onAlarmTap {
            onAlarmTap()
        } else {
            NotificationCenter.default.post(name: NSNotification.Name("ShowSetAlarmSheet"), object: nil)
        }
    }

    private func handleTimerAction() {
        if let onTimerTap {
            onTimerTap()
        } else {
            NotificationCenter.default.post(name: NSNotification.Name("ShowSetTimerSheet"), object: nil)
        }
    }

    private func handleTimerResetAction() {
        onTimerResetTap?()
    }

    private func handleTimerPlayPauseAction() {
        if let onTimerPlayPauseTap {
            onTimerPlayPauseTap()
        } else {
            handleTimerAction()
        }
    }

    private func prepareTimeOffsetAdjustmentSheet() {
        stopInertia()

        let snappedOffset = snappedToWholeMinute(timeOffset)
        let totalMinutes = Int(abs(snappedOffset) / 60)
        pendingOffsetDirection = snappedOffset >= 0 ? .increase : .decrease
        pendingOffsetHours = min(totalMinutes / 60, 24)
        pendingOffsetMinutes = totalMinutes % 60
    }

    private func confirmTimeOffsetAdjustment() {
        let totalMinutes = pendingOffsetHours * 60 + pendingOffsetMinutes
        let signedOffset = TimeInterval(totalMinutes * 60 * pendingOffsetDirection.rawValue)

        stopInertia()
        withAnimation(.spring()) {
            accumulatedOffset = signedOffset
            commitTimeOffset(signedOffset)
            dragOffset = 0
            lastHapticOffset = 0
            lastInertiaHapticOffset = 0
            showButtons = false
        }

        showTimeOffsetAdjustmentSheet = false
        triggerControlHaptic(style: .soft)
    }

    private var resolvedTimerPlayPauseTitle: String {
        if let timerPlayPauseTitle {
            return timerPlayPauseTitle
        }
        return timerPlayPauseSymbol.contains("pause")
            ? String(localized: "Pause")
            : String(localized: "Start")
    }

    private var isStartTimerPlayPauseAction: Bool {
        !timerPlayPauseSymbol.contains("pause")
            && resolvedTimerPlayPauseTitle == String(localized: "Start")
    }

    /// Main scrollable content area with time adjustment states
    @ViewBuilder
    private var mainContent: some View {
        HStack {
            if dragOffset != 0 || timeOffset != 0 {
                draggingIndicator
            } else {
                defaultSlideIndicator
            }
        }
        .padding(.horizontal, 16)
        .font(.subheadline)
        // Animate only the local indicator swap (dragging vs. idle), keyed on the
        // boolean that drives it. Keying on the continuous `dragOffset`/`timeOffset`
        // values re-fired this spring every frame / every minute-crossing and, for the
        // shared `timeOffset` binding, risked dragging the whole dependent tree into
        // the transaction. The boolean flips only when the indicator actually changes.
        .animation(.spring(duration: 0.25), value: dragOffset != 0 || timeOffset != 0)
        .frame(maxWidth: .infinity)
        .frame(height: controlHeight)
        .contentShape(Rectangle())
        .glassEffect(.regular.interactive())
        .glassEffectID("timerControl", in: glassNamespace)
        .glassEffectTransition(.matchedGeometry)
        .gesture(scrollDragGesture)
        .onTapGesture(count: 2) {
            guard enableDoubleTapExpandedControls, timeOffset == 0 else { return }
            expandActionButtons()
            onExpandControlsByDoubleTap?()
        }
    }

    // Double-tap Feature
    @ViewBuilder
    private var alarmTimerCloseButtons: some View {
        HStack(spacing: 5) {
            Button {
                triggerControlHaptic(style: .soft)
                handleAlarmAction()
                collapseActionButtons()
            } label: {
                HStack {
                    Image(systemName: "alarm")
                        .font(.headline)
                    Text("Alarm")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .frame(height: controlHeight)
            .contentShape(Capsule(style: .continuous))
            .glassEffect(.regular.interactive())
            .glassEffectID("alarmControl", in: glassNamespace)
            .glassEffectTransition(.matchedGeometry)

            Button {
                triggerControlHaptic(style: .soft)
                handleTimerAction()
                collapseActionButtons()
            } label: {
                HStack {
                    Image(systemName: "timer")
                        .font(.headline)
                    Text("Timer")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .frame(height: controlHeight)
            .contentShape(Capsule(style: .continuous))
            .glassEffect(.regular.interactive())
            .glassEffectID("timerControl", in: glassNamespace)
            .glassEffectTransition(.matchedGeometry)

            Button {
                triggerControlHaptic(style: .rigid)
                collapseActionButtons()
            } label: {
                ZStack {
                    Capsule(style: .continuous)
                        .fill(.clear)

                    Image(systemName: "xmark")
                        .font(.headline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .frame(height: controlHeight)
            .glassEffect(.regular.interactive())
            .glassEffectID("closeControl", in: glassNamespace)
            .glassEffectTransition(.matchedGeometry)
        }
        .frame(maxWidth: .infinity)
    }

    // Timer Controls
    @ViewBuilder
    private var timerControlButtons: some View {
        HStack(spacing: 8) {
            Button {
                triggerControlHaptic(style: .soft)
                handleTimerResetAction()
                collapseActionButtons()
            } label: {
                ZStack {
                    Capsule(style: .continuous)
                        .fill(.clear)

                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.headline)
                        Text("Reset")
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .frame(height: controlHeight)
            .glassEffect(.regular.interactive())
            .glassEffectID("timerResetControl", in: glassNamespace)
            .glassEffectTransition(.matchedGeometry)

            Button {
                triggerControlHaptic(style: .soft)
                handleTimerPlayPauseAction()
                collapseActionButtons()
            } label: {
                ZStack {
                    Capsule(style: .continuous)
                        .fill(.clear)

                    if timerPlayPauseSymbol.contains("pause") {
                        HStack {
                            Image(systemName: timerPlayPauseSymbol)
                                .font(.headline)
                            Text(resolvedTimerPlayPauseTitle)
                        }
                        .transition(.blurReplace.combined(with: .opacity))
                    } else {
                        HStack {
                            Image(systemName: timerPlayPauseSymbol)
                                .font(.headline)
                            Text(resolvedTimerPlayPauseTitle)
                        }
                        .transition(.blurReplace.combined(with: .opacity))
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isStartTimerPlayPauseAction ? .black : .primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Capsule(style: .continuous))
                .animation(.spring(duration: 0.25), value: timerPlayPauseSymbol)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .frame(height: controlHeight)
            .glassEffect(
                isStartTimerPlayPauseAction
                    ? .regular.tint(.white).interactive()
                    : .regular.interactive()
            )
            .glassEffectID("timerPlayPauseControl", in: glassNamespace)
            .glassEffectTransition(.materialize)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var splitActionButtons: some View {
        switch expandedControlsMode {
        case .alarmTimerClose:
            alarmTimerCloseButtons
        case .timerControls:
            timerControlButtons
        }
    }

    /// Overlay buttons for continuous scroll mode (calendar + reset with time label)
    @ViewBuilder
    private var continuousScrollOverlayButtons: some View {
        HStack(spacing: 12.5) {
            // Add to Calendar button
            Button(action: {
                if hapticEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .rigid)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                }
                addToCalendar()
            }) {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.white)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 15)
                    .contentShape(Capsule(style: .continuous))
                    .glassEffect(.regular.tint(.blue))
                    .padding(.leading, 5)
            }
            .buttonStyle(.plain)

            Button {
                prepareTimeOffsetAdjustmentSheet()
                showTimeOffsetAdjustmentSheet = true
                triggerControlHaptic(style: .soft)
            } label: {
                Text(formattedTimeOffset(timeOffset))
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Reset button
            Button(action: {
                DispatchQueue.main.async {
                    resetTimeOffset()
                }
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.black)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 15)
                    .contentShape(Capsule(style: .continuous))
                    .glassEffect(.regular.tint(.white))
                    .padding(.trailing, 5)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 5)
        .clipShape(Capsule(style: .continuous))
        .contentShape(Capsule(style: .continuous))
        .glassEffect(.regular.interactive())
        .highPriorityGesture(DragGesture())
        .transition(.blurReplace.combined(with: .scale).combined(with: .move(edge: .bottom)).combined(with: .opacity))
        .offset(y: -controlHeight)
    }
    
    /// Drag gesture for time adjustment scrolling
    private var scrollDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                stopInertia()
                dragOffset = value.translation.width
                let hours = hoursFromOffset(dragOffset)
                // Don't write `timeOffset` here. Buffer the desired value and let
                // the per-frame driver flush it, coalescing the high-frequency drag
                // callbacks into at most one list update per frame.
                pendingScrubOffset = accumulatedOffset + hours * 3600
                frameDriver.start()
                checkAndPlayHapticTick()
            }
            .onEnded { value in
                isDragging = false
                lastHapticOffset = 0
                
                if hapticEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                }

                let hours = hoursFromOffset(dragOffset)
                accumulatedOffset += hours * 3600
                pendingScrubOffset = accumulatedOffset
                let velocity = value.velocity.width

                withAnimation(.spring()) {
                    dragOffset = 0
                }

                startInertiaScroll(velocity: velocity)
                // Keep the driver running to flush the final position (and to run
                // inertia if it started).
                frameDriver.start()
            }
    }
    
    // MARK: - Body
    
    var body: some View {
        let isTimerControlsMode = expandedControlsMode == .timerControls
        let isExpanded = enableDoubleTapExpandedControls && (isTimerControlsMode || showButtons)

        GlassEffectContainer(spacing: 5) {
            if isExpanded {
                splitActionButtons
            } else {
                mainContent
            }
        }
        .padding(.horizontal, 5)
        .overlay(alignment: .top) {
            if !isExpanded && timeOffset != 0 {
                continuousScrollOverlayButtons
            }
        }
        .animation(.spring(), value: isExpanded)
        .animation(.spring(), value: timeOffset != 0)
        .onReceive(frameDriver.publisher) { dt in
            handleFrameTick(dt: dt)
        }
        .onAppear {
            if !continuousScrollMode {
                continuousScrollMode = true
            }
            showButtons = false
            prepareHaptics()
        }
        .onDisappear {
            isDragging = false
            stopInertia()
            frameDriver.stop()
            hapticEngine?.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if hapticEnabled {
                restartHapticEngine()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            stopInertia()
            hapticEngine?.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetScrollTime"))) { _ in
            stopInertia()
            withAnimation(.spring()) {
                dragOffset = 0
                lastHapticOffset = 0
                lastInertiaHapticOffset = 0
                accumulatedOffset = 0
                showButtons = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StopScrollTimeInertia"))) { _ in
            stopInertia()
        }
        .onChange(of: showButtons) { _, isExpanded in
            if !enableDoubleTapExpandedControls && isExpanded {
                showButtons = false
                return
            }

            if isExpanded {
                stopInertia()
                dragOffset = 0
            }
        }
        .onChange(of: expandedControlsMode) { _, newMode in
            if newMode == .timerControls {
                stopInertia()
                dragOffset = 0
            }
            showButtons = false
        }
        .onChange(of: timeOffset) { _, newValue in
            if dragOffset == 0,
               !inertiaActive,
               newValue != snappedToWholeMinute(accumulatedOffset) {
                accumulatedOffset = newValue
            }
        }
        .sheet(isPresented: $showTimeOffsetAdjustmentSheet) {
            ScrollTimeOffsetAdjustmentSheet(
                direction: $pendingOffsetDirection,
                hours: $pendingOffsetHours,
                minutes: $pendingOffsetMinutes,
                onClose: {
                    showTimeOffsetAdjustmentSheet = false
                    triggerControlHaptic(style: .soft)
                },
                onConfirm: confirmTimeOffsetAdjustment
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

// MARK: - Per-Frame Driver
/// Drives at most one callback per display refresh via `CADisplayLink`.
///
/// Used to throttle how often time scrubbing pushes a new `timeOffset` to the
/// city list: the drag gesture and inertia integrator can fire much faster than
/// the screen refreshes, so they only buffer the latest value and this driver
/// flushes it once per frame. Because `CADisplayLink` callbacks are skipped when
/// the main thread is busy, list updates also self-throttle under heavy load.
final class ScrollTimeFrameDriver: NSObject {
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    /// Emits the elapsed time (seconds) since the previous frame, on the main thread.
    let publisher = PassthroughSubject<CFTimeInterval, Never>()

    func start() {
        guard displayLink == nil else { return }
        lastTimestamp = 0
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = 0
    }

    @objc private func step(_ link: CADisplayLink) {
        let now = link.timestamp
        let dt = lastTimestamp == 0 ? link.duration : now - lastTimestamp
        lastTimestamp = now
        publisher.send(dt)
    }

    deinit {
        displayLink?.invalidate()
    }
}

// MARK: - Static Dots Indicator
struct ScrollTimeDotsIndicator: View {
    // Pre-calculated static values - computed once
    private static let dotOpacities: [Double] = {
        let center = 11.5
        let maxDistance = 11.5
        return (0..<24).map { index in
            let distance = abs(Double(index) - center)
            return 1.0 - (distance / maxDistance)
        }
    }()
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<24, id: \.self) { index in
                Capsule()
                    .fill(.primary.opacity(Self.dotOpacities[index]))
                    .frame(width: 2, height: 12)
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
