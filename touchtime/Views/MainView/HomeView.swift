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

// Data struct for city time adjustment sheet
struct CityTimeAdjustmentData: Identifiable {
    let id = UUID()
    let cityName: String
    let timeZoneIdentifier: String
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

    @Binding var worldClocks: [WorldClock]
    @Binding var timeOffset: TimeInterval
    @Binding var showScrollTimeButtons: Bool
    @ObservedObject var weatherManager: WeatherManager
    @State private var currentDate = Date()
    @State private var showingRenameAlert = false
    @State private var renamingClockId: UUID? = nil
    @State private var renamingLocalTime = false
    @State private var newClockName = ""
    @State private var originalClockName = ""
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
    @AppStorage("showUVIndex") private var showUVIndex = false
    @AppStorage("showWindDirection") private var showWindDirection = false
    @AppStorage("showSunAzimuth") private var showSunAzimuth = false
    @AppStorage("showMoonAzimuth") private var showMoonAzimuth = false
    @AppStorage("showMoonSunAzimuth") private var showMoonSunAzimuth = false
    @AppStorage("showSunriseSunset") private var showSunriseSunset = false
    @AppStorage("showDaylight") private var showDaylight = false
    @AppStorage("showTimeOverlay") private var showTimeOverlay = false
    @AppStorage("showSolarCurve") private var showSolarCurve = false
    @AppStorage("showWhatsNewSwipeAdjust") private var showWhatsNewSwipeAdjust = true
    @AppStorage("showShakeToResetTip") private var showShakeToResetTip = false
    @AppStorage("hasTriggeredShakeToResetTip") private var hasTriggeredShakeToResetTip = false
    @AppStorage("homeTimerConfiguredSeconds") private var homeTimerConfiguredSeconds = 0
    @AppStorage("homeTimerEndDateEpoch") private var homeTimerEndDateEpoch: Double = 0
    @AppStorage("homeTimerCompletionHandled") private var homeTimerCompletionHandled = false
    @AppStorage("homeTimerPaused") private var homeTimerPaused = false
    @AppStorage("homeTimerPausedRemainingSeconds") private var homeTimerPausedRemainingSeconds = 0
    @AppStorage("homeTimerAlarmID") private var homeTimerAlarmIDRawValue = ""
    
    // Namespace for zoom transition
    @Namespace private var earthViewNamespace
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // UserDefaults key for storing world clocks
    private let worldClocksKey = "savedWorldClocks"
    private let collectionsKey = "savedCityCollections"
    private let alarmManager = AlarmManager.shared

    @State private var homeTimerAlarmSyncVersion = 0
    
    // MARK: - Cached Time Formatting
    private static let timeFormatterCache: NSCache<NSString, DateFormatter> = {
        let cache = NSCache<NSString, DateFormatter>()
        cache.countLimit = 50
        return cache
    }()
    
