//
//  HomeView.swift
//  touchtime
//
//  Created on 23/09/2025.
//

import SwiftUI
import Combine
import UIKit
import EventKit
import EventKitUI
import WeatherKit
import UniformTypeIdentifiers
import Shimmer

// Data struct for city time adjustment sheet
struct CityTimeAdjustmentData: Identifiable {
    let id = UUID()
    let cityName: String
    let timeZoneIdentifier: String
}

private struct HomeSkyListRowBackground: View {
    let date: Date
    let timeZoneIdentifier: String
    let weatherCondition: WeatherCondition?
    /// Displayed time minus now, which the stars turn with.
    let timeOffset: TimeInterval

    var body: some View {
        SkyBackgroundView(
            date: date,
            timeZoneIdentifier: timeZoneIdentifier,
            weatherCondition: weatherCondition,
            showRainEffect: true,
            appliesCardChrome: false,
            starsMotion: StarsView.Motion(timeOffset: timeOffset, timeZoneIdentifier: timeZoneIdentifier)
        )
        .skyBackgroundCardChrome()
    }
}

/// Next to a vertical bar (iPhone Duo) a list drops that side's section
/// margin down to the safe area, so its cards run wider than the rest of the
/// screen. Padding the safe area on that side gives the margin back.
@available(iOS 27.1, *)
struct VerticalBarListMargin: ViewModifier {
    let length: CGFloat
    @Environment(\.toolbarVerticalEdge) private var verticalBarEdge

    func body(content: Content) -> some View {
        content.safeAreaPadding(
            verticalBarEdge == .leading ? .leading : .trailing,
            verticalBarEdge == nil ? 0 : length
        )
    }
}

extension View {
    @ViewBuilder
    func verticalBarListMargin(_ length: CGFloat) -> some View {
        if #available(iOS 27.1, *) {
            modifier(VerticalBarListMargin(length: length))
        } else {
            self
        }
    }
}

/// Fades scrolling content out over its last stretch before the fold between
/// iPhone Duo's stacked panes, so it dissolves into the sky behind them
/// instead of ending in a hard edge.
struct FoldEdgeFade: ViewModifier {
    let edge: VerticalEdge

    private static let length: CGFloat = 40

    // Smoothstep opacity ramp: a linear one shows hard bands where the fade
    // starts and ends
    private static let stops: [Gradient.Stop] = (0...8).map { step in
        let location = Double(step) / 8
        return .init(color: .black.opacity(location * location * (3 - 2 * location)), location: location)
    }

    func body(content: Content) -> some View {
        content.mask {
            VStack(spacing: 0) {
                if edge == .top {
                    LinearGradient(stops: Self.stops, startPoint: .top, endPoint: .bottom)
                        .frame(height: Self.length)
                }
                Color.black
                if edge == .bottom {
                    LinearGradient(stops: Self.stops, startPoint: .bottom, endPoint: .top)
                        .frame(height: Self.length)
                }
            }
            // Also covers what the scroll view draws under its bars
            .ignoresSafeArea()
        }
    }
}

extension View {
    @ViewBuilder
    func foldEdgeFade(_ edge: VerticalEdge, isActive: Bool) -> some View {
        if isActive {
            modifier(FoldEdgeFade(edge: edge))
        } else {
            self
        }
    }
}

// MARK: - Lazy Card Image (deferred rendering for ShareLink)
struct LazyCardImage: Transferable {
    let render: () -> UIImage
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { lazy in
            let image = lazy.render()
            guard let data = image.pngData() else {
                throw CocoaError(.fileWriteUnknown)
            }
            return data
        }
    }
}

struct HomeView: View {
    private struct DeletedCitySnapshot {
        struct CollectionPosition {
            let collectionId: UUID
            let cityIndex: Int
        }

        let clock: WorldClock
        let worldClockIndex: Int
        let collectionPositions: [CollectionPosition]
    }

    /// City whose card is being shared as an image. The time is fixed
    /// when the menu item is tapped, so the share preview shows that
    /// moment instead of ticking (and reseeding its stars) every second.
    private struct CityShareData: Identifiable {
        let id = UUID()
        let cityName: String
        let timeZoneIdentifier: String
        /// Wall-clock time and Slide to Adjust offset at the tap.
        let baseDate: Date
        let timeOffset: TimeInterval

        /// The time the card shows.
        var date: Date {
            baseDate.addingTimeInterval(timeOffset)
        }
    }

    /// Pinned countdown whose card is being shared as an image, with the
    /// scrubbed time at the tap so the share screen shows that moment.
    private struct CountdownShareData: Identifiable {
        let id = UUID()
        let item: CountdownItem
        let now: Date
    }

    @Binding var worldClocks: [WorldClock]
    @Binding var timeOffset: TimeInterval
    @Binding var showScrollTimeButtons: Bool
    @ObservedObject var weatherManager: WeatherManager
    @ObservedObject private var googleMeet = GoogleMeetManager.shared
    @State private var currentDate = Date()
    @State private var showingRenameAlert = false
    @State private var renamingClockId: UUID? = nil
    @State private var renamingLocalTime = false
    @State private var newClockName = ""
    @State private var originalClockName = ""
    @State private var showingTimerRenameAlert = false
    @State private var newTimerName = ""
    @State private var showShareSheet = false
    @State private var showSettingsSheet = false
    @State private var showLifetimeStore = false
    @State private var eventStore = EKEventStore()
    @State private var showEventEditor = false
    @State private var eventToEdit: EKEvent?
    @State private var scheduleForTimeZone: String = TimeZone.current.identifier
    @State private var showSunriseSunsetSheet = false
    @State private var selectedTimeZone: String = ""
    @State private var selectedCityName: String = ""
    // iPhone Duo landscape: the list and a city's details side by side
    @State private var isLandscape = false
    // City shown in the detail pane; nil means the local time
    @State private var detailPaneCityId: UUID? = nil
    @State private var showArrangeListSheet = false
    @State private var showSetAlarmSheet = false
    @State private var showSetTimerSheet = false
    @State private var showStopwatchRecordsSheet = false
    @State private var showCountdownSheet = false
    // Pinned countdowns show their preview below the home timer; the shared
    // store is observed, so pins toggled inside the countdown sheet update
    // the cards immediately.
    @Environment(CountdownStore.self) private var countdownStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    // Countdown being edited after tapping its pinned card on Home.
    @State private var editingHomeCountdown: CountdownItem? = nil
    // Pinned countdown being shared as an image from its card's context menu.
    @State private var countdownShareData: CountdownShareData? = nil
    @State private var showComplicationsSheet = false
    @State private var showWidgetIntroSheet = false
    @State private var showEarthView = false
    @State private var cityTimeAdjustmentData: CityTimeAdjustmentData? = nil
    // City card being shared as an image from its context menu.
    @State private var cityShareData: CityShareData? = nil
    @State private var showCalendarPermissionAlert = false
    
    // Collection management
    @State private var collections: [CityCollection] = []
    @State private var selectedCollectionId: UUID? = nil
    @State private var recentlyDeletedCity: DeletedCitySnapshot? = nil
    @AppStorage("selectedCollectionId") private var savedSelectedCollectionId: String = ""
    
    // Computed binding for picker
    private var pickerSelection: Binding<UUID?> {
        Binding(
            get: { selectedCollectionId },
            set: { newValue in
                selectedCollectionId = newValue
                saveSelectedCollection()
                if hapticEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }
        )
    }
    
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("additionalTimeDisplay") private var additionalTimeDisplay = "None"
    @AppStorage("showLocalTime") private var showLocalTime = true
    @AppStorage("customLocalName") private var customLocalName = ""
    @AppStorage("showSkyDot") private var showSkyDot = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("defaultEventDuration") private var defaultEventDuration: Double = 3600 // Default 1 hour in seconds
    @AppStorage("selectedCalendarIdentifier") private var selectedCalendarIdentifier: String = ""
    @AppStorage("addMeetLinkToEvents") private var addMeetLinkToEvents = false
    @AppStorage("availableTimeEnabled") private var availableTimeEnabled = false
    @AppStorage("availableStartTime") private var availableStartTime = "09:00"
    @AppStorage("availableEndTime") private var availableEndTime = "17:00"
    @AppStorage("availableWeekdays") private var availableWeekdays = "2,3,4,5,6" // Default Mon-Fri
    @AppStorage("hasLifetimeAccess") private var hasLifetimeAccess = false
    @AppStorage("dateStyle") private var dateStyle = "Relative"
    @AppStorage("showWeather") private var showWeather = false
    @AppStorage("useCelsius") private var useCelsius = true
    @AppStorage("showAnalogClock") private var showAnalogClock = false
    @AppStorage("analogClockShowScale") private var analogClockShowScale = false
    @AppStorage("showSunPosition") private var showSunPosition = false
    @AppStorage("showWeatherCondition") private var showWeatherCondition = false
    @AppStorage("showTemperatureIndicator") private var showTemperatureIndicator = false
    @AppStorage("showTemperatureRange") private var showTemperatureRange = false
    @AppStorage("showUVIndex") private var showUVIndex = false
    @AppStorage("showWindDirection") private var showWindDirection = false
    @AppStorage("showSunAzimuth") private var showSunAzimuth = false
    @AppStorage("showMoonAzimuth") private var showMoonAzimuth = false
    @AppStorage("showMoonSunAzimuth") private var showMoonSunAzimuth = false
    @AppStorage("showSunriseSunset") private var showSunriseSunset = false
    @AppStorage("showDaylight") private var showDaylight = false
    @AppStorage("showTimeOverlay") private var showTimeOverlay = false
    @AppStorage("showSolarCurve") private var showSolarCurve = false
    @AppStorage("solarCurveShowSun") private var solarCurveShowSun = false
    @AppStorage("showWhatsNewSwipeAdjust") private var showWhatsNewSwipeAdjust = true
    @AppStorage("showShakeToResetTip") private var showShakeToResetTip = false
    @AppStorage("hasTriggeredShakeToResetTip") private var hasTriggeredShakeToResetTip = false
    @AppStorage("showTimeZoneUpdatedTip") private var showTimeZoneUpdatedTip = false
    @AppStorage("lastKnownTimeZoneIdentifier") private var lastKnownTimeZoneIdentifier = ""
    @AppStorage("homeTimerConfiguredSeconds") private var homeTimerConfiguredSeconds = 0
    @AppStorage("homeTimerEndDateEpoch") private var homeTimerEndDateEpoch: Double = 0
    @AppStorage("homeTimerCompletionHandled") private var homeTimerCompletionHandled = false
    @AppStorage("homeTimerPaused") private var homeTimerPaused = false
    @AppStorage("homeTimerPausedRemainingSeconds") private var homeTimerPausedRemainingSeconds = 0
    @AppStorage("homeTimerAlarmID") private var homeTimerAlarmIDRawValue = ""
    @AppStorage("homeTimerName") private var homeTimerName = ""
    @AppStorage("homeStopwatchStartEpoch") private var homeStopwatchStartEpoch: Double = 0
    @AppStorage("homeStopwatchAccumulatedSeconds") private var homeStopwatchAccumulatedSeconds: Double = 0
    @AppStorage("homeStopwatchLapsData") private var homeStopwatchLapsData = Data()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // UserDefaults key for storing world clocks
    private let worldClocksKey = "savedWorldClocks"
    private let collectionsKey = "savedCityCollections"
    
    private var hasConfiguredHomeTimer: Bool {
        homeTimerConfiguredSeconds > 0
    }

