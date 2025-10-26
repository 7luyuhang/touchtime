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
    
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showTimeDifference") private var showTimeDifference = true
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
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // UserDefaults key for storing world clocks
    private let worldClocksKey = "savedWorldClocks"
    
    // Get local city name from timezone
    var localCityName: String {
        let identifier = TimeZone.current.identifier
        let components = identifier.split(separator: "/")
        if components.count >= 2 {
            return components.last!.replacingOccurrences(of: "_", with: " ")
        } else {
            return identifier
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
                    
                    // Format date
                    formatter.dateFormat = "E, d MMM"
                    let dateString = formatter.string(from: adjustedDate)
                    
                    event.notes = "Time in \(cityName): \(timeString) · \(dateString)"
                    
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
                if worldClocks.isEmpty && !showLocalTime {
                    // Empty state view
                    ContentUnavailableView {
                        Label("Nothing here", systemImage: "location.magnifyingglass")
                    } description: {
                        Text("Add cities to track time.")
                    }
                    .background(Color.clear)
                } else {
                    // Main List Content
                    List {
                        // Local Time Section
                        if showLocalTime {
                            Section {
                                VStack(alignment: .leading, spacing: 4) {
                                    // Top row: "Local" label and Date
                                    HStack {
                                        Image(systemName: "location.fill")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .blendMode(.plusLighter)
                                        
                                        Spacer()
                                        
                                        Text({
                                            let formatter = DateFormatter()
                                            formatter.timeZone = TimeZone.current
                                            formatter.locale = Locale(identifier: "en_US_POSIX")
                                            formatter.dateStyle = .medium
                                            formatter.timeStyle = .none
                                            let adjustedDate = currentDate.addingTimeInterval(timeOffset)
                                            return formatter.string(from: adjustedDate)
                                        }())
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .contentTransition(.numericText())
                                        .blendMode(.plusLighter)
                                    }
                                    
                                    // Bottom row: Location and Time (baseline aligned)
                                    HStack(alignment: .lastTextBaseline) {
                                        
                                        Text(customLocalName.isEmpty ? localCityName : customLocalName)
                                            .font(.headline)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .contentTransition(.numericText())
                                        
                                        
                                        Spacer()
                                        
                                        HStack(alignment: .lastTextBaseline, spacing: 2) {
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
                                            
                                            if !use24HourFormat {
                                                Text({
                                                    let formatter = DateFormatter()
                                                    formatter.timeZone = TimeZone.current
                                                    formatter.locale = Locale(identifier: "en_US_POSIX")
                                                    formatter.dateFormat = "a"
                                                    formatter.amSymbol = "am"
                                                    formatter.pmSymbol = "pm"
                                                    let adjustedDate = currentDate.addingTimeInterval(timeOffset)
                                                    return formatter.string(from: adjustedDate)
                                                }())
                                                .font(.headline)
                                            }
                                        }
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
                                
                                
                                // Tap gesture for local time
                                .onTapGesture {
                                    selectedTimeZone = TimeZone.current.identifier
                                    selectedCityName = customLocalName.isEmpty ? localCityName : customLocalName
                                    showSunriseSunsetSheet = true
                                    
                                    // Provide haptic feedback if enabled
                                    if hapticEnabled {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                                        impactFeedback.prepare()
                                        impactFeedback.impactOccurred()
                                    }
                                }
                                
                                // Menu Local Time
                                .contextMenu {
                                    Button(action: {
                                        let cityName = customLocalName.isEmpty ? localCityName : customLocalName
                                        addToCalendar(timeZoneIdentifier: TimeZone.current.identifier, cityName: cityName)
                                    }) {
                                        Label("Schedule Event", systemImage: "calendar.badge.plus")
                                    }
                                    
                                    Divider()
                                    
                                    Button(action: {
                                        let cityName = customLocalName.isEmpty ? localCityName : customLocalName
                                        copyTimeAsText(cityName: cityName, timeZoneIdentifier: TimeZone.current.identifier)
                                    }) {
                                        Label("Copy as Text", systemImage: "quote.opening")
                                    }
                                    
                                    Button(action: {
                                        renamingLocalTime = true
                                        originalClockName = localCityName
                                        newClockName = customLocalName.isEmpty ? localCityName : customLocalName
                                        showingRenameAlert = true
                                    }) {
                                        Label("Rename", systemImage: "pencil.tip.crop.circle")
                                    }
                                }
                            }
                        }
                        
                        ForEach(worldClocks) { clock in
                            Section {
                                VStack(alignment: .leading, spacing: 4) {
                                    // Top row: Time difference and Date
                                    if showTimeDifference && !clock.timeDifference.isEmpty {
                                        HStack {
                                            if showSkyDot {
                                                SkyDotView(
                                                    date: currentDate.addingTimeInterval(timeOffset),
                                                    timeZoneIdentifier: clock.timeZoneIdentifier
                                                )
                                            }
                                            
                                            Text(clock.timeDifference)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                                .blendMode(.plusLighter)
                                            
                                            Spacer()
                                            
                                            Text(clock.currentDate(baseDate: currentDate, offset: timeOffset))
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                                .contentTransition(.numericText())
                                                .blendMode(.plusLighter)
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
                                            
                                            Text(clock.currentDate(baseDate: currentDate, offset: timeOffset))
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                                .contentTransition(.numericText())
                                        }
                                    }
                                    
                                    // Bottom row: City name and Time (baseline aligned)
                                    HStack(alignment: .lastTextBaseline) {
                                        Text(clock.cityName)
                                            .font(.headline)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .contentTransition(.numericText())
                                        
                                        Spacer()
                                        
                                        HStack(alignment: .lastTextBaseline, spacing: 2) {
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
                                            
                                            if !use24HourFormat {
                                                Text({
                                                    let formatter = DateFormatter()
                                                    formatter.timeZone = TimeZone(identifier: clock.timeZoneIdentifier)
                                                    formatter.locale = Locale(identifier: "en_US_POSIX")
                                                    formatter.dateFormat = "a"
                                                    formatter.amSymbol = "am"
                                                    formatter.pmSymbol = "pm"
                                                    let adjustedDate = currentDate.addingTimeInterval(timeOffset)
                                                    return formatter.string(from: adjustedDate)
                                                }())
                                                .font(.headline)
                                            }
                                        }
                                    }
                                    .padding(.bottom, -4)
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
                                
                                // Tap gesture for world clock
                                .onTapGesture {
                                    selectedTimeZone = clock.timeZoneIdentifier
                                    selectedCityName = clock.cityName
                                    showSunriseSunsetSheet = true
                                    
                                    // Provide haptic feedback if enabled
                                    if hapticEnabled {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                                        impactFeedback.prepare()
                                        impactFeedback.impactOccurred()
                                    }
                                }
                                
                                //Swipe to delete time
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        if let index = worldClocks.firstIndex(where: { $0.id == clock.id }) {
                                            worldClocks.remove(at: index)
                                            saveWorldClocks()
                                        }
                                    } label: {
                                        Label("", systemImage: "xmark.circle")
                                    }
                                }
                                
                                // Context Menu
                                .contextMenu {
                                    
                                    // Schedule event
                                    Button(action: {
                                        addToCalendar(timeZoneIdentifier: clock.timeZoneIdentifier, cityName: clock.cityName)
                                    }) {
                                        Label("Schedule Event", systemImage: "plus.circle")
                                    }
                                    
                                    Divider()
                                    
                                    // Copy as Text
                                    Button(action: {
                                        copyTimeAsText(cityName: clock.cityName, timeZoneIdentifier: clock.timeZoneIdentifier)
                                    }) {
                                        Label("Copy as Text", systemImage: "quote.opening")
                                    }
                                    
                                    // Rename
                                    Button(action: {
                                        renamingLocalTime = false
                                        renamingClockId = clock.id
                                        // Get original name from timezone identifier
                                        let identifier = clock.timeZoneIdentifier
                                        let components = identifier.split(separator: "/")
                                        originalClockName = components.count >= 2
                                        ? String(components.last!).replacingOccurrences(of: "_", with: " ")
                                        : String(identifier)
                                        newClockName = clock.cityName
                                        showingRenameAlert = true
                                    }) {
                                        Label("Rename", systemImage: "pencil.tip.crop.circle")
                                    }
                                    
                                    Divider()
                                    
                                    // Move to Top
                                    if let index = worldClocks.firstIndex(where: { $0.id == clock.id }), index != 0 {
                                        Button(action: {
                                            // Move to top
                                            withAnimation {
                                                let clockToMove = worldClocks.remove(at: index)
                                                worldClocks.insert(clockToMove, at: 0)
                                                saveWorldClocks()
                                            }
                                        }) {
                                            Label("Move to Top", systemImage: "arrow.up.to.line")
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    Button(role: .destructive, action: {
                                        // Delete
                                        if let index = worldClocks.firstIndex(where: { $0.id == clock.id }) {
                                            withAnimation {
                                                worldClocks.remove(at: index)
                                                saveWorldClocks()
                                            }
                                        }
                                    }) {
                                        Label("Delete", systemImage: "xmark.circle")
                                    }
                                }
                            }
                        }
                        
                    }
                    .listSectionSpacing(12) // List Paddings
                    .scrollIndicators(.hidden)
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .safeAreaPadding(.bottom, 56)
                }
                
                // Scroll Time View - Hide when renaming or when there's no content to display
                if !showingRenameAlert && !(worldClocks.isEmpty && !showLocalTime) {
                    ScrollTimeView(timeOffset: $timeOffset, showButtons: $showScrollTimeButtons, worldClocks: $worldClocks)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .transition(.blurReplace)
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
            .animation(.spring, value: showingRenameAlert)
            .animation(.spring, value: customLocalName)
            .animation(.spring, value: worldClocks)
            .animation(.spring, value: showSkyDot)
            .animation(.spring, value: showLocalTime)
            .animation(.spring, value: availableTimeEnabled)
            
            // Navigation Title
            .navigationTitle("Touch Time")
            .navigationBarTitleDisplayMode(.inline)
            
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // Only show Share button if there are world clocks to share
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
                            Image(systemName: "square.and.arrow.up")
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
                            .frame(width: 24)
                    }
                }
            }
            
            .onReceive(timer) { _ in
                currentDate = Date()
            }
            
            // Rename
            .alert("Rename", isPresented: $showingRenameAlert) {
                TextField(originalClockName, text: $newClockName)
                Button("Cancel", role: .cancel) {
                    newClockName = ""
                    originalClockName = ""
                    renamingClockId = nil
                    renamingLocalTime = false
                }
                Button("Save") {
                    let nameToSave = newClockName.isEmpty ? originalClockName : newClockName
                    
                    if renamingLocalTime {
                        customLocalName = nameToSave == localCityName ? "" : nameToSave
                    } else if let clockId = renamingClockId,
                              let index = worldClocks.firstIndex(where: { $0.id == clockId }) {
                        worldClocks[index].cityName = nameToSave
                        saveWorldClocks()
                    }
                    newClockName = ""
                    originalClockName = ""
                    renamingClockId = nil
                    renamingLocalTime = false
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
                .presentationDetents([.medium])
            }
        }
        
    }
    
    // Save world clocks to UserDefaults
    func saveWorldClocks() {
        if let encoded = try? JSONEncoder().encode(worldClocks) {
            UserDefaults.standard.set(encoded, forKey: worldClocksKey)
        }
    }
}
