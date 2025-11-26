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

struct HomeView: View {
    @Binding var worldClocks: [WorldClock]
    @State private var currentDate = Date()
    @State private var timeOffset: TimeInterval = 0
    @State private var showingRenameAlert = false
    @State private var renamingClockId: UUID? = nil
    @State private var renamingLocalTime = false
    @State private var newClockName = ""
    @State private var originalClockName = ""
    @State private var showScrollTimeButtons = false
    @State private var showShareSheet = false
    @State private var showSettingsSheet = false
    @State private var eventStore = EKEventStore()
    @State private var showEventEditor = false
    @State private var eventToEdit: EKEvent?
    @State private var scheduleForTimeZone: String = TimeZone.current.identifier
    @State private var showSunriseSunsetSheet = false
    @State private var selectedTimeZone: String = ""
    @State private var selectedCityName: String = ""
    @State private var showArrangeListSheet = false
    
    // Collection management
    @State private var collections: [CityCollection] = []
    @State private var selectedCollectionId: UUID? = nil
    @AppStorage("selectedCollectionId") private var savedSelectedCollectionId: String = ""
    
    // Zoom transition namespace
    @Namespace private var namespace
    
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
    @AppStorage("dateStyle") private var dateStyle = "Relative"
    @AppStorage("showWeather") private var showWeather = false
    @AppStorage("useCelsius") private var useCelsius = true
    @AppStorage("showAnalogClock") private var showAnalogClock = false
    