    /// True when the current view has countdown cards to show, so the list
    /// still has content without clocks or a timer.
    private var hasPinnedCountdowns: Bool {
        !displayedCountdowns.isEmpty
    }

    private var homeTimerDisplayName: String {
        let trimmedName = homeTimerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? String(localized: "Timer") : trimmedName
    }

    private var homeTimerAlarmID: UUID? {
        UUID(uuidString: homeTimerAlarmIDRawValue)
    }

    private var homeTimerEndDate: Date? {
        guard homeTimerEndDateEpoch > 0 else { return nil }
        return Date(timeIntervalSince1970: homeTimerEndDateEpoch)
    }

    private func homeTimerRemainingFromEndDate(at date: Date) -> Int {
        guard let endDate = homeTimerEndDate else {
            return 0
        }

        let remaining = Int(ceil(endDate.timeIntervalSince(date)))
        return max(remaining, 0)
    }

    private func homeTimerRemainingSeconds(at date: Date) -> Int {
        guard hasConfiguredHomeTimer else {
            return 0
        }

        if homeTimerPaused {
            return max(0, min(homeTimerPausedRemainingSeconds, 59 * 60 + 59))
        }

        return homeTimerRemainingFromEndDate(at: date)
    }

    private func startHomeTimer(
        durationSeconds: Int,
        startPaused: Bool = false,
        requestAlarmAuthorization: Bool = true
    ) {
        let clampedDuration = min(max(durationSeconds, 1), 59 * 60 + 59)
        homeTimerConfiguredSeconds = clampedDuration

        if startPaused {
            homeTimerEndDateEpoch = 0
            homeTimerPaused = true
            homeTimerPausedRemainingSeconds = clampedDuration
        } else {
            homeTimerEndDateEpoch = Date().addingTimeInterval(TimeInterval(clampedDuration)).timeIntervalSince1970
            homeTimerPaused = false
            homeTimerPausedRemainingSeconds = 0
        }

        homeTimerCompletionHandled = false

        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }

        refreshHomeTimerAlarm(
            requestAuthorization: requestAlarmAuthorization
        )
    }

    private func handleHomeTimerTap() {
        guard hasConfiguredHomeTimer else { return }

        let remaining = homeTimerRemainingSeconds(at: Date())
        if remaining == 0 {
            startHomeTimer(durationSeconds: homeTimerConfiguredSeconds)
            return
        }

        if homeTimerPaused {
            let secondsToResume = max(1, min(homeTimerPausedRemainingSeconds, 59 * 60 + 59))
            homeTimerEndDateEpoch = Date().addingTimeInterval(TimeInterval(secondsToResume)).timeIntervalSince1970
            homeTimerPaused = false
            homeTimerPausedRemainingSeconds = 0
            homeTimerCompletionHandled = false
            refreshHomeTimerAlarm(requestAuthorization: true)
        } else {
            homeTimerPausedRemainingSeconds = remaining
            homeTimerPaused = true
            homeTimerEndDateEpoch = 0
            refreshHomeTimerAlarm(requestAuthorization: false)
        }

        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
    }

    private func resetHomeTimer() {
        guard hasConfiguredHomeTimer else { return }
        startHomeTimer(
            durationSeconds: homeTimerConfiguredSeconds,
            startPaused: homeTimerPaused,
            requestAlarmAuthorization: !homeTimerPaused
        )
    }

    private func renameHomeTimer() {
        newTimerName = homeTimerName.trimmingCharacters(in: .whitespacesAndNewlines)
        showingTimerRenameAlert = true

        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
    }

    private func saveHomeTimerName() {
        let trimmedName = newTimerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousName = homeTimerName
        withAnimation(.smooth(duration: 0.25)) {
            homeTimerName = trimmedName
        }
        newTimerName = ""

        // Keep the Timer Recents entry for this timer in sync with the latest name
        RecentTimerStore.renameMatching(
            durationSeconds: homeTimerConfiguredSeconds,
            oldName: RecentTimerStore.normalizedName(previousName),
            newName: RecentTimerStore.normalizedName(trimmedName)
        )

        refreshHomeTimerAlarm(requestAuthorization: false)
    }

    private func clearHomeTimer() {
        homeTimerConfiguredSeconds = 0
        homeTimerEndDateEpoch = 0
        homeTimerCompletionHandled = false
        homeTimerPaused = false
        homeTimerPausedRemainingSeconds = 0
        homeTimerName = ""
        refreshHomeTimerAlarm(requestAuthorization: false)

        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
    }

    private func restoreHomeTimerStateIfNeeded() {
        defer {
            refreshHomeTimerAlarm(requestAuthorization: false)
        }

        if !homeTimerAlarmIDRawValue.isEmpty, homeTimerAlarmID == nil {
            homeTimerAlarmIDRawValue = ""
        }

        let clampedConfiguredSeconds = min(max(homeTimerConfiguredSeconds, 0), 59 * 60 + 59)
        if clampedConfiguredSeconds != homeTimerConfiguredSeconds {
            homeTimerConfiguredSeconds = clampedConfiguredSeconds
        }

        guard clampedConfiguredSeconds > 0 else {
            homeTimerEndDateEpoch = 0
            homeTimerCompletionHandled = false
            homeTimerPaused = false
            homeTimerPausedRemainingSeconds = 0
            return
        }

        if homeTimerPaused {
            let clampedPausedRemaining = min(max(homeTimerPausedRemainingSeconds, 0), 59 * 60 + 59)
            if clampedPausedRemaining != homeTimerPausedRemainingSeconds {
                homeTimerPausedRemainingSeconds = clampedPausedRemaining
            }
            if homeTimerPausedRemainingSeconds == 0 {
                homeTimerPausedRemainingSeconds = clampedConfiguredSeconds
            }
            homeTimerEndDateEpoch = 0
            homeTimerCompletionHandled = homeTimerPausedRemainingSeconds == 0
            return
        }

        if homeTimerEndDateEpoch <= 0 {
            homeTimerEndDateEpoch = Date().addingTimeInterval(TimeInterval(clampedConfiguredSeconds)).timeIntervalSince1970
            homeTimerCompletionHandled = false
            return
        }

        let remaining = homeTimerRemainingFromEndDate(at: Date())
        if remaining == 0 {
            // The timer ran out while this view was away: still count that run
            if !homeTimerCompletionHandled {
                recordHomeTimerCompletion()
            }
        } else {
            homeTimerCompletionHandled = false
        }
    }

    /// Marks the current run as finished, counting it once towards the
    /// usage count of its Recents entry.
    private func recordHomeTimerCompletion() {
        RecentTimerStore.recordCompletion(
            durationSeconds: homeTimerConfiguredSeconds,
            name: RecentTimerStore.normalizedName(homeTimerName)
        )
        homeTimerCompletionHandled = true
    }

    private func refreshHomeTimerAlarm(
        requestAuthorization: Bool
    ) {
        Task {
            await HomeTimerAlarm.refresh(requestAuthorization: requestAuthorization)
        }
    }

    private func handleHomeTimerTick(at now: Date) {
        guard hasConfiguredHomeTimer, !homeTimerPaused else { return }

        let remaining = homeTimerRemainingSeconds(at: now)
        if remaining == 0 {
            guard !homeTimerCompletionHandled else { return }
            recordHomeTimerCompletion()

            if hapticEnabled {
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.prepare()
                notificationFeedback.notificationOccurred(.success)
            }
        } else if homeTimerCompletionHandled {
            homeTimerCompletionHandled = false
        }
    }

    // MARK: - Home Stopwatch

    private var homeStopwatch: StopwatchSnapshot {
        StopwatchSnapshot(
            startEpoch: homeStopwatchStartEpoch,
            accumulatedSeconds: homeStopwatchAccumulatedSeconds,
            laps: StopwatchLapStore.decode(homeStopwatchLapsData)
        )
    }

    /// Start / Stop from the stopwatch card.
    private func handleHomeStopwatchTap() {
        let stopwatch = homeStopwatch
        guard !stopwatch.isFinished else { return }

        if stopwatch.isRunning {
            homeStopwatchAccumulatedSeconds = stopwatch.elapsed(at: Date())
            homeStopwatchStartEpoch = 0
        } else {
            homeStopwatchStartEpoch = Date().timeIntervalSince1970
        }

        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
    }

    /// Start from the Stopwatch records sheet. A session under way is
    /// replaced, going to the records first as Reset sends it.
    private func startNewHomeStopwatch() {
        let now = Date()
        let stopwatch = homeStopwatch
        if stopwatch.hasStarted {
            StopwatchRecordStore.remember(
                totalSeconds: stopwatch.elapsed(at: now),
                laps: stopwatch.laps
            )
        }

        withAnimation(.spring()) {
            homeStopwatchAccumulatedSeconds = 0
            homeStopwatchLapsData = Data()
            homeStopwatchStartEpoch = now.timeIntervalSince1970
        }
    }

    /// Persist the stop once the running total hits 99:59:59.99. The display
    /// is already clamped, so this only has to flip the card's button to play.
    private func finalizeHomeStopwatchIfLimitReached(at now: Date) {
        guard homeStopwatch.hasReachedLimit(at: now) else { return }
        homeStopwatchAccumulatedSeconds = StopwatchSnapshot.maxElapsed
        homeStopwatchStartEpoch = 0
    }

    /// Reset ends the session: its time and laps go to the Stopwatch records
    /// (see `StopwatchRecordsSheet`) before the stopwatch is cleared.
    private func resetHomeStopwatch() {
        let stopwatch = homeStopwatch
        if stopwatch.hasStarted {
            StopwatchRecordStore.remember(
                totalSeconds: stopwatch.elapsed(at: Date()),
                laps: stopwatch.laps
            )
        }

        withAnimation(.spring()) {
            homeStopwatchStartEpoch = 0
            homeStopwatchAccumulatedSeconds = 0
            homeStopwatchLapsData = Data()
        }

        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
    }

    /// Commits edits made in the countdown editor opened from a pinned
    /// Home card, mirroring CountdownSheet's update logic.
    private func updateCountdown(_ item: CountdownItem, title: String, targetDate: Date, emoji: String?, photoData: Data?, photoCrop: CountdownItem.PhotoCrop?, isPinned: Bool, repeatFrequency: CountdownItem.RepeatFrequency, reminderTime: Date?, reminderCity: WorldClock?, reminderLeadDays: Int, reminderKind: CountdownItem.ReminderKind, contact: CountdownItem.LinkedContact?, scheduledMessage: String?, pausedAt: Date?) {
        guard let index = countdownStore.countdowns.firstIndex(where: { $0.id == item.id }) else { return }
        // Assemble the edited item first so the store (and UserDefaults)
        // sees a single mutation instead of one per field.
        var updated = countdownStore.countdowns[index]
        updated.title = title
        updated.targetDate = targetDate
        updated.emoji = emoji
        updated.photoData = photoData
        updated.photoCrop = photoCrop
        updated.isPinned = isPinned
        updated.repeatFrequency = repeatFrequency
        updated.reminderTime = reminderTime
        updated.reminderCity = reminderCity
        updated.reminderLeadDays = reminderLeadDays
        updated.reminderKind = reminderKind
        updated.contact = contact
        updated.scheduledMessage = scheduledMessage
        updated.pausedAt = pausedAt
        withAnimation(.spring()) {
            countdownStore.countdowns[index] = updated
        }
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }

    /// Unpins a countdown from its Home card's context menu; the card
    /// disappears since Home only shows pinned countdowns.
    private func unpinCountdown(_ item: CountdownItem) {
        guard let index = countdownStore.countdowns.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(.spring()) {
            countdownStore.countdowns[index].isPinned = false
        }
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }

    private func deleteCountdown(_ item: CountdownItem) {
        withAnimation(.spring()) {
            countdownStore.countdowns.removeAll { $0.id == item.id }
        }
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }

    private var effectiveShowWeatherCondition: Bool {
        showWeatherCondition
    }

    private var effectiveShowTemperatureIndicator: Bool {
        hasLifetimeAccess && showTemperatureIndicator
    }

    private var effectiveShowTemperatureRange: Bool {
        hasLifetimeAccess && showTemperatureRange
    }

    private var effectiveShowUVIndex: Bool {
        hasLifetimeAccess && showUVIndex
    }

    private var effectiveShowWindDirection: Bool {
        hasLifetimeAccess && showWindDirection
    }

    private var effectiveShowMoonAzimuth: Bool {
        hasLifetimeAccess && showMoonAzimuth
    }

    private var effectiveShowMoonSunAzimuth: Bool {
        hasLifetimeAccess && showMoonSunAzimuth
    }

    private var effectiveShowDaylight: Bool {
        hasLifetimeAccess && showDaylight
    }

    private var effectiveShowTimeOverlay: Bool {
        hasLifetimeAccess && showTimeOverlay && availableTimeEnabled
    }

    private var complicationOptions: ComplicationDisplayOptions {
        ComplicationDisplayOptions(
            showAnalogClock: showAnalogClock,
            analogClockShowScale: analogClockShowScale,
            showSunPosition: showSunPosition,
            showWeatherCondition: effectiveShowWeatherCondition,
            showTemperatureIndicator: effectiveShowTemperatureIndicator,
            showTemperatureRange: effectiveShowTemperatureRange,
            showUVIndex: effectiveShowUVIndex,
            showWindDirection: effectiveShowWindDirection,
            showSunAzimuth: showSunAzimuth,
            showMoonAzimuth: effectiveShowMoonAzimuth,
            showMoonSunAzimuth: effectiveShowMoonSunAzimuth,
            showSunriseSunset: showSunriseSunset,
            showDaylight: effectiveShowDaylight,
            showTimeOverlay: effectiveShowTimeOverlay,
            showSolarCurve: showSolarCurve,
            solarCurveShowSun: solarCurveShowSun
        )
    }

    private var hasVisibleComplication: Bool {
        complicationOptions.hasVisibleComplication
    }
    
    // Get local city name from timezone
    var localCityName: String {
        let identifier = TimeZone.current.identifier
        let components = identifier.split(separator: "/")
        let cityName: String
        if components.count >= 2 {
            cityName = components.last!.replacingOccurrences(of: "_", with: " ")
        } else {
            cityName = identifier
        }
        // Return localized city name
        return String(localized: String.LocalizationValue(cityName))
    }
    
    // Get original city name from timezone identifier
    func getOriginalCityName(from identifier: String) -> String {
        let components = identifier.split(separator: "/")
        if components.count >= 2 {
            return components.last!.replacingOccurrences(of: "_", with: " ")
        } else {
            return String(components[0])
        }
    }
    
    // Get localized city name for display (using WorldClock's localizedCityName property)
    func getLocalizedCityName(for clock: WorldClock) -> String {
        return clock.localizedCityName
    }
    
    // Get displayed clocks based on selected collection
    var displayedClocks: [WorldClock] {
        if let collectionId = selectedCollectionId,
           let collection = collections.first(where: { $0.id == collectionId }) {
            return collection.cities
        }
        return worldClocks // Default - show all cities
    }
    
    // Get displayed pinned countdowns based on selected collection: every
    // pinned countdown on All Cities, only the ones added to the collection
    // otherwise, both in the order arranged in ArrangeListView
    var displayedCountdowns: [CountdownItem] {
        let pinned = countdownStore.pinnedCountdowns(at: currentDate.addingTimeInterval(timeOffset))
        if let collectionId = selectedCollectionId,
           let collection = collections.first(where: { $0.id == collectionId }) {
            return pinned.filter { collection.contains(countdownId: $0.id) }
        }
        return pinned // Default - show all pinned countdowns
    }
    
    // Current collection name for display
    var currentCollectionName: String {
        if let collectionId = selectedCollectionId,
           let collection = collections.first(where: { $0.id == collectionId }) {
            return collection.name
        }
        return String(localized: "All Cities")
    }
    
    // Quick Switch Collections
    // Cycle to the next collection (Collection 1 -> Collection 2 -> ... -> Collection 1)
    func cycleToNextCollection() {
        guard !collections.isEmpty else { return }
        
        if let currentId = selectedCollectionId,
           let currentIndex = collections.firstIndex(where: { $0.id == currentId }) {
            // Currently on a collection, go to the next one or wrap to first
            let nextIndex = (currentIndex + 1) % collections.count
            selectedCollectionId = collections[nextIndex].id
        } else {
            // Currently on All Cities, go to the first collection
            selectedCollectionId = collections.first?.id
        }
        
        saveSelectedCollection()
        
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    // Load collections from UserDefaults
    func loadCollections() {
        if let data = UserDefaults.standard.data(forKey: collectionsKey),
           let decoded = try? JSONDecoder().decode([CityCollection].self, from: data) {
            collections = decoded
        } else {
            // Clear collections if no data in UserDefaults
            collections = []
        }
        
        // Load saved selection
        if !savedSelectedCollectionId.isEmpty,
           let uuid = UUID(uuidString: savedSelectedCollectionId) {
            selectedCollectionId = uuid
        } else {
            // Clear selection if no saved ID
            selectedCollectionId = nil
        }
    }
    
    // Save selected collection
    func saveSelectedCollection() {
        savedSelectedCollectionId = selectedCollectionId?.uuidString ?? ""
    }
    
    // Save collections to UserDefaults
    func saveCollections() {
        if let encoded = try? JSONEncoder().encode(collections) {
            UserDefaults.standard.set(encoded, forKey: collectionsKey)
        }
    }
    
    // Add to Calendar - opens system event editor for a specific time zone
    func addToCalendar(timeZoneIdentifier: String, cityName: String) {
        // Request calendar permission
        eventStore.requestFullAccessToEvents { granted, error in
            guard granted, error == nil else {
                print("Calendar access denied or error: \(String(describing: error))")
                DispatchQueue.main.async {
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
                await self.prepareAndPresentEvent(timeZoneIdentifier: timeZoneIdentifier, cityName: cityName)
            }
        }
    }

    // Build the event (notes + optional Google Meet link) and present the editor
    @MainActor
    private func prepareAndPresentEvent(timeZoneIdentifier: String, cityName: String) async {
        // Create event with adjusted time
        let event = EKEvent(eventStore: eventStore)

        // Calculate the adjusted start time for the selected timezone
        let currentDate = Date()
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Get the current time in the target timezone
        let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current

        // Calculate time in target timezone adjusted by the offset
        let adjustedDate = currentDate.addingTimeInterval(timeOffset)

        // Set the start date
        event.startDate = adjustedDate

        // Set end date with user-configured default duration
        event.endDate = adjustedDate.addingTimeInterval(defaultEventDuration)

        // Set calendar - use selected calendar if available, otherwise default
        if !selectedCalendarIdentifier.isEmpty,
           let selectedCalendar = eventStore.calendars(for: .event).first(where: { $0.calendarIdentifier == selectedCalendarIdentifier }) {
            event.calendar = selectedCalendar
        } else {
            event.calendar = eventStore.defaultCalendarForNewEvents
        }

        // Add notes with the city and time information
        formatter.timeZone = targetTimeZone
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

        // Reset locale
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Build notes: city time first, then optionally a Google Meet link below it.
        var noteSections: [String] = [
            String(format: String(localized: "Time in %@: %@ · %@"), cityName, timeString, dateString)
        ]
        if addMeetLinkToEvents,
           googleMeet.isSignedIn,
           let meetLink = try? await googleMeet.createMeetLink() {
            noteSections.append(String(localized: "Google Meet:") + "\n" + meetLink)
        }
        event.notes = noteSections.joined(separator: "\n\n")

        // Store the event and show the editor
        eventToEdit = event
        scheduleForTimeZone = timeZoneIdentifier
        showEventEditor = true
    }
    
    // Get formatted date for city with Natural Dates setting
    /// `currentDate + timeOffset`, floored to the whole minute.
    ///
    /// Sky colors and the astronomical complications (sunrise/sunset, sun/moon
    /// position, daylight, analog clock, …) only change at minute granularity.
    /// Feeding them a value that still carries the seconds component forces SwiftUI
    /// to re-evaluate those (expensive) subtrees on every body pass, even when the
    /// minute hasn't changed. Quantizing to the minute keeps identical inputs equal
    /// so SwiftUI can skip re-rendering those subtrees.
    func getCityDate(timeZoneIdentifier: String, baseDate: Date, offset: TimeInterval) -> String {
        guard let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return ""
        }
        
        // The adjusted time for the target timezone
        let adjustedTime = baseDate.addingTimeInterval(offset)
        
        return adjustedTime.formattedDate(
            style: dateStyle,
            timeZone: targetTimeZone,
            relativeTo: baseDate
        )
    }

    // Copy time as text
    func copyTimeAsText(cityName: String, timeZoneIdentifier: String) {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        if use24HourFormat {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "h:mma"
        }
        
        let adjustedDate = currentDate.addingTimeInterval(timeOffset)
        let timeString = formatter.string(from: adjustedDate).lowercased()
        let textToCopy = "\(cityName) \(timeString)"
        
        UIPasteboard.general.string = textToCopy
        
        // Provide haptic feedback if enabled
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
    }
    
    // MARK: - Context Menus
    @ViewBuilder
    private func localTimeContextMenu() -> some View {
        ControlGroup {
            Button(action: {
                cityTimeAdjustmentData = CityTimeAdjustmentData(
                    cityName: String(localized: "Local"),
                    timeZoneIdentifier: TimeZone.current.identifier
                )
            }) {
                Label(String(localized: "Set Alarm"), systemImage: "alarm")
            }
            
            Button(action: {
                let cityName = String(localized: "Local")
                addToCalendar(timeZoneIdentifier: TimeZone.current.identifier, cityName: cityName)
            }) {
                Label("Schedule Event", systemImage: "plus.circle")
            }
        }
        
        Divider()
        
        Menu {
            Button(action: {
                let cityName = String(localized: "Local")
                copyTimeAsText(cityName: cityName, timeZoneIdentifier: TimeZone.current.identifier)
            }) {
                Label(String(localized: "Copy as Text"), systemImage: "quote.opening")
            }
            Button(action: {
                shareCardAsImage(cityName: String(localized: "Local"), timeZoneIdentifier: TimeZone.current.identifier)
            }) {
                Label(String(localized: "Share as Image"), systemImage: "camera.macro")
            }
        } label: {
            Label(String(localized: "Share"), systemImage: "square.and.arrow.up") // Local Share
        }
    }
    
    @ViewBuilder
    private func cityContextMenu(for clock: WorldClock) -> some View {
        ControlGroup {
            Button(action: {
                cityTimeAdjustmentData = CityTimeAdjustmentData(
                    cityName: getLocalizedCityName(for: clock),
                    timeZoneIdentifier: clock.timeZoneIdentifier
                )
            }) {
                Label(String(localized: "Set Alarm"), systemImage: "alarm")
            }
            
            // Schedule event
            Button(action: {
                addToCalendar(timeZoneIdentifier: clock.timeZoneIdentifier, cityName: getLocalizedCityName(for: clock))
            }) {
                Label("Schedule Event", systemImage: "plus.circle")
            }
        }
        
        Divider()
        
        Menu {
            Button(action: {
                copyTimeAsText(cityName: getLocalizedCityName(for: clock), timeZoneIdentifier: clock.timeZoneIdentifier)
            }) {
                Label(String(localized: "Copy as Text"), systemImage: "quote.opening")
            }
            Button(action: {
                shareCardAsImage(cityName: getLocalizedCityName(for: clock), timeZoneIdentifier: clock.timeZoneIdentifier)
            }) {
                Label(String(localized: "Share as Image"), systemImage: "camera.macro")
            }
        } label: {
            Label(String(localized: "Share"), systemImage: "square.and.arrow.up") // City Share
        }
        
        // Rename
        Button(action: {
            renamingClockId = clock.id
            // Get original name from timezone identifier
            let identifier = clock.timeZoneIdentifier
            let components = identifier.split(separator: "/")
            let rawName = components.count >= 2
            ? String(components.last!).replacingOccurrences(of: "_", with: " ")
            : String(identifier)
            originalClockName = String(localized: String.LocalizationValue(rawName))
            newClockName = clock.localizedCityName
            showingRenameAlert = true
        }) {
            Label("Rename", systemImage: "pencil.tip.crop.circle")
        }
        
        Divider()
        
        // Move to Top (only for default view)
        if selectedCollectionId == nil {
            if let index = worldClocks.firstIndex(where: { $0.id == clock.id }), index != 0 {
                Button(action: {
                    // Move to top
                    withAnimation {
                        let clockToMove = worldClocks.remove(at: index)
                        worldClocks.insert(clockToMove, at: 0)
                        saveWorldClocks()
                    }
                }) {
                    Label(String(localized: "Move to Top"), systemImage: "arrow.up.to.line")
                }
            }
        }
        
        // Arrange Cities
        Button {
            showArrangeListSheet = true
        } label: {
            Label(String(localized: "Arrange"), systemImage: "list.bullet")
        }
        
        // Only show delete for default view
        if selectedCollectionId == nil {
            Divider()
            
            Button(role: .destructive, action: {
                // Delete
                withAnimation {
                    deleteCity(withId: clock.id)
                }
            }) {
                Label("Delete", systemImage: "xmark.circle")
            }
        }
    }
    
    // MARK: - Share as Image
    
    /// Opens the share-as-image screen for a city card, fixing the time it
    /// shows at this moment.
    private func shareCardAsImage(cityName: String, timeZoneIdentifier: String) {
        cityShareData = CityShareData(
            cityName: cityName,
            timeZoneIdentifier: timeZoneIdentifier,
            baseDate: currentDate,
            timeOffset: timeOffset
        )
    }
    
    /// The share card for a city at the export size of the given frame: the
    /// row's card replica on its sky backdrop, with the local time as the
    /// footer. Built here because it reads the same settings as the rows;
    /// the share screen previews it live and renders it for the file.
    private func cityShareCard(for share: CityShareData, aspectRatio: ShareAspectRatio, frameCornerRadius: CGFloat = 0) -> some View {
        let timeZoneIdentifier = share.timeZoneIdentifier
        let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
        let weather = showWeather ? weatherManager.weatherData[timeZoneIdentifier] : nil
        let clock = WorldClock(cityName: share.cityName, timeZoneIdentifier: timeZoneIdentifier)
        
        return CityCardSnapshotView(
            cityName: share.cityName,
            timeString: RowTimeFormat.time(
                date: share.baseDate,
                offset: share.timeOffset,
                timeZone: targetTimeZone,
                use24Hour: use24HourFormat
            ),
            localCityName: localCityName,
            localTimeString: RowTimeFormat.time(
                date: share.baseDate,
                offset: share.timeOffset,
                timeZone: TimeZone.current,
                use24Hour: use24HourFormat
            ),
            dateString: getCityDate(
                timeZoneIdentifier: timeZoneIdentifier,
                baseDate: share.baseDate,
                offset: share.timeOffset
            ),
            date: share.date,
            timeZone: targetTimeZone,
            timeZoneIdentifier: timeZoneIdentifier,
            weather: weather,
            weatherCondition: weather?.condition,
            useCelsius: useCelsius,
            complications: complicationOptions,
            additionalTimeDisplay: additionalTimeDisplay,
            showSkyDot: showSkyDot,
            additionalTimeText: RowTimeFormat.additionalText(
                for: clock,
                display: additionalTimeDisplay,
                baseDate: share.baseDate,
                offset: share.timeOffset
            ),
            aspectRatio: aspectRatio,
            frameCornerRadius: frameCornerRadius
        )
        .environmentObject(weatherManager)
        .environment(\.colorScheme, .dark)
    }
    
    /// Renders the city share card into the image that gets saved or
    /// shared, falling back to a placeholder if rendering fails.
    private func renderCityShareImage(for share: CityShareData, aspectRatio: ShareAspectRatio) -> UIImage {
        let renderer = ImageRenderer(content: cityShareCard(for: share, aspectRatio: aspectRatio))
        renderer.scale = 3
        return renderer.uiImage ?? UIImage(systemName: "photo") ?? UIImage()
    }
    
    /// On iPhone Duo a city's details share the screen with the list instead
    /// of opening as a sheet: side by side in landscape, and stacked on the
    /// unfolded screen in portrait, flat or partially open, the details above
    /// the fold and the list below it.
    private var splitAxis: Axis? {
        guard #available(iOS 27.1, *) else { return nil }
        if isLandscape {
            return .horizontal
        }
        return horizontalSizeClass == .regular ? .vertical : nil
    }

    private var usesSplitLayout: Bool {
        splitAxis != nil
    }

    /// The city in the detail pane: the tapped row while it's still listed,
    /// otherwise the first row.
    private var detailPaneCity: (name: String, timeZoneIdentifier: String)? {
        if let cityId = detailPaneCityId,
           let clock = displayedClocks.first(where: { $0.id == cityId }) {
            return (getLocalizedCityName(for: clock), clock.timeZoneIdentifier)
        }
        if showLocalTime {
            return (String(localized: "Local"), TimeZone.current.identifier)
        }
        if let clock = displayedClocks.first {
            return (getLocalizedCityName(for: clock), clock.timeZoneIdentifier)
        }
        return nil
    }

    var body: some View {
        Group {
            if #available(iOS 27.1, *), let splitAxis {
                ArrangementView {
                    cityDetailPane
                } secondary: {
                    homeContent
                }
                .arrangementViewStyle(.split.axes(splitAxis == .horizontal ? .horizontal : .vertical))
                .background { splitSkyBackground }
            } else {
                homeContent
            }
        }
        .background {
            // Measures the whole window, so the keyboard can't make a portrait
            // screen look wide
            Color.clear
                .ignoresSafeArea()
                .onGeometryChange(for: Bool.self) { proxy in
                    proxy.size.width > proxy.size.height
                } action: { isWide in
                    isLandscape = isWide
                }
        }
        // The detail pane takes over from the details sheet
        .onChange(of: usesSplitLayout) { _, usesSplitLayout in
            if usesSplitLayout {
                showSunriseSunsetSheet = false
            }
        }
    }

    /// The widest iPhone's width, for the list column on wider screens.
    private static let maximumColumnWidth: CGFloat = 440

    /// On a wide screen without the details beside it (the unfolded iPhone
    /// Duo in portrait, flat or partially open) the list and Slide to Adjust
    /// keep to a phone-wide column.
    private var usesPhoneColumn: Bool {
        horizontalSizeClass == .regular && splitAxis != .horizontal
    }

    // Fades in from 20% of the way across the window to full at 80%.
    // Smoothstep opacity ramp: a linear one shows hard bands where the fade
    // starts and ends
    private static let splitSkyFadeStops: [Gradient.Stop] = (0...8).map { step in
        let progress = Double(step) / 8
        return .init(color: .black.opacity(progress * progress * (3 - 2 * progress)), location: 0.2 + progress * 0.6)
    }

    /// Behind both panes: the detail pane city's sky, fading in from under
    /// the list to full strength on the left, or at the top when stacked.
    private var splitSkyBackground: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)

            if showSkyDot, let city = detailPaneCity {
                SkyBackgroundView(
                    date: currentDate.addingTimeInterval(timeOffset),
                    timeZoneIdentifier: city.timeZoneIdentifier,
                    weatherCondition: showWeather ? weatherManager.weatherData[city.timeZoneIdentifier]?.condition : nil,
                    appliesCardChrome: false,
                    // Full screen, like the Clock tab's sky
                    starCount: 150,
                    starsMotion: StarsView.Motion(timeOffset: timeOffset, timeZoneIdentifier: city.timeZoneIdentifier)
                )
                .mask {
                    LinearGradient(
                        stops: Self.splitSkyFadeStops,
                        startPoint: splitAxis == .vertical ? .bottom : .trailing,
                        endPoint: splitAxis == .vertical ? .top : .leading
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var cityDetailPane: some View {
        if let city = detailPaneCity {
            SunriseSunsetSheet(
                cityName: city.name,
                timeZoneIdentifier: city.timeZoneIdentifier,
                initialDate: currentDate,
                timeOffset: timeOffset,
                splitAxis: splitAxis
            )
            .environmentObject(weatherManager)
            // Above the list its cards line up with the list's: they sit 16pt
            // inside the pane, the list's 20pt inside the column
            .frame(maxWidth: usesPhoneColumn ? Self.maximumColumnWidth - 8 : nil)
            .frame(maxWidth: .infinity)
        } else {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
        }
    }

    private var homeContent: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ShakeDetectorView {
                    withAnimation(.spring()) {
                        restoreLastDeletedCity()
                    }
                }
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                
                // Blank View
                if displayedClocks.isEmpty && !showLocalTime && !hasConfiguredHomeTimer && !homeStopwatch.hasStarted && !hasPinnedCountdowns {
                    // Empty state view
                    ContentUnavailableView {
                        Label("Nothing here", systemImage: selectedCollectionId != nil ? "questionmark.folder" : "location.magnifyingglass")
                    } description: {
                        Text(selectedCollectionId != nil ? "No cities in this collection." : "Add cities to track time.")
                    } actions: {
                        if selectedCollectionId != nil {
                            Button {
                                if hapticEnabled {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                                showArrangeListSheet = true
                            } label: {
                                Text("Add Cities")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .glassEffect(.clear.interactive())
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                    .background(Color.clear)
                    .id("empty-\(selectedCollectionId?.uuidString ?? "")")
                    .transition(.identity) // Collection Animation
                    
                } else {
                    // Main List Content
                    List {
                        
                        // Time Zone Updated Tip (shown after the device's time zone changes)
                        if showLocalTime && showTimeZoneUpdatedTip {
                            Section {
                                HStack(spacing: 16) {
                                    Image(systemName: "clock.badge.airplane")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                        .blendMode(.plusLighter)
                                        .frame(width: 24, height: 24)
                                    
                                    Text(String(localized: "Time zone updated"))
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "xmark")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .frame(width: 24, height: 24)
                                }
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                                        .fill(Color.black.opacity(0.10))
                                        .glassEffect(.clear.interactive(),
                                                     in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        showTimeZoneUpdatedTip = false
                                    }
                                    if hapticEnabled {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                                        impactFeedback.impactOccurred()
                                    }
                                }
                            }
                        }
                        
                        // Shake to Reset Tip (shown after first city deletion)
                        if showShakeToResetTip {
                            Section {
                                HStack(spacing: 16) {
                                    Image(systemName: "iphone.radiowaves.left.and.right")
                                        .symbolEffect(.wiggle.clockwise.byLayer, options: .repeat(.periodic(delay: 1.0)))
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                        .blendMode(.plusLighter)
                                        .frame(width: 24, height: 24)
                                    
                                    Text(String(localized: "Shake device to undo"))
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "xmark")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .frame(width: 24, height: 24)
                                }
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                                        .fill(Color.black.opacity(0.10))
                                        .glassEffect(.clear.interactive(),
                                                     in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        showShakeToResetTip = false
                                    }
                                    if hapticEnabled {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                                        impactFeedback.impactOccurred()
                                    }
                                }
                            }
                        }
                        
                        // What's New Section
                        if showWhatsNewSwipeAdjust {
                            Section {
                                HStack(spacing: 16) {
                                    Image(systemName: "hand.draw.fill")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                        .blendMode(.plusLighter)
                                        .frame(width: 24, height: 24)
                                    
                                    Text("Swipe right for precise time adjustment or set alarms")
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "xmark")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .frame(width: 24, height: 24)
                                }
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                                        .fill(Color.black.opacity(0.10))
                                        .glassEffect(.clear.interactive(),
                                                     in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        showWhatsNewSwipeAdjust = false
                                    }
                                    if hapticEnabled {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                                        impactFeedback.impactOccurred()
                                    }
                                }
                            }
                        }
                        
                        // Home Timer Section
                        if hasConfiguredHomeTimer {
                            HomeTimerSection(
                                timerName: homeTimerDisplayName,
                                configuredSeconds: homeTimerConfiguredSeconds,
                                endDateEpoch: homeTimerEndDateEpoch,
                                isPaused: homeTimerPaused,
                                pausedRemainingSeconds: homeTimerPausedRemainingSeconds,
                                onRename: renameHomeTimer,
                                onTap: handleHomeTimerTap,
                                onReset: resetHomeTimer,
                                onDelete: clearHomeTimer
                            )
                        }

                        // Home Stopwatch Section
                        if homeStopwatch.hasStarted {
                            HomeStopwatchSection(
                                stopwatch: homeStopwatch,
                                onTap: handleHomeStopwatchTap,
                                onReset: resetHomeStopwatch
                            )
                        }
                        
                        // Countdown Preview Section: pinned countdowns live below the
                        // timer, narrowed to the selected collection like the cities
                        HomeCountdownSection(
                            countdowns: displayedCountdowns,
                            now: currentDate.addingTimeInterval(timeOffset),
                            onTap: { item in
                                if hapticEnabled {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                                editingHomeCountdown = item
                            },
                            onUnpin: { item in
                                unpinCountdown(item)
                            },
                            onShare: { item in
                                countdownShareData = CountdownShareData(
                                    item: item,
                                    now: currentDate.addingTimeInterval(timeOffset)
                                )
                            }
                        )
                        
                        // Local Time Section
                        if showLocalTime {
                            Section {
                                LocalTimeRowContent(
                                    currentDate: $currentDate,
                                    timeOffset: $timeOffset,
                                    complicationOptions: complicationOptions,
                                    weatherManager: weatherManager
                                )
                                .listRowBackground(
                                    showSkyDot ? RowSkyBackground(
                                        timeZoneIdentifier: TimeZone.current.identifier,
                                        currentDate: $currentDate,
                                        timeOffset: $timeOffset,
                                        weatherManager: weatherManager
                                    ) : nil
                                )
                                // The row only redraws when the minute changes, so a new
                                // time zone needs a fresh row to show its time right away
                                .id("local-\(showSkyDot)-\(lastKnownTimeZoneIdentifier)")
                                
                                // Tap gesture for local time
                                .onTapGesture {
                                    selectedTimeZone = TimeZone.current.identifier
                                    selectedCityName = String(localized: "Local")
                                    detailPaneCityId = nil
                                    if !usesSplitLayout {
                                        showSunriseSunsetSheet = true
                                    }
                                    
                                    // Provide haptic feedback if enabled
                                    if hapticEnabled {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                                        impactFeedback.impactOccurred()
                                    }
                                }
                                
                                // Swipe to adjust time (leading edge - swipe right) for local time
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        cityTimeAdjustmentData = CityTimeAdjustmentData(
                                            cityName: String(localized: "Local"),
                                            timeZoneIdentifier: TimeZone.current.identifier
                                        )
                                        
                                        if hapticEnabled {
                                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                            impactFeedback.impactOccurred()
                                        }
                                    } label: {
                                        Label("", systemImage: "clock.fill")
                                    }
                                    .tint(.blue)
                                }
                                
                                // Menu Local Time
                                .contextMenu {
                                    localTimeContextMenu()
                                }
                            }
                        }
                        
                        // Add Cities button when collection only has local time
                        if showLocalTime && displayedClocks.isEmpty && selectedCollectionId != nil {
                            Section {
                                Button {
                                    showArrangeListSheet = true
                                    if hapticEnabled {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                        impactFeedback.impactOccurred()
                                    }
                                } label: {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "plus")
                                            .font(.system(size: 20).weight(.medium))
                                            .foregroundStyle(.secondary)
                                            .blendMode(.plusLighter)
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(
                                    Capsule()
                                        .fill(.clear)
                                        .glassEffect(.clear)
                                )
                            }
                        }
                        
                        // City list
                        ForEach(displayedClocks) { clock in
                            Section {
                                CityRowContent(
                                    clock: clock,
                                    currentDate: $currentDate,
                                    timeOffset: $timeOffset,
                                    complicationOptions: complicationOptions,
                                    weatherManager: weatherManager
                                )
                                .listRowBackground(
                                    showSkyDot ? RowSkyBackground(
                                        timeZoneIdentifier: clock.timeZoneIdentifier,
                                        currentDate: $currentDate,
                                        timeOffset: $timeOffset,
                                        weatherManager: weatherManager
                                    ) : nil
                                )
                                .id("\(clock.id)-\(showSkyDot)")
                                
                                // Tap gesture for world clock
                                .onTapGesture {
                                    selectedTimeZone = clock.timeZoneIdentifier
                                    selectedCityName = getLocalizedCityName(for: clock)
                                    detailPaneCityId = clock.id
                                    if !usesSplitLayout {
                                        showSunriseSunsetSheet = true
                                    }
                                    
                                    // Provide haptic feedback if enabled
                                    if hapticEnabled {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                                        impactFeedback.prepare()
                                        impactFeedback.impactOccurred()
                                    }
                                }
                                
                                // Swipe to adjust time (leading edge - swipe right)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        cityTimeAdjustmentData = CityTimeAdjustmentData(
                                            cityName: getLocalizedCityName(for: clock),
                                            timeZoneIdentifier: clock.timeZoneIdentifier
                                        )
                                        
                                        if hapticEnabled {
                                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                            impactFeedback.impactOccurred()
                                        }
                                    } label: {
                                        Label("", systemImage: "clock.fill")
                                    }
                                    .tint(.blue)
                                }
                                
                                //Swipe to delete time (only for default view)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if selectedCollectionId == nil {
                                        Button(role: .destructive) {
                                            deleteCity(withId: clock.id)
                                        } label: {
                                            Label("", systemImage: "xmark.circle")
                                        }
                                    }
                                }
                                
                                // Context Menu
                                .contextMenu {
                                    cityContextMenu(for: clock)
                                }
                            }
                        }
                    }
                    .listSectionSpacing(12) // List Paddings
                    .scrollIndicators(.hidden)
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .safeAreaPadding(.bottom, 52)
                    // Same width as Slide to Adjust beside the vertical bar
                    .verticalBarListMargin(20)
                    // In regular width the list drops its side margins; the
                    // phone-wide column keeps a phone's
                    .safeAreaPadding(.horizontal, usesPhoneColumn ? 20 : 0)
                    // Below the details it fades in from the fold
                    .foldEdgeFade(.top, isActive: splitAxis == .vertical)
                    .id(selectedCollectionId?.uuidString ?? "default")
                    .transition(.identity) // Collection Animation
                    // Centralized batch weather prefetch for all displayed cities
                    .task(id: "\(displayedClocks.map(\.timeZoneIdentifier))_\(showWeather)_\(effectiveShowWeatherCondition)_\(effectiveShowTemperatureIndicator)_\(effectiveShowUVIndex)_\(effectiveShowWindDirection)_\(showSkyDot)") {
                        if showWeather || effectiveShowWeatherCondition || effectiveShowTemperatureIndicator || effectiveShowUVIndex || effectiveShowWindDirection {
                            var identifiers = displayedClocks.map(\.timeZoneIdentifier)
                            if showLocalTime {
                                identifiers.insert(TimeZone.current.identifier, at: 0)
                            }
                            await weatherManager.getWeatherForCities(identifiers)
                        }
                    }
                }
                
                
                // Scroll Time View - Hide when renaming or when there's no content to display
                if !showingRenameAlert && !(displayedClocks.isEmpty && !showLocalTime) {
                    ScrollTimeView(
                        timeOffset: $timeOffset,
                        showButtons: $showScrollTimeButtons,
                        worldClocks: $worldClocks,
                        enableDoubleTapExpandedControls: true,
                        onAlarmTap: {
                            showSetAlarmSheet = true
                        },
                        onTimerTap: {
                            showSetTimerSheet = true
                        },
                        onCountdownTap: {
                            showCountdownSheet = true
                        },
                        onStopwatchTap: {
                            showStopwatchRecordsSheet = true
                        }
                    )
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .transition(.blurReplace())
                }
            }
            .frame(maxWidth: usesPhoneColumn ? Self.maximumColumnWidth : nil)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    // Base system background. Beside the detail pane the split's
                    // sky background shows through instead
                    if !usesSplitLayout {
                        Color(UIColor.systemGroupedBackground)
                            .ignoresSafeArea()
                    }
                    
                    // Sky Background Effect for System Time
                    if showLocalTime && showSkyDot && !usesSplitLayout {
                        VStack {
                            LocalSkyGlowBackground(
                                currentDate: $currentDate,
                                timeOffset: $timeOffset,
                                weatherManager: weatherManager
                            )
                            
                            Spacer()
                        }
                        .ignoresSafeArea()
                    }
                }
            )
            
            // Animations
            .animation(.spring(), value: showingRenameAlert)
            .animation(.spring(), value: customLocalName)
            .animation(.spring(), value: worldClocks)
            .animation(.spring(), value: showSkyDot)
            .animation(.spring(), value: showLocalTime)
            .animation(.spring(), value: hasLifetimeAccess && availableTimeEnabled)
            .animation(.spring(), value: showWhatsNewSwipeAdjust)
            .animation(.spring(), value: showShakeToResetTip)
            .animation(.spring(), value: showTimeZoneUpdatedTip)
            .animation(.snappy(), value: selectedCollectionId) // Collection Animation
            
            .ignoresSafeArea(.keyboard, edges: .bottom)
            // Lets the split's sky background show through the stack
            .containerBackground(usesSplitLayout ? .clear : Color(UIColor.systemGroupedBackground), for: .navigation)
            
            // Navigation Title
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            
            .toolbar {
                // Collection Name - Tappable to cycle through collections
                if selectedCollectionId != nil && collections.count > 1 {
                    ToolbarItem(placement: .principal) {
                        Button {
                            cycleToNextCollection()
                        } label: {
                            Text(currentCollectionName)
                                .font(.subheadline.weight(.semibold))
                                .contentTransition(.numericText())
                                .padding(.horizontal, 16)
                                .frame(height: 44)
                                .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
                                .lineLimit(1)
                                .animation(.snappy, value: currentCollectionName)
                        }
                        .buttonStyle(.plain)
                    }
                } else if selectedCollectionId != nil {
                    // Show non-tappable collection name when only one collection exists
                    ToolbarItem(placement: .principal) {
                        Text(currentCollectionName)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .glassEffect(.regular, in: Capsule(style: .continuous))
                            .lineLimit(1)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if !hasLifetimeAccess {
                            Button(action: {
                                if hapticEnabled {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.prepare()
                                    impactFeedback.impactOccurred()
                                }
                                showLifetimeStore = true
                            }) {
                                Text(String(localized: "Lifetime"))
                                Text(String(localized: "Unlock all features"))
                                Image(systemName: "heart")
                            }
                            
                            Divider()
                        }

                        // Collections
                        if !collections.isEmpty {
                            Button {
                                selectedCollectionId = nil
                                saveSelectedCollection()
                                if hapticEnabled {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                            } label: {
                                Label("All Cities", systemImage: selectedCollectionId == nil ? "checkmark.circle" : "")
                            }
                            
                            ForEach(collections) { collection in
                                Button {
                                    selectedCollectionId = collection.id
                                    saveSelectedCollection()
                                    if hapticEnabled {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                        impactFeedback.impactOccurred()
                                    }
                                } label: {
                                    Label(collection.name, systemImage: selectedCollectionId == collection.id ? "checkmark.circle" : "")
                                }
                            }
                            Divider()
                        }
                        
                        // Share Section - entry stays even with nothing to share
                        Button(action: {
                            // Provide haptic feedback if enabled
                            if hapticEnabled {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.prepare()
                                impactFeedback.impactOccurred()
                            }
                            showShareSheet = true
                        }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        
                        // Arrange Section - only show if there are world clocks or collections
                        if !worldClocks.isEmpty || !collections.isEmpty {
                            Button(action: {
                                if hapticEnabled {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.prepare()
                                    impactFeedback.impactOccurred()
                                }
                                showArrangeListSheet = true
                            }) {
                                Label(String(localized: "Arrange"), systemImage: "list.bullet")
                            }
                        }

                        // Settings Section
                        Button(action: {
                            if hapticEnabled {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.prepare()
                                impactFeedback.impactOccurred()
                            }
                            showSettingsSheet = true
                        }) {
                            Label("Settings", systemImage: "gear")
                        }

                        Section(String(localized: "Tools")) {
                            Button(action: {
                                if hapticEnabled {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.prepare()
                                    impactFeedback.impactOccurred()
                                }
                                showSetAlarmSheet = true
                            }) {
                                Label(String(localized: "Alarms"), systemImage: "alarm")
                            }

                            Button(action: {
                                if hapticEnabled {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.prepare()
                                    impactFeedback.impactOccurred()
                                }
                                showSetTimerSheet = true
                            }) {
                                Label(String(localized: "Timers"), systemImage: "timer")
                            }

                            Button(action: {
                                if hapticEnabled {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.prepare()
                                    impactFeedback.impactOccurred()
                                }
                                showStopwatchRecordsSheet = true
                            }) {
                                Label(String(localized: "Stopwatch"), systemImage: "stopwatch")
                            }

                            Button(action: {
                                if hapticEnabled {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.prepare()
                                    impactFeedback.impactOccurred()
                                }
                                showCountdownSheet = true
                            }) {
                                Label(String(localized: "Countdowns"), systemImage: "hourglass")
                            }
                        }

                        Divider()

                        Button(action: {
                            if hapticEnabled {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.prepare()
                                impactFeedback.impactOccurred()
                            }
                            showComplicationsSheet = true
                        }) {
                            Label(String(localized: "Complications"), systemImage: "watch.analog")
                        }

                        Button(action: {
                            if hapticEnabled {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.prepare()
                                impactFeedback.impactOccurred()
                            }
                            showWidgetIntroSheet = true
                        }) {
                            Label(String(localized: "Widgets"), systemImage: "widget.small")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    // Earth View Button
                    Button(action: {
                        if hapticEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.prepare()
                            impactFeedback.impactOccurred()
                        }
                        showEarthView = true
                    }) {
                        Image(systemName: "globe.americas.fill")
                    }
                }
            }
            
            .onReceive(timer) { now in
                handleHomeTimerTick(at: now)
                finalizeHomeStopwatchIfLimitReached(at: now)

                // Only update when the minute changes.
                // The List displays "HH:mm" (no seconds) and all visual components
                // (sky gradients, analog clock, etc.) are minute-level.
                // This reduces full-body re-renders from 60×/min to 1×/min,
                // eliminating frame drops during scrolling with many cities.
                let cal = Calendar.current
                if cal.component(.minute, from: now) != cal.component(.minute, from: currentDate) {
                    currentDate = now
                }
            }
            
            .onAppear {
                loadCollections()
                restoreHomeTimerStateIfNeeded()
                finalizeHomeStopwatchIfLimitReached(at: Date())
                checkForTimeZoneChange()
            }
            
            // Time zone changes, for the Time Zone Updated tip
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    checkForTimeZoneChange()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange).receive(on: DispatchQueue.main)) { _ in
                checkForTimeZoneChange()
            }
            
            // Listen for reset notification to reset scroll time
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetScrollTime"))) { _ in
                withAnimation(.spring()) {
                    timeOffset = 0
                    showScrollTimeButtons = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowSetAlarmSheet"))) { _ in
                showSetAlarmSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowSetTimerSheet"))) { _ in
                showSetTimerSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowCountdownSheet"))) { _ in
                showCountdownSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowStopwatchSheet"))) { _ in
                showStopwatchRecordsSheet = true
            }

            // Quick actions (Home Screen icon menu / Spotlight App Shortcuts)
            .onReceive(NotificationCenter.default.publisher(for: .quickActionSetAlarm)) { _ in
                showSetAlarmSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .quickActionSetTimer)) { _ in
                showSetTimerSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .quickActionCountdown)) { _ in
                showCountdownSheet = true
            }
            
            // Rename
            .alert("Rename", isPresented: $showingRenameAlert) {
                TextField(originalClockName, text: $newClockName)
                Button("Cancel", role: .cancel) {
                    newClockName = ""
                    originalClockName = ""
                    renamingClockId = nil
                }
                Button("Save") {
                    let nameToSave = newClockName.isEmpty ? originalClockName : newClockName
                    
                    if let clockId = renamingClockId,
                       let index = worldClocks.firstIndex(where: { $0.id == clockId }) {
                        worldClocks[index].cityName = nameToSave
                        saveWorldClocks()
                        
                        // Also update the city name in collections if it exists there
                        for collectionIndex in collections.indices {
                            if let cityIndex = collections[collectionIndex].cities.firstIndex(where: { $0.id == clockId }) {
                                collections[collectionIndex].cities[cityIndex].cityName = nameToSave
                            }
                        }
                        saveCollections()
                    }
                    newClockName = ""
                    originalClockName = ""
                    renamingClockId = nil
                }
            } message: {
                Text("Customize the name of this city")
            }

            // Rename Timer
            .alert(String(localized: "Rename Timer"), isPresented: $showingTimerRenameAlert) {
                TextField(homeTimerDisplayName, text: $newTimerName)
                Button(String(localized: "Cancel"), role: .cancel) {
                    newTimerName = ""
                }
                Button(String(localized: "Save")) {
                    saveHomeTimerName()
                }
            } message: {
                Text(String(localized: "Customize the name of this timer"))
            }
            
            // Calendar Permission Alert
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

            // Share Sheet: empty when there is no local time, no cities and no pinned countdowns
            .sheet(isPresented: $showShareSheet) {
                if worldClocks.isEmpty && !showLocalTime && !countdownStore.countdowns.contains(where: \.isPinned) {
                    ShareCitiesEmptyView()
                } else {
                    ShareCitiesSheet(
                        worldClocks: $worldClocks,
                        showSheet: $showShareSheet,
                        currentDate: currentDate,
                        timeOffset: timeOffset
                    )
                    .environmentObject(weatherManager)
                }
            }
            
            // Share as Image: full-screen preview of one city card with
            // frame, share and save actions, from the row's context menu
            .fullScreenCover(item: $cityShareData) { share in
                ShareAsImageView(title: share.cityName) { aspectRatio, frameCornerRadius in
                    cityShareCard(for: share, aspectRatio: aspectRatio, frameCornerRadius: frameCornerRadius)
                } render: { aspectRatio in
                    renderCityShareImage(for: share, aspectRatio: aspectRatio)
                }
            }
            
            // Settings Sheet
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView(
                    worldClocks: $worldClocks,
                    weatherManager: weatherManager
                )
            }
            .onChange(of: showSettingsSheet) { oldValue, newValue in
                if !newValue && oldValue { // Sheet was dismissed
                    loadCollections() // Reload collections in case they were reset
                    // If collections are empty or selected collection no longer exists, reset to default view
                    if collections.isEmpty && selectedCollectionId != nil {
                        selectedCollectionId = nil
                        saveSelectedCollection()
                    } else if let selectedId = selectedCollectionId,
                              !collections.contains(where: { $0.id == selectedId }) {
                        selectedCollectionId = nil
                        saveSelectedCollection()
                    }
                }
            }
            .fullScreenCover(isPresented: $showLifetimeStore) {
                NavigationStack {
                    LifetimeStoreView()
                }
            }
            
            // Event Editor Sheet
            .sheet(isPresented: $showEventEditor) {
                EventEditView(
                    event: $eventToEdit,
                    isPresented: $showEventEditor,
                    eventStore: eventStore
                )
                .ignoresSafeArea()
            }
            
            // Sunrise/Sunset Sheet. Hidden as soon as the layout splits: opening
            // the iPhone Duo in portrait changes only the size class, and the
            // list rebuilt beside the detail pane would present it again
            .sheet(isPresented: Binding(
                get: { showSunriseSunsetSheet && !usesSplitLayout },
                set: { showSunriseSunsetSheet = $0 }
            )) {
                SunriseSunsetSheet(
                    cityName: selectedCityName,
                    timeZoneIdentifier: selectedTimeZone,
                    initialDate: currentDate,
                    timeOffset: timeOffset
                )
                .environmentObject(weatherManager)
            }
            
            // Arrange List Sheet
            .sheet(isPresented: $showArrangeListSheet) {
                ArrangeListView(
                    worldClocks: $worldClocks,
                    showSheet: $showArrangeListSheet,
                    currentDate: currentDate,
                    timeOffset: timeOffset
                )
            }
            .onChange(of: showArrangeListSheet) { oldValue, newValue in
                if !newValue && oldValue { // Sheet was dismissed
                    loadCollections() // Reload collections in case they were modified
                }
            }

            // Set Alarm Sheet
            .sheet(isPresented: $showSetAlarmSheet) {
                SetAlarmSheet()
            }

            // Set Timer Sheet
            .sheet(isPresented: $showSetTimerSheet) {
                SetTimerSheet(
                    initialDurationSeconds: homeTimerConfiguredSeconds,
                    onConfirm: { durationSeconds in
                        startHomeTimer(durationSeconds: durationSeconds)
                    },
                    onPlayPause: handleHomeTimerTap,
                    onClearHomeTimer: clearHomeTimer
                )
            }

            // Stopwatch Records Sheet
            .sheet(isPresented: $showStopwatchRecordsSheet) {
                StopwatchRecordsSheet(stopwatch: homeStopwatch, onStart: startNewHomeStopwatch)
            }

            // Countdown Sheet
            .sheet(isPresented: $showCountdownSheet) {
                CountdownSheet()
            }

            // Countdown Editor Sheet: opened by tapping a pinned card on Home
            .sheet(item: $editingHomeCountdown) { item in
                CountdownDetailsView(countdown: item, onDelete: {
                    deleteCountdown(item)
                }) { title, targetDate, emoji, photoData, photoCrop, isPinned, repeatFrequency, reminderTime, reminderCity, reminderLeadDays, reminderKind, contact, scheduledMessage, pausedAt in
                    updateCountdown(item, title: title, targetDate: targetDate, emoji: emoji, photoData: photoData, photoCrop: photoCrop, isPinned: isPinned, repeatFrequency: repeatFrequency, reminderTime: reminderTime, reminderCity: reminderCity, reminderLeadDays: reminderLeadDays, reminderKind: reminderKind, contact: contact, scheduledMessage: scheduledMessage, pausedAt: pausedAt)
                }
                // Force a fresh view identity per item, otherwise SwiftUI reuses
                // the sheet content and @State keeps the previous item's values.
                .id(item.id)
            }

            // Share as Image for a pinned card: same full-screen preview as
            // the countdown editor, with the day count at the scrubbed time
            .fullScreenCover(item: $countdownShareData) { share in
                CountdownShareAsImageView(
                    title: share.item.title,
                    targetDate: share.item.effectiveTargetDate(at: share.now),
                    emoji: share.item.emoji,
                    photoData: share.item.photoData,
                    photoCrop: share.item.photoCrop,
                    isRepeating: share.item.repeatFrequency != .never,
                    now: share.now,
                    pausedAt: share.item.pausedAt
                )
            }

            // Complications Sheet
            .sheet(isPresented: $showComplicationsSheet) {
                NavigationStack {
                    ComplicationsSettingsView(
                        showAnalogClock: $showAnalogClock,
                        showSunPosition: $showSunPosition,
                        showSunAzimuth: $showSunAzimuth,
                        showMoonAzimuth: $showMoonAzimuth,
                        showMoonSunAzimuth: $showMoonSunAzimuth,
                        showSunriseSunset: $showSunriseSunset,
                        showWeatherCondition: $showWeatherCondition,
                        showTemperatureIndicator: $showTemperatureIndicator,
                        showTemperatureRange: $showTemperatureRange,
                        showUVIndex: $showUVIndex,
                        showWindDirection: $showWindDirection,
                        showDaylight: $showDaylight,
                        showTimeOverlay: $showTimeOverlay,
                        showSolarCurve: $showSolarCurve,
                        showWeather: showWeather,
                        weatherManager: weatherManager
                    )
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
            }

            // Widgets Sheet
            .sheet(isPresented: $showWidgetIntroSheet) {
                WidgetIntroSheet()
            }
            
            // Earth View
            .fullScreenCover(isPresented: $showEarthView) {
                EarthView(
                    timeOffset: $timeOffset,
                    worldClocks: $worldClocks,
                    weatherManager: weatherManager
                )
                    .interactiveDismissDisabled(true)
            }
            
            // City Time Adjustment Sheet
            .sheet(item: $cityTimeAdjustmentData) { data in
                CityTimeAdjustmentSheet(
                    cityName: data.cityName,
                    timeZoneIdentifier: data.timeZoneIdentifier,
                    timeOffset: $timeOffset,
                    showSheet: Binding(
                        get: { cityTimeAdjustmentData != nil },
                        set: { if !$0 { cityTimeAdjustmentData = nil } }
                    ),
                    showScrollTimeButtons: $showScrollTimeButtons
                )
            }
        }
        
    }
    
    // Save world clocks to UserDefaults
    func saveWorldClocks() {
        if let encoded = try? JSONEncoder().encode(worldClocks) {
            UserDefaults.standard.set(encoded, forKey: worldClocksKey)
        }
    }

    // Restore the most recently deleted city (if any)
    func restoreLastDeletedCity() {
        guard let snapshot = recentlyDeletedCity else { return }

        // If this city already exists again, clear stale snapshot and exit.
        guard !worldClocks.contains(where: { $0.id == snapshot.clock.id }) else {
            recentlyDeletedCity = nil
            return
        }

        let worldInsertIndex = min(snapshot.worldClockIndex, worldClocks.count)
        worldClocks.insert(snapshot.clock, at: worldInsertIndex)
        saveWorldClocks()

        for position in snapshot.collectionPositions {
            guard let collectionIndex = collections.firstIndex(where: { $0.id == position.collectionId }) else {
                continue
            }
            guard !collections[collectionIndex].cities.contains(where: { $0.id == snapshot.clock.id }) else {
                continue
            }

            let cityInsertIndex = min(position.cityIndex, collections[collectionIndex].cities.count)
            collections[collectionIndex].cities.insert(snapshot.clock, at: cityInsertIndex)
        }
        saveCollections()

        recentlyDeletedCity = nil

        if hapticEnabled {
            let feedback = UINotificationFeedbackGenerator()
            feedback.prepare()
            feedback.notificationOccurred(.success)
        }
    }
    
    // Delete city from both worldClocks and all collections
    func deleteCity(withId cityId: UUID) {
        guard let worldClockIndex = worldClocks.firstIndex(where: { $0.id == cityId }) else {
            return
        }

        let deletedClock = worldClocks.remove(at: worldClockIndex)
        var removedCollectionPositions: [DeletedCitySnapshot.CollectionPosition] = []

        for collectionIndex in collections.indices {
            if let cityIndex = collections[collectionIndex].cities.firstIndex(where: { $0.id == cityId }) {
                collections[collectionIndex].cities.remove(at: cityIndex)
                removedCollectionPositions.append(
                    .init(
                        collectionId: collections[collectionIndex].id,
                        cityIndex: cityIndex
                    )
                )
            }
        }

        recentlyDeletedCity = DeletedCitySnapshot(
            clock: deletedClock,
            worldClockIndex: worldClockIndex,
            collectionPositions: removedCollectionPositions
        )

        if !hasTriggeredShakeToResetTip {
            hasTriggeredShakeToResetTip = true
            showShakeToResetTip = true
        }

        saveWorldClocks()
        saveCollections()
    }

    // Show the Time Zone Updated tip when the device's time zone differs from
    // the last one seen, e.g. after landing in another country
    private func checkForTimeZoneChange() {
        let currentIdentifier = TimeZone.current.identifier
        guard currentIdentifier != lastKnownTimeZoneIdentifier else { return }

        // Nothing is recorded before the first check, so there's no change to report
        let isFirstCheck = lastKnownTimeZoneIdentifier.isEmpty
        lastKnownTimeZoneIdentifier = currentIdentifier

        guard !isFirstCheck, showLocalTime else { return }
        withAnimation(.spring()) {
            showTimeZoneUpdatedTip = true
        }
    }
}