    private static func timeFormatter(for timeZone: TimeZone, use24Hour: Bool) -> DateFormatter {
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
    
    private func formattedTime(for timeZone: TimeZone) -> String {
        let formatter = Self.timeFormatter(for: timeZone, use24Hour: use24HourFormat)
        return formatter.string(from: currentDate.addingTimeInterval(timeOffset))
    }

    private var hasConfiguredHomeTimer: Bool {
        homeTimerConfiguredSeconds > 0
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

    private func clearHomeTimer() {
        homeTimerConfiguredSeconds = 0
        homeTimerEndDateEpoch = 0
        homeTimerCompletionHandled = false
        homeTimerPaused = false
        homeTimerPausedRemainingSeconds = 0
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
                eventTitle: String(localized: "Timer"),
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

    private func weatherConditionForSky(at timeZoneIdentifier: String) -> WeatherCondition? {
        guard showWeather else { return nil }
        return weatherManager.weatherData[timeZoneIdentifier]?.condition
    }

    private var effectiveShowWeatherCondition: Bool {
        hasLifetimeAccess && showWeatherCondition
    }

    private var effectiveShowTemperatureIndicator: Bool {
        hasLifetimeAccess && showTemperatureIndicator
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
        hasLifetimeAccess && showTimeOverlay
    }

    private var complicationOptions: ComplicationDisplayOptions {
        ComplicationDisplayOptions(
            showAnalogClock: showAnalogClock,
            analogClockShowScale: analogClockShowScale,
            showSunPosition: showSunPosition,
            showWeatherCondition: effectiveShowWeatherCondition,
            showTemperatureIndicator: effectiveShowTemperatureIndicator,
            showUVIndex: effectiveShowUVIndex,
            showWindDirection: effectiveShowWindDirection,
            showSunAzimuth: showSunAzimuth,
            showMoonAzimuth: effectiveShowMoonAzimuth,
            showMoonSunAzimuth: effectiveShowMoonSunAzimuth,
            showSunriseSunset: showSunriseSunset,
            showDaylight: effectiveShowDaylight,
            showTimeOverlay: effectiveShowTimeOverlay,
            showSolarCurve: showSolarCurve
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
            if granted && error == nil {
                DispatchQueue.main.async {
                    // Create event with adjusted time
                    let event = EKEvent(eventStore: self.eventStore)
                    
                    // Calculate the adjusted start time for the selected timezone
                    let currentDate = Date()
                    let formatter = DateFormatter()
                    formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    
                    // Get the current time in the target timezone
                    let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
                    
                    // Calculate time in target timezone adjusted by the offset
                    let adjustedDate = currentDate.addingTimeInterval(self.timeOffset)
                    
                    // Set the start date
                    event.startDate = adjustedDate
                    
                    // Set end date with user-configured default duration
                    event.endDate = adjustedDate.addingTimeInterval(self.defaultEventDuration)
                    
                    // Set calendar - use selected calendar if available, otherwise default
                    if !self.selectedCalendarIdentifier.isEmpty,
                       let selectedCalendar = self.eventStore.calendars(for: .event).first(where: { $0.calendarIdentifier == self.selectedCalendarIdentifier }) {
                        event.calendar = selectedCalendar
                    } else {
                        event.calendar = self.eventStore.defaultCalendarForNewEvents
                    }
                    
                    // Add notes with the city and time information
                    formatter.timeZone = targetTimeZone
                    if self.use24HourFormat {
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
                    
                    event.notes = String(format: String(localized: "Time in %@: %@ · %@"), cityName, timeString, dateString)
                    
                    // Store the event and show the editor
                    self.eventToEdit = event
                    self.scheduleForTimeZone = timeZoneIdentifier
                    self.showEventEditor = true
                }
            } else {
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
            }
        }
    }
    
    // Get formatted date for city with Natural Dates setting
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
        
        let dateString = getCityDate(
            timeZoneIdentifier: timeZoneIdentifier,
            baseDate: currentDate,
            offset: timeOffset
        )
        
        let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
        
        let clock = WorldClock(cityName: cityName, timeZoneIdentifier: timeZoneIdentifier)
        let additionalText = additionalTimeDisplay == "Time Difference" ? clock.timeDifference : clock.utcOffset
        
        let snapshotView = CityCardSnapshotView(
            cityName: cityName,
            timeString: timeString,
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
                if displayedClocks.isEmpty && !showLocalTime && !hasConfiguredHomeTimer {
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
                                configuredSeconds: homeTimerConfiguredSeconds,
                                endDateEpoch: homeTimerEndDateEpoch,
                                isPaused: homeTimerPaused,
                                pausedRemainingSeconds: homeTimerPausedRemainingSeconds,
                                onTap: handleHomeTimerTap,
                                onReset: resetHomeTimer,
                                onDelete: clearHomeTimer
                            )
                        }
                        
                        // Local Time Section
                        if showLocalTime {
                            Section {
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
                                            
                                            Text(currentDate.formattedDate(
                                                style: dateStyle,
                                                timeZoneIdentifier: TimeZone.current.identifier,
                                                timeOffset: timeOffset
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
                                            
                                            Text(formattedTime(for: .current))
                                            .font(.system(size: 36))
                                            .fontWeight(.light)
                                            .fontDesign(.rounded)
                                            .monospacedDigit()
                                            .contentTransition(.numericText())
                                            .clipped()
                                        }
                                        .padding(.bottom, -4)
                                        
                                        // Available Time Display with Progress Indicator
                                        // Only show if enabled AND at least one weekday is selected
                                        if hasLifetimeAccess && availableTimeEnabled && !availableWeekdays.isEmpty {
                                            
                                            AvailableTimeIndicator(
                                                currentDate: currentDate,
                                                timeOffset: timeOffset,
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
                                        date: currentDate.addingTimeInterval(timeOffset),
                                        timeZone: TimeZone.current,
                                        options: complicationOptions,
                                        bottomPadding: (hasLifetimeAccess && availableTimeEnabled && !availableWeekdays.isEmpty) ? 18 : 0
                                    )
                                    .environmentObject(weatherManager)
                                }
                                // Make entire row tappable
                                .contentShape(Rectangle())
                                // Sky Background
                                .listRowBackground(
                                    showSkyDot ? SkyBackgroundView(
                                        date: currentDate.addingTimeInterval(timeOffset),
                                        timeZoneIdentifier: TimeZone.current.identifier,
                                        weatherCondition: weatherConditionForSky(at: TimeZone.current.identifier)
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
                                ZStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        // Top row: Additional time display and Date
                                        if additionalTimeDisplay != "None" {
                                            HStack {
                                                // Display based on selected option
                                                let additionalText = additionalTimeDisplay == "Time Difference" ? clock.timeDifference : clock.utcOffset
                                                if !additionalText.isEmpty || additionalTimeDisplay == "UTC" {
                                                    Text(additionalText)
                                                        .font(.subheadline)
                                                        .foregroundStyle(.secondary)
                                                        .blendMode(.plusLighter)
                                                }
                                                
                                                Spacer()
                                                
                                                // Weather display for world clock
                                                if showWeather {
                                                    WeatherView(
                                                        weather: weatherManager.weatherData[clock.timeZoneIdentifier],
                                                        useCelsius: useCelsius
                                                    )
                                                    .contentTransition(.numericText())
                                                }
                                                
                                                Text(getCityDate(timeZoneIdentifier: clock.timeZoneIdentifier, baseDate: currentDate, offset: timeOffset))
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                                    .blendMode(.plusLighter)
                                                    .contentTransition(.numericText())
                                                    .clipped()
                                            }
                                        } else {
                                            HStack {
                                                if showSkyDot {
                                                    SkyDotView(
                                                        date: currentDate.addingTimeInterval(timeOffset),
                                                        timeZoneIdentifier: clock.timeZoneIdentifier,
                                                        weatherCondition: weatherConditionForSky(at: clock.timeZoneIdentifier)
                                                    )
                                                }
                                                
                                                Spacer()
                                                
                                                // Weather display for world clock (when time difference is hidden)
                                                if showWeather {
                                                    WeatherView(
                                                        weather: weatherManager.weatherData[clock.timeZoneIdentifier],
                                                        useCelsius: useCelsius
                                                    )
                                                    .contentTransition(.numericText())
                                                }
                                                
                                                Text(getCityDate(timeZoneIdentifier: clock.timeZoneIdentifier, baseDate: currentDate, offset: timeOffset))
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                                    .contentTransition(.numericText())
                                                    .clipped()
                                            }
                                        }
                                        
                                        // Bottom row: City name and Time (baseline aligned)
                                        HStack(alignment: .lastTextBaseline) {
                                            Text(getLocalizedCityName(for: clock))
                                                .font(.headline)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                                .frame(maxWidth: hasVisibleComplication ? 120 : .infinity, alignment: .leading)
                                                .contentTransition(.numericText())
                                            
                                            Spacer()
                                            
                                            Text(formattedTime(for: TimeZone(identifier: clock.timeZoneIdentifier) ?? .current))
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
                                        date: currentDate.addingTimeInterval(timeOffset),
                                        timeZone: TimeZone(identifier: clock.timeZoneIdentifier) ?? TimeZone.current,
                                        options: complicationOptions,
                                        bottomPadding: 0
                                    )
                                    .environmentObject(weatherManager)
                                }
                                // Make entire row tappable
                                .contentShape(Rectangle())
                                // Sky Background
                                .listRowBackground(
                                    showSkyDot ? SkyBackgroundView(
                                        date: currentDate.addingTimeInterval(timeOffset),
                                        timeZoneIdentifier: clock.timeZoneIdentifier,
                                        weatherCondition: weatherConditionForSky(at: clock.timeZoneIdentifier)
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
                    ScrollTimeView(timeOffset: $timeOffset, showButtons: $showScrollTimeButtons, worldClocks: $worldClocks)
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
                            SkyBackgroundView(
                                date: currentDate.addingTimeInterval(timeOffset),
                                timeZoneIdentifier: TimeZone.current.identifier,
                                weatherCondition: weatherConditionForSky(at: TimeZone.current.identifier)
                            )
                            .frame(width: 500, height: 500)
                            .blur(radius: 50)
                            .offset(y: -250)
                            .opacity(0.35)
                            
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
            .animation(.spring(), value: showAnalogClock)
            .animation(.spring(), value: showSunPosition)
            .animation(.spring(), value: effectiveShowWeatherCondition)
            .animation(.spring(), value: effectiveShowTemperatureIndicator)
            .animation(.spring(), value: effectiveShowUVIndex)
            .animation(.spring(), value: effectiveShowWindDirection)
            .animation(.spring(), value: showSunAzimuth)
            .animation(.spring(), value: effectiveShowMoonAzimuth)
            .animation(.spring(), value: effectiveShowMoonSunAzimuth)
            .animation(.spring(), value: showSunriseSunset)
            .animation(.spring(), value: effectiveShowDaylight)
            .animation(.spring(), value: effectiveShowTimeOverlay)
            .animation(.spring(), value: showSolarCurve)
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
                        
                        // Share Section - only show if there are world clocks
                        if !worldClocks.isEmpty {
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

                        Divider()
                        
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

            // Share Cities Sheet
            .sheet(isPresented: $showShareSheet) {
                ShareCitiesSheet(
                    worldClocks: $worldClocks,
                    showSheet: $showShareSheet,
                    currentDate: currentDate,
                    timeOffset: timeOffset
                )
                .environmentObject(weatherManager)
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
                SetTimerSheet(initialDurationSeconds: homeTimerConfiguredSeconds) { durationSeconds in
                    startHomeTimer(durationSeconds: durationSeconds)
                }
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