    @StateObject private var weatherManager = WeatherManager()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // UserDefaults key for storing world clocks
    private let worldClocksKey = "savedWorldClocks"
    private let collectionsKey = "savedCityCollections"
    
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
        return "Default"
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
                // Provide haptic feedback on permission denied if enabled
                if self.hapticEnabled {
                    DispatchQueue.main.async {
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
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                
                // Blank View
                if displayedClocks.isEmpty && !showLocalTime {
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
                    .transition(.opacity.combined(with: .slide)) // Collection Animation
                    
                } else {
                    // Main List Content
                    List {
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
                                        }
                                        
                                        // Bottom row: Location and Time (baseline aligned)
                                        HStack(alignment: .lastTextBaseline) {
                                            
                                            Text(String(localized: "Local"))
                                                .font(.headline)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                                .frame(maxWidth: showAnalogClock ? 120 : .infinity, alignment: .leading)
                                                .contentTransition(.numericText())
                                            
                                            
                                            Spacer()
                                            
                                            Text({
                                                let formatter = DateFormatter()
                                                formatter.timeZone = TimeZone.current
                                                formatter.locale = Locale(identifier: "en_US_POSIX")
                                                if use24HourFormat {
                                                    formatter.dateFormat = "HH:mm"
                                                } else {
                                                    formatter.dateFormat = "h:mm"
                                                }
                                                let adjustedDate = currentDate.addingTimeInterval(timeOffset)
                                                return formatter.string(from: adjustedDate)
                                            }())
                                            .font(.system(size: 36))
                                            .fontWeight(.light)
                                            .fontDesign(.rounded)
                                            .monospacedDigit()
                                            .contentTransition(.numericText())
                                        }
                                        .padding(.bottom, -4)
                                        
                                        // Available Time Display with Progress Indicator
                                        // Only show if enabled AND at least one weekday is selected
                                        if availableTimeEnabled && !availableWeekdays.isEmpty {
                                            
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
                                    
                                    // Analog Clock Overlay - Centered
                                    if showAnalogClock {
                                        AnalogClockView(
                                            date: currentDate.addingTimeInterval(timeOffset),
                                            size: 64,
                                            timeZone: TimeZone.current
                                        )
                                        .padding(.bottom, (availableTimeEnabled && !availableWeekdays.isEmpty) ? 18 : 0)
                                        .transition(.blurReplace)
                                    }
                                }
                                // Make entire row tappable
                                .contentShape(Rectangle())
                                // Sky Background
                                .listRowBackground(
                                    showSkyDot ? SkyBackgroundView(
                                        date: currentDate.addingTimeInterval(timeOffset),
                                        timeZoneIdentifier: TimeZone.current.identifier
                                    ) : nil
                                )
                                .id("local-\(showSkyDot)")
                                // Fetch weather when weather toggle changes or view appears
                                .task(id: showWeather) {
                                    if showWeather {
                                        await weatherManager.getWeather(for: TimeZone.current.identifier)
                                    }
                                }
                                
                                
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
                                
                                // Menu Local Time
                                .contextMenu {
                                    Button(action: {
                                        let cityName = String(localized: "Local")
                                        addToCalendar(timeZoneIdentifier: TimeZone.current.identifier, cityName: cityName)
                                    }) {
                                        Label("Schedule Event", systemImage: "calendar.badge.plus")
                                    }
                                    
                                    Divider()
                                    
                                    Button(action: {
                                        let cityName = String(localized: "Local")
                                        copyTimeAsText(cityName: cityName, timeZoneIdentifier: TimeZone.current.identifier)
                                    }) {
                                        Label(String(localized: "Copy as Text"), systemImage: "quote.opening")
                                    }
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
                                                if showSkyDot {
                                                    SkyDotView(
                                                        date: currentDate.addingTimeInterval(timeOffset),
                                                        timeZoneIdentifier: clock.timeZoneIdentifier
                                                    )
                                                }
                                                
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
                                                }
                                                
                                                Text(getCityDate(timeZoneIdentifier: clock.timeZoneIdentifier, baseDate: currentDate, offset: timeOffset))
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                                    .blendMode(.plusLighter)
                                                    .contentTransition(.numericText())
                                            }
                                        } else {
                                            HStack {
                                                if showSkyDot {
                                                    SkyDotView(
                                                        date: currentDate.addingTimeInterval(timeOffset),
                                                        timeZoneIdentifier: clock.timeZoneIdentifier
                                                    )
                                                }
                                                
                                                Spacer()
                                                
                                                // Weather display for world clock (when time difference is hidden)
                                                if showWeather {
                                                    WeatherView(
                                                        weather: weatherManager.weatherData[clock.timeZoneIdentifier],
                                                        useCelsius: useCelsius
                                                    )
                                                }
                                                
                                                Text(getCityDate(timeZoneIdentifier: clock.timeZoneIdentifier, baseDate: currentDate, offset: timeOffset))
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                                    .contentTransition(.numericText())
                                            }
                                        }
                                        
                                        // Bottom row: City name and Time (baseline aligned)
                                        HStack(alignment: .lastTextBaseline) {
                                            Text(getLocalizedCityName(for: clock))
                                                .font(.headline)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                                .frame(maxWidth: showAnalogClock ? 120 : .infinity, alignment: .leading)
                                                .contentTransition(.numericText())
                                            
                                            Spacer()
                                            
                                            Text({
                                                let formatter = DateFormatter()
                                                formatter.timeZone = TimeZone(identifier: clock.timeZoneIdentifier)
                                                formatter.locale = Locale(identifier: "en_US_POSIX")
                                                if use24HourFormat {
                                                    formatter.dateFormat = "HH:mm"
                                                } else {
                                                    formatter.dateFormat = "h:mm"
                                                }
                                                let adjustedDate = currentDate.addingTimeInterval(timeOffset)
                                                return formatter.string(from: adjustedDate)
                                            }())
                                            .font(.system(size: 36))
                                            .fontWeight(.light)
                                            .fontDesign(.rounded)
                                            .monospacedDigit()
                                            .contentTransition(.numericText())
                                        }
                                        .padding(.bottom, -4)
                                    }
                                    