private struct ShakeDetectorView: UIViewControllerRepresentable {
    let onShake: () -> Void

    func makeUIViewController(context: Context) -> ShakeDetectorViewController {
        let viewController = ShakeDetectorViewController()
        viewController.onShake = onShake
        return viewController
    }

    func updateUIViewController(_ uiViewController: ShakeDetectorViewController, context: Context) {
        uiViewController.onShake = onShake
    }
}

private final class ShakeDetectorViewController: UIViewController {
    var onShake: (() -> Void)?

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        resignFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else {
            super.motionEnded(motion, with: event)
            return
        }
        onShake?()
    }
}

// MARK: - Shared row time formatting
// Pure helpers used by the extracted row views so that each row can compute its
// own time/date strings from the bindings it observes (enabling localized
// invalidation without depending on HomeView instance methods).
fileprivate enum RowTimeFormat {
    private static let timeFormatterCache: NSCache<NSString, DateFormatter> = {
        let cache = NSCache<NSString, DateFormatter>()
        cache.countLimit = 50
        return cache
    }()

    static func timeFormatter(for timeZone: TimeZone, use24Hour: Bool) -> DateFormatter {
        let key = "\(timeZone.identifier)_\(use24Hour)" as NSString
        if let cached = timeFormatterCache.object(forKey: key) {
            return cached
        }
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = use24Hour ? "HH:mm" : "h:mm"
        timeFormatterCache.setObject(formatter, forKey: key)
        return formatter
    }

    static func time(date: Date, offset: TimeInterval, timeZone: TimeZone, use24Hour: Bool) -> String {
        timeFormatter(for: timeZone, use24Hour: use24Hour).string(from: date.addingTimeInterval(offset))
    }

    static func minuteQuantized(date: Date, offset: TimeInterval) -> Date {
        let interval = date.addingTimeInterval(offset).timeIntervalSinceReferenceDate
        return Date(timeIntervalSinceReferenceDate: (interval / 60).rounded(.down) * 60)
    }

    static func minuteQuantized(offset: TimeInterval) -> TimeInterval {
        (offset / 60).rounded(.down) * 60
    }

    static func cityDate(timeZoneIdentifier: String, displayDate: Date, referenceDate: Date, dateStyle: String) -> String {
        guard let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return ""
        }
        return displayDate.formattedDate(
            style: dateStyle,
            timeZone: targetTimeZone,
            relativeTo: referenceDate
        )
    }

    struct WeekdayDisplay {
        let previous: String
        let current: String
        let next: String
    }

    static func weekdayDisplay(for timeZoneIdentifier: String, baseDate: Date, offset: TimeInterval) -> WeekdayDisplay? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return nil
        }
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let displayDate = baseDate.addingTimeInterval(offset)
        let previousDate = calendar.date(byAdding: .day, value: -1, to: displayDate) ?? displayDate.addingTimeInterval(-86_400)
        let nextDate = calendar.date(byAdding: .day, value: 1, to: displayDate) ?? displayDate.addingTimeInterval(86_400)
        let previous = weekdaySymbol(for: calendar.component(.weekday, from: previousDate))
        let current = weekdaySymbol(for: calendar.component(.weekday, from: displayDate))
        let next = weekdaySymbol(for: calendar.component(.weekday, from: nextDate))
        return WeekdayDisplay(previous: previous, current: current, next: next)
    }

    static func weekdaySymbol(for weekday: Int) -> String {
        switch weekday {
        case 1: return String(localized: "Sun")
        case 2: return String(localized: "Mon")
        case 3: return String(localized: "Tue")
        case 4: return String(localized: "Wed")
        case 5: return String(localized: "Thu")
        case 6: return String(localized: "Fri")
        case 7: return String(localized: "Sat")
        default: return ""
        }
    }

    static func weekdayInlineText(for weekday: WeekdayDisplay) -> String {
        "\(weekday.previous) [\(weekday.current)] \(weekday.next)"
    }

    static func additionalText(for clock: WorldClock, display: String, baseDate: Date, offset: TimeInterval) -> String {
        switch display {
        case "Time Difference":
            return clock.timeDifference
        case "UTC":
            return clock.utcOffset
        case "Weekday":
            guard let weekday = weekdayDisplay(for: clock.timeZoneIdentifier, baseDate: baseDate, offset: offset) else {
                return ""
            }
            return weekdayInlineText(for: weekday)
        default:
            return ""
        }
    }
}

