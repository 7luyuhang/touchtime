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
import AlarmKit
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

    var body: some View {
        SkyBackgroundView(
            date: date,
            timeZoneIdentifier: timeZoneIdentifier,
            weatherCondition: weatherCondition,
            showRainEffect: true,
            appliesCardChrome: false
        )
        .skyBackgroundCardChrome()
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

    private struct WeekdayDisplay {
        let previous: String
        let current: String
        let next: String
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
    @State private var showArrangeListSheet = false
    @State private var showSetAlarmSheet = false
    @State private var showSetTimerSheet = false
    @State private var showCountdownSheet = false
    // Pinned countdowns show their preview below the home timer; the shared
    // store is observed, so pins toggled inside the countdown sheet update
    // the cards immediately.
    @Environment(CountdownStore.self) private var countdownStore
    // Countdown being edited after tapping its pinned card on Home.
    @State private var editingHomeCountdown: CountdownItem? = nil
    @State private var showComplicationsSheet = false
    @State private var showWidgetIntroSheet = false
    @State private var showEarthView = false
    @State private var cityTimeAdjustmentData: CityTimeAdjustmentData? = nil
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
    @AppStorage("showDoubleTapMoreActionTip") private var showDoubleTapMoreActionTip = true
    @AppStorage("showShakeToResetTip") private var showShakeToResetTip = false
    @AppStorage("hasTriggeredShakeToResetTip") private var hasTriggeredShakeToResetTip = false
    @AppStorage("homeTimerConfiguredSeconds") private var homeTimerConfiguredSeconds = 0
    @AppStorage("homeTimerEndDateEpoch") private var homeTimerEndDateEpoch: Double = 0
    @AppStorage("homeTimerCompletionHandled") private var homeTimerCompletionHandled = false
    @AppStorage("homeTimerPaused") private var homeTimerPaused = false
    @AppStorage("homeTimerPausedRemainingSeconds") private var homeTimerPausedRemainingSeconds = 0
    @AppStorage("homeTimerAlarmID") private var homeTimerAlarmIDRawValue = ""
    @AppStorage("homeTimerName") private var homeTimerName = ""
    
    // Namespace for zoom transition
    @Namespace private var earthViewNamespace
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // UserDefaults key for storing world clocks
    private let worldClocksKey = "savedWorldClocks"
    private let collectionsKey = "savedCityCollections"
    private let alarmManager = AlarmManager.shared

    @State private var homeTimerAlarmSyncVersion = 0
    
    private var hasConfiguredHomeTimer: Bool {
        homeTimerConfiguredSeconds > 0
    }

    /// True when at least one countdown is pinned to Home, so the list
    /// still has countdown cards to show without clocks or a timer.
    private var hasPinnedCountdowns: Bool {
        countdownStore.countdowns.contains(where: \.isPinned)
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
        homeTimerCompletionHandled = remaining == 0
    }

    private func refreshHomeTimerAlarm(
        requestAuthorization: Bool
    ) {
        homeTimerAlarmSyncVersion += 1
        let syncVersion = homeTimerAlarmSyncVersion
        let shouldSchedule = hasConfiguredHomeTimer && !homeTimerPaused
        let remainingSeconds = homeTimerRemainingSeconds(at: Date())
        let existingAlarmID = homeTimerAlarmID

        Task { @MainActor in
            await synchronizeHomeTimerAlarm(
                syncVersion: syncVersion,
                existingAlarmID: existingAlarmID,
                shouldSchedule: shouldSchedule,
                remainingSeconds: remainingSeconds,
                requestAuthorization: requestAuthorization
            )
        }
    }

    @MainActor
    private func synchronizeHomeTimerAlarm(
        syncVersion: Int,
        existingAlarmID: UUID?,
        shouldSchedule: Bool,
        remainingSeconds: Int,
        requestAuthorization: Bool
    ) async {
        let isStale = { syncVersion != homeTimerAlarmSyncVersion || Task.isCancelled }

        if let existingAlarmID {
            try? alarmManager.cancel(id: existingAlarmID)
        }

        guard !isStale() else { return }

        guard shouldSchedule, remainingSeconds > 0 else {
            homeTimerAlarmIDRawValue = ""
            return
        }

        if requestAuthorization {
            switch await AlarmSupport.ensureAuthorization(using: alarmManager) {
            case .authorized:
                break
            case .denied:
                homeTimerAlarmIDRawValue = ""
                return
            case .failed(let error):
                homeTimerAlarmIDRawValue = ""
                print("Failed to authorize AlarmKit for timer: \(error.localizedDescription)")
                return
            }
        } else if alarmManager.authorizationState != .authorized {
            homeTimerAlarmIDRawValue = ""
            return
        }

        let newAlarmID = UUID()

        do {
            try await AlarmSupport.scheduleTimerAlarm(
                id: newAlarmID,
                durationSeconds: remainingSeconds,
                eventTitle: homeTimerDisplayName,
                using: alarmManager
            )
        } catch {
            homeTimerAlarmIDRawValue = ""
            print("Failed to schedule AlarmKit timer reminder: \(error.localizedDescription)")
            return
        }

        guard !isStale() else {
            try? alarmManager.cancel(id: newAlarmID)
            return
        }

        homeTimerAlarmIDRawValue = newAlarmID.uuidString
    }

    private func handleHomeTimerTick(at now: Date) {
        guard hasConfiguredHomeTimer, !homeTimerPaused else { return }

        let remaining = homeTimerRemainingSeconds(at: now)
        if remaining == 0 {
            guard !homeTimerCompletionHandled else { return }
            homeTimerCompletionHandled = true

            if hapticEnabled {
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.prepare()
                notificationFeedback.notificationOccurred(.success)
            }
        } else if homeTimerCompletionHandled {
            homeTimerCompletionHandled = false
        }
    }

    /// Commits edits made in the countdown editor opened from a pinned
    /// Home card, mirroring CountdownSheet's update logic.
    private func updateCountdown(_ item: CountdownItem, title: String, targetDate: Date, emoji: String?, photoData: Data?, isPinned: Bool, repeatFrequency: CountdownItem.RepeatFrequency, reminderTime: Date?, reminderLeadDays: Int) {
        guard let index = countdownStore.countdowns.firstIndex(where: { $0.id == item.id }) else { return }
        // Assemble the edited item first so the store (and UserDefaults)
        // sees a single mutation instead of one per field.
        var updated = countdownStore.countdowns[index]
        updated.title = title
        updated.targetDate = targetDate
        updated.emoji = emoji
        updated.photoData = photoData
        updated.isPinned = isPinned
        updated.repeatFrequency = repeatFrequency
        updated.reminderTime = reminderTime
        updated.reminderLeadDays = reminderLeadDays
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

    private func weatherConditionForSky(at timeZoneIdentifier: String) -> WeatherCondition? {
        guard showWeather else { return nil }
        return weatherManager.weatherData[timeZoneIdentifier]?.condition
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

    private func additionalText(for clock: WorldClock) -> String {
        switch additionalTimeDisplay {
        case "Time Difference":
            return clock.timeDifference
        case "UTC":
            return clock.utcOffset
        case "Weekday":
            guard let weekday = weekdayDisplay(
                for: clock.timeZoneIdentifier,
                baseDate: currentDate,
                offset: timeOffset
            ) else {
                return ""
            }
            return weekdayInlineText(for: weekday)
        default:
            return ""
        }
    }

    private func weekdayDisplay(
        for timeZoneIdentifier: String,
        baseDate: Date,
        offset: TimeInterval
    ) -> WeekdayDisplay? {
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

    private func weekdaySymbol(for weekday: Int) -> String {
        switch weekday {
        case 1:
            return String(localized: "Sun")
        case 2:
            return String(localized: "Mon")
        case 3:
            return String(localized: "Tue")
        case 4:
            return String(localized: "Wed")
        case 5:
            return String(localized: "Thu")
        case 6:
            return String(localized: "Fri")
        case 7:
            return String(localized: "Sat")
        default:
            return ""
        }
    }

    private func weekdayInlineText(for weekday: WeekdayDisplay) -> String {
        "\(weekday.previous) [\(weekday.current)] \(weekday.next)"
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
        
        let localLazy = LazyCardImage { [self] in
            renderCardImage(
                cityName: String(localized: "Local"),
                timeZoneIdentifier: TimeZone.current.identifier,
                weatherCondition: weatherConditionForSky(at: TimeZone.current.identifier)
            ).uiImage
        }
        Menu {
            Button(action: {
                let cityName = String(localized: "Local")
                copyTimeAsText(cityName: cityName, timeZoneIdentifier: TimeZone.current.identifier)
            }) {
                Label(String(localized: "Copy as Text"), systemImage: "quote.opening")
            }
            ShareLink(item: localLazy, preview: SharePreview(String(localized: "Local"))) {
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
        
        let cityLazy = LazyCardImage { [self] in
            renderCardImage(
                cityName: getLocalizedCityName(for: clock),
                timeZoneIdentifier: clock.timeZoneIdentifier,
                weatherCondition: weatherConditionForSky(at: clock.timeZoneIdentifier)
            ).uiImage
        }
        Menu {
            Button(action: {
                copyTimeAsText(cityName: getLocalizedCityName(for: clock), timeZoneIdentifier: clock.timeZoneIdentifier)
            }) {
                Label(String(localized: "Copy as Text"), systemImage: "quote.opening")
            }
            ShareLink(item: cityLazy, preview: SharePreview(getLocalizedCityName(for: clock))) {
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
    
    // Render city card as image for sharing
    func renderCardImage(cityName: String, timeZoneIdentifier: String, weatherCondition: WeatherCondition? = nil) -> CardImage {
        let adjustedDate = currentDate.addingTimeInterval(timeOffset)
        let effectiveWeatherCondition = showWeather ? weatherCondition : nil
        let weatherForSnapshot = showWeather ? weatherManager.weatherData[timeZoneIdentifier] : nil
        
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if use24HourFormat {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "h:mm"
        }
        let timeString = formatter.string(from: adjustedDate)
        formatter.timeZone = TimeZone.current
        let localTimeString = formatter.string(from: adjustedDate)
        
        let dateString = getCityDate(
            timeZoneIdentifier: timeZoneIdentifier,
            baseDate: currentDate,
            offset: timeOffset
        )
        
        let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
        
        let clock = WorldClock(cityName: cityName, timeZoneIdentifier: timeZoneIdentifier)
        let additionalText = additionalText(for: clock)
        
        let snapshotView = CityCardSnapshotView(
            cityName: cityName,
            timeString: timeString,
            localCityName: localCityName,
            localTimeString: localTimeString,
            dateString: dateString,
            date: adjustedDate,
            timeZone: targetTimeZone,
            timeZoneIdentifier: timeZoneIdentifier,
            weather: weatherForSnapshot,
            weatherCondition: effectiveWeatherCondition,
            useCelsius: useCelsius,
            complications: complicationOptions,
            additionalTimeDisplay: additionalTimeDisplay,
            showSkyDot: showSkyDot,
            additionalTimeText: additionalText
        )
        .environmentObject(weatherManager)
        .environment(\.colorScheme, .dark)
        
        let renderer = ImageRenderer(content: snapshotView)
        renderer.scale = 3
        
        if let uiImage = renderer.uiImage {
            return CardImage(uiImage: uiImage)
        }
        
        // Fallback: create a simple placeholder image
        let placeholderImage = UIImage(systemName: "photo") ?? UIImage()
        return CardImage(uiImage: placeholderImage)
    }
    
    var body: some View {
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
                if displayedClocks.isEmpty && !showLocalTime && !hasConfiguredHomeTimer && !hasPinnedCountdowns {
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
                        
                        // Countdown Preview Section: pinned countdowns live below the timer
                        HomeCountdownSection(
                            countdowns: countdownStore.countdowns,
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
                                .id("local-\(showSkyDot)")
                                
                                // Tap gesture for local time
                                .onTapGesture {
                                    selectedTimeZone = TimeZone.current.identifier
                                    selectedCityName = String(localized: "Local")
                                    showSunriseSunsetSheet = true
                                    
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
                                    showSunriseSunsetSheet = true
                                    
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

                        if showDoubleTapMoreActionTip {
                            Section {
                                VStack(spacing: 16) {
                                    // Button Group
                                    HStack(spacing: 8) {
                                        Image(systemName: "alarm")
                                            .font(.headline)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 40)
                                            .glassEffect(.regular, in: Capsule(style: .continuous))
                                        Image(systemName: "timer")
                                            .font(.headline)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 40)
                                            .glassEffect(.regular, in: Capsule(style: .continuous))
                                        Image(systemName: "xmark")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 40)
                                            .glassEffect(.regular, in: Capsule(style: .continuous))
                                    }
                                    .padding(.horizontal, 8)
                                    
                                    VStack(spacing: 10) {
                                        Text(String(localized: "Double-tap for quick actions"))
                                            .font(.subheadline.weight(.medium))
                                            .shimmering(
                                                animation: .easeInOut(duration: 2.0).repeatForever(autoreverses: false)
                                            )
                                        Image(systemName: "chevron.down")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                                )
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .listSectionSpacing(12) // List Paddings
                    .scrollIndicators(.hidden)
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .safeAreaPadding(.bottom, 52)
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
                        onExpandControlsByDoubleTap: {
                            withAnimation(.spring()) {
                                showDoubleTapMoreActionTip = false
                            }
                        }
                    )
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .transition(.blurReplace())
                }
            }
            .background(
                ZStack {
                    // Base system background
                    Color(UIColor.systemGroupedBackground)
                        .ignoresSafeArea()
                    
                    // Sky Background Effect for System Time
                    if showLocalTime && showSkyDot {
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
            .animation(.snappy(), value: selectedCollectionId) // Collection Animation
            
            .ignoresSafeArea(.keyboard, edges: .bottom)
            
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
                                Label(String(localized: "Timer"), systemImage: "timer")
                            }

                            Button(action: {
                                if hapticEnabled {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.prepare()
                                    impactFeedback.impactOccurred()
                                }
                                showCountdownSheet = true
                            }) {
                                Label(String(localized: "Countdown"), systemImage: "hourglass")
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
                    .matchedTransitionSource(id: "earthView", in: earthViewNamespace)
                }
            }
            
            .onReceive(timer) { now in
                handleHomeTimerTick(at: now)

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

            // Home Screen quick action (long-press the app icon)
            .onReceive(NotificationCenter.default.publisher(for: .quickActionSetTimer)) { _ in
                showSetTimerSheet = true
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

            // Share Cities Sheet: empty when there is no local time and no cities
            .sheet(isPresented: $showShareSheet) {
                if worldClocks.isEmpty && !showLocalTime {
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
            .sheet(isPresented: $showLifetimeStore) {
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
            
            // Sunrise/Sunset Sheet
            .sheet(isPresented: $showSunriseSunsetSheet) {
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
                    onPlayPause: handleHomeTimerTap
                )
            }

            // Countdown Sheet
            .sheet(isPresented: $showCountdownSheet) {
                CountdownSheet()
            }

            // Countdown Editor Sheet: opened by tapping a pinned card on Home
            .sheet(item: $editingHomeCountdown) { item in
                CountdownDetailsView(countdown: item, onDelete: {
                    deleteCountdown(item)
                }) { title, targetDate, emoji, photoData, isPinned, repeatFrequency, reminderTime, reminderLeadDays in
                    updateCountdown(item, title: title, targetDate: targetDate, emoji: emoji, photoData: photoData, isPinned: isPinned, repeatFrequency: repeatFrequency, reminderTime: reminderTime, reminderLeadDays: reminderLeadDays)
                }
                // Force a fresh view identity per item, otherwise SwiftUI reuses
                // the sheet content and @State keeps the previous item's values.
                .id(item.id)
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
            .sheet(isPresented: $showEarthView) {
                EarthView(
                    timeOffset: $timeOffset,
                    worldClocks: $worldClocks,
                    weatherManager: weatherManager
                )
                    .navigationTransition(.zoom(sourceID: "earthView", in: earthViewNamespace))
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
            weatherCondition: showWeather ? weatherManager.weatherData[timeZoneIdentifier]?.condition : nil
        )
    }
}

/// Blurred sky glow used as the screen background for the local time zone.
fileprivate struct LocalSkyGlowBackground: View {
    @Binding var currentDate: Date
    @Binding var timeOffset: TimeInterval
    @ObservedObject var weatherManager: WeatherManager
    @AppStorage("showWeather") private var showWeather = false

    var body: some View {
        SkyBackgroundView(
            date: RowTimeFormat.minuteQuantized(date: currentDate, offset: timeOffset),
            timeZoneIdentifier: TimeZone.current.identifier,
            weatherCondition: showWeather ? weatherManager.weatherData[TimeZone.current.identifier]?.condition : nil,
            appliesCardChrome: false
        )
        .frame(width: 500, height: 500)
        .blur(radius: 50)
        .offset(y: -250)
        .opacity(0.35)
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