                                    // Analog Clock Overlay - Centered
                                    if showAnalogClock {
                                        AnalogClockView(
                                            date: currentDate.addingTimeInterval(timeOffset),
                                            size: 64,
                                            timeZone: TimeZone(identifier: clock.timeZoneIdentifier) ?? TimeZone.current
                                        )
                                        .transition(.blurReplace)
                                    }
                                }
                                // Make entire row tappable
                                .contentShape(Rectangle())
                                // Sky Background
                                .listRowBackground(
                                    showSkyDot ? SkyBackgroundView(
                                        date: currentDate.addingTimeInterval(timeOffset),
                                        timeZoneIdentifier: clock.timeZoneIdentifier
                                    ) : nil
                                )
                                .id("\(clock.id)-\(showSkyDot)")
                                // Fetch weather for this city when weather toggle changes
                                .task(id: showWeather) {
                                    if showWeather {
                                        await weatherManager.getWeather(for: clock.timeZoneIdentifier)
                                    }
                                }
                                
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
                                    
                                    // Schedule event
                                    Button(action: {
                                        addToCalendar(timeZoneIdentifier: clock.timeZoneIdentifier, cityName: getLocalizedCityName(for: clock))
                                    }) {
                                        Label("Schedule Event", systemImage: "plus.circle")
                                    }
                                    
                                    Divider()
                                    
                                    // Copy as Text
                                    Button(action: {
                                        copyTimeAsText(cityName: getLocalizedCityName(for: clock), timeZoneIdentifier: clock.timeZoneIdentifier)
                                    }) {
                                        Label(String(localized: "Copy as Text"), systemImage: "quote.opening")
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
                            }
                        }
                    }
                    .listSectionSpacing(12) // List Paddings
                    .scrollIndicators(.hidden)
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .safeAreaPadding(.bottom, 52)
                    .id(selectedCollectionId?.uuidString ?? "default")
                    .transition(.opacity.combined(with: .slide)) // Collection Animation
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
                                timeZoneIdentifier: TimeZone.current.identifier
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
            .animation(.spring(), value: availableTimeEnabled)
            .animation(.spring(), value: showAnalogClock)
            .animation(.snappy(), value: selectedCollectionId) // Collection Animation
            
            // Navigation Title
            .navigationTitle(selectedCollectionId != nil ? currentCollectionName : "")
            .navigationBarTitleDisplayMode(.inline)
            
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // Show menu if there are world clocks or collections
                    if !worldClocks.isEmpty || !collections.isEmpty {
                        Menu {
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
                            
                            // Share Section
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
                        
                            // Arrange Section
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
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        // Provide haptic feedback if enabled
                        if hapticEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.prepare()
                            impactFeedback.impactOccurred()
                        }
                        showSettingsSheet = true
                    }) {
                        Image(systemName: "gear")
                    }
                    .matchedTransitionSource(id: "settings", in: namespace)
                }
            }
            
            .onReceive(timer) { _ in
                currentDate = Date()
            }
            
            .onAppear {
                loadCollections()
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
            
            // Share Cities Sheet
            .sheet(isPresented: $showShareSheet) {
                ShareCitiesSheet(
                    worldClocks: $worldClocks,
                    showSheet: $showShareSheet,
                    currentDate: currentDate,
                    timeOffset: timeOffset
                )
            }
            
            // Settings Sheet
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView(worldClocks: $worldClocks)
                    .navigationTransition(.zoom(sourceID: "settings", in: namespace))
                      //Customize sheet background
//                    .scrollContentBackground(.hidden)
//                    .presentationBackground(.ultraThinMaterial)
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
        }
        
    }
    
    // Save world clocks to UserDefaults
    func saveWorldClocks() {
        if let encoded = try? JSONEncoder().encode(worldClocks) {
            UserDefaults.standard.set(encoded, forKey: worldClocksKey)
        }
    }
    
    // Delete city from both worldClocks and all collections
    func deleteCity(withId cityId: UUID) {
        // Remove from worldClocks
        if let index = worldClocks.firstIndex(where: { $0.id == cityId }) {
            worldClocks.remove(at: index)
            saveWorldClocks()
        }
        
        // Remove from all collections
        for collectionIndex in collections.indices {
            if let cityIndex = collections[collectionIndex].cities.firstIndex(where: { $0.id == cityId }) {
                collections[collectionIndex].cities.remove(at: cityIndex)
            }
        }
        saveCollections()
    }
}