// MARK: - Extracted row views (localized invalidation)
// Each of these reads `currentDate`/`timeOffset` through bindings so that, while
// scrubbing time, only the visible rows recompute instead of the whole HomeView
// body. HomeView no longer reads the per-frame time values directly.

/// Sky background for a single list row, computed from the time bindings.
/// `HomeSkyListRowBackground` only receives plain values, so its subtree is
/// pruned on frames where the quantized date and weather did not change.
fileprivate struct RowSkyBackground: View {
    let timeZoneIdentifier: String
    @Binding var currentDate: Date
    @Binding var timeOffset: TimeInterval
    @ObservedObject var weatherManager: WeatherManager
    @AppStorage("showWeather") private var showWeather = false

    var body: some View {
        HomeSkyListRowBackground(
            date: RowTimeFormat.minuteQuantized(date: currentDate, offset: timeOffset),
            timeZoneIdentifier: timeZoneIdentifier,
            weatherCondition: showWeather ? weatherManager.weatherData[timeZoneIdentifier]?.condition : nil,
            timeOffset: RowTimeFormat.minuteQuantized(offset: timeOffset)
        )
    }
}

/// The local time zone's sky color across the top of the screen, fading out
/// downward.
fileprivate struct LocalSkyGlowBackground: View {
    @Binding var currentDate: Date
    @Binding var timeOffset: TimeInterval
    @ObservedObject var weatherManager: WeatherManager
    @AppStorage("showWeather") private var showWeather = false

    // Smoothstep opacity ramp: a linear one shows hard bands where the fade
    // starts and ends
    private static let fadeStops: [Gradient.Stop] = (0...8).map { step in
        let location = Double(step) / 8
        return .init(color: .black.opacity(location * location * (3 - 2 * location)), location: location)
    }

    var body: some View {
        let sky = SkyColorGradient(
            date: RowTimeFormat.minuteQuantized(date: currentDate, offset: timeOffset),
            timeZoneIdentifier: TimeZone.current.identifier,
            weatherCondition: showWeather ? weatherManager.weatherData[TimeZone.current.identifier]?.condition : nil
        )

        Rectangle()
            .fill(sky.linearGradient())
            .animation(.easeInOut(duration: 0.5), value: sky.animationValue)
            .frame(height: 400)
            .mask {
                LinearGradient(stops: Self.fadeStops, startPoint: .bottom, endPoint: .top)
            }
            .opacity(0.25)
    }
}

/// Local time zone row content.
///
/// Thin wrapper: it is the only layer that reads the per-frame time bindings.
/// It quantizes them to the minute and hands plain values to
/// `LocalTimeRowBody`, so SwiftUI can prune the whole row subtree (via
/// `.equatable()`) on frames where the displayed minute did not change.
fileprivate struct LocalTimeRowContent: View {
    @Binding var currentDate: Date
    @Binding var timeOffset: TimeInterval
    let complicationOptions: ComplicationDisplayOptions
    @ObservedObject var weatherManager: WeatherManager

    var body: some View {
        LocalTimeRowBody(
            displayDate: RowTimeFormat.minuteQuantized(date: currentDate, offset: timeOffset),
            referenceDate: RowTimeFormat.minuteQuantized(date: currentDate, offset: 0),
            complicationOptions: complicationOptions,
            weatherManager: weatherManager
        )
        .equatable()
    }
}

fileprivate struct LocalTimeRowBody: View, Equatable {
    let displayDate: Date
    let referenceDate: Date
    let complicationOptions: ComplicationDisplayOptions
    @ObservedObject var weatherManager: WeatherManager

    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showWeather") private var showWeather = false
    @AppStorage("useCelsius") private var useCelsius = true
    @AppStorage("dateStyle") private var dateStyle = "Relative"
    @AppStorage("hasLifetimeAccess") private var hasLifetimeAccess = false
    @AppStorage("availableTimeEnabled") private var availableTimeEnabled = false
    @AppStorage("availableStartTime") private var availableStartTime = "09:00"
    @AppStorage("availableEndTime") private var availableEndTime = "17:00"
    @AppStorage("availableWeekdays") private var availableWeekdays = "2,3,4,5,6"

    // Dynamic properties (@AppStorage / @ObservedObject) invalidate the view
    // through their own dependency channel, so == only needs to cover the
    // plain inputs coming from the wrapper.
    static func == (lhs: LocalTimeRowBody, rhs: LocalTimeRowBody) -> Bool {
        lhs.displayDate == rhs.displayDate
            && lhs.referenceDate == rhs.referenceDate
            && lhs.complicationOptions == rhs.complicationOptions
    }

    private var hasVisibleComplication: Bool { complicationOptions.hasVisibleComplication }
    private var showsAvailableTime: Bool {
        hasLifetimeAccess && availableTimeEnabled && !availableWeekdays.isEmpty
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 4) {
                // Top row: "Local" label and Date
                HStack {
                    Image(systemName: "location.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)

                    Spacer()

                    // Weather display for local time
                    if showWeather {
                        WeatherView(
                            weather: weatherManager.weatherData[TimeZone.current.identifier],
                            useCelsius: useCelsius
                        )
                        .contentTransition(.numericText())
                    }

                    Text(displayDate.formattedDate(
                        style: dateStyle,
                        timeZone: TimeZone.current,
                        relativeTo: referenceDate
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .contentTransition(.numericText())
                    .clipped()
                }

                // Bottom row: Location and Time (baseline aligned)
                HStack(alignment: .lastTextBaseline) {
                    Text(String(localized: "Local"))
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: hasVisibleComplication ? 120 : .infinity, alignment: .leading)
                        .contentTransition(.numericText())

                    Spacer()

                    PulsingTimeText(timeText: RowTimeFormat.time(date: displayDate, offset: 0, timeZone: .current, use24Hour: use24HourFormat))
                        .font(.system(size: 36))
                        .fontWeight(.light)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .clipped()
                }
                .padding(.bottom, -4)

                // Available Time Display with Progress Indicator
                if showsAvailableTime {
                    AvailableTimeIndicator(
                        currentDate: displayDate,
                        timeOffset: 0,
                        availableStartTime: availableStartTime,
                        availableEndTime: availableEndTime,
                        use24HourFormat: use24HourFormat,
                        availableWeekdays: availableWeekdays
                    )
                }
            }
            .frame(minHeight: 64) // For Complication Overlays

            // Complication Overlays
            ComplicationOverlayView(
                date: displayDate,
                timeZone: TimeZone.current,
                options: complicationOptions,
                bottomPadding: showsAvailableTime ? 18 : 0
            )
            .environmentObject(weatherManager)
        }
        .animation(nil, value: complicationOptions)
        .contentShape(Rectangle())
    }
}

/// World clock (city) row content.
///
/// Thin wrapper: reads the per-frame time bindings, quantizes to the minute,
/// and hands plain values to `CityRowBody` so unchanged rows are pruned.
fileprivate struct CityRowContent: View {
    let clock: WorldClock
    @Binding var currentDate: Date
    @Binding var timeOffset: TimeInterval
    let complicationOptions: ComplicationDisplayOptions
    @ObservedObject var weatherManager: WeatherManager

    var body: some View {
        CityRowBody(
            clock: clock,
            displayDate: RowTimeFormat.minuteQuantized(date: currentDate, offset: timeOffset),
            referenceDate: RowTimeFormat.minuteQuantized(date: currentDate, offset: 0),
            complicationOptions: complicationOptions,
            weatherManager: weatherManager
        )
        .equatable()
    }
}

fileprivate struct CityRowBody: View, Equatable {
    let clock: WorldClock
    let displayDate: Date
    let referenceDate: Date
    let complicationOptions: ComplicationDisplayOptions
    @ObservedObject var weatherManager: WeatherManager

    @AppStorage("dateStyle") private var dateStyle = "Relative"
    @AppStorage("additionalTimeDisplay") private var additionalTimeDisplay = "None"
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showWeather") private var showWeather = false
    @AppStorage("useCelsius") private var useCelsius = true

    // Dynamic properties (@AppStorage / @ObservedObject) invalidate the view
    // through their own dependency channel, so == only needs to cover the
    // plain inputs coming from the wrapper.
    static func == (lhs: CityRowBody, rhs: CityRowBody) -> Bool {
        lhs.clock == rhs.clock
            && lhs.displayDate == rhs.displayDate
            && lhs.referenceDate == rhs.referenceDate
            && lhs.complicationOptions == rhs.complicationOptions
    }

    private var hasVisibleComplication: Bool { complicationOptions.hasVisibleComplication }

    private var cityDateText: String {
        RowTimeFormat.cityDate(
            timeZoneIdentifier: clock.timeZoneIdentifier,
            displayDate: displayDate,
            referenceDate: referenceDate,
            dateStyle: dateStyle
        )
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 4) {
                // Top row: Additional time display and Date
                if additionalTimeDisplay != "None" {
                    HStack {
                        additionalTimeView

                        Spacer()

                        // Weather display for world clock
                        if showWeather {
                            WeatherView(
                                weather: weatherManager.weatherData[clock.timeZoneIdentifier],
                                useCelsius: useCelsius
                            )
                            .contentTransition(.numericText())
                        }

                        Text(cityDateText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .blendMode(.plusLighter)
                            .contentTransition(.numericText())
                            .clipped()
                    }
                } else {
                    HStack {
                        Spacer()

                        // Weather display for world clock (when time difference is hidden)
                        if showWeather {
                            WeatherView(
                                weather: weatherManager.weatherData[clock.timeZoneIdentifier],
                                useCelsius: useCelsius
                            )
                            .contentTransition(.numericText())
                        }

                        Text(cityDateText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                            .clipped()
                    }
                }

                // Bottom row: City name and Time (baseline aligned)
                HStack(alignment: .lastTextBaseline) {
                    Text(clock.localizedCityName)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: hasVisibleComplication ? 120 : .infinity, alignment: .leading)
                        .contentTransition(.numericText())

                    Spacer()

                    PulsingTimeText(timeText: RowTimeFormat.time(
                        date: displayDate,
                        offset: 0,
                        timeZone: TimeZone(identifier: clock.timeZoneIdentifier) ?? .current,
                        use24Hour: use24HourFormat
                    ))
                    .font(.system(size: 36))
                    .fontWeight(.light)
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .clipped()
                }
                .padding(.bottom, -4)
            }
            .frame(minHeight: 64) // For Complication Overlays

            // Complication Overlays
            ComplicationOverlayView(
                date: displayDate,
                timeZone: TimeZone(identifier: clock.timeZoneIdentifier) ?? TimeZone.current,
                options: complicationOptions,
                bottomPadding: 0
            )
            .environmentObject(weatherManager)
        }
        .animation(nil, value: complicationOptions)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var additionalTimeView: some View {
        if additionalTimeDisplay == "Weekday" {
            if let weekday = RowTimeFormat.weekdayDisplay(
                for: clock.timeZoneIdentifier,
                baseDate: displayDate,
                offset: 0
            ) {
                HStack(spacing: 5) {
                    Text(weekday.previous)
                        .font(.caption.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .blendMode(.plusLighter)
                        .contentTransition(.numericText())

                    Text(weekday.current)
                        .font(.caption.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(Color.white)
                        .frame(width: 20, height: 16)
                        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .contentTransition(.numericText())

                    Text(weekday.next)
                        .font(.caption.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .blendMode(.plusLighter)
                        .contentTransition(.numericText())
                }
            }
        } else {
            let text = RowTimeFormat.additionalText(
                for: clock,
                display: additionalTimeDisplay,
                baseDate: displayDate,
                offset: 0
            )
            if !text.isEmpty || additionalTimeDisplay == "UTC" {
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
            }
        }
    }
}
