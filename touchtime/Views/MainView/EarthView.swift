//
//  EarthView.swift
//  touchtime
//
//  Created on 02/10/2025.
//

import SwiftUI
import MapKit
import Combine
import UIKit
import EventKit
import EventKitUI

struct EarthView: View {
    @Binding var worldClocks: [WorldClock]
    @State private var position = MapCameraPosition.region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
    ))
    @State private var currentDate = Date()
    @State private var timerCancellable: AnyCancellable?
    @State private var showShareSheet = false
    @State private var showSettingsSheet = false
    @State private var showingRenameAlert = false
    @State private var renamingClockId: UUID? = nil
    @State private var newClockName = ""
    @State private var originalClockName = ""
    @State private var eventStore = EKEventStore()
    @State private var showEventEditor = false
    @State private var eventToEdit: EKEvent?
    @State private var showMapMenu = false
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("isUsingExploreMode") private var isUsingExploreMode = false
    @AppStorage("showSkyDot") private var showSkyDot = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("defaultEventDuration") private var defaultEventDuration: Double = 3600
    @AppStorage("selectedCalendarIdentifier") private var selectedCalendarIdentifier: String = ""
    @AppStorage("showLocalTime") private var showLocalTime = true
    @AppStorage("customLocalName") private var customLocalName = ""
    
    // 設置地圖縮放限制
    private let cameraBounds = MapCameraBounds(
        minimumDistance: 5000000,     // 最小高度 1,000km（最大放大）
        maximumDistance: nil
    )
    
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
    
    // Convert timezone identifier to coordinate using shared utility
    func getCoordinate(for timeZoneIdentifier: String) -> CLLocationCoordinate2D? {
        if let coords = TimeZoneCoordinates.getCoordinate(for: timeZoneIdentifier) {
            return CLLocationCoordinate2D(latitude: coords.latitude, longitude: coords.longitude)
        }
        return nil
    }
    
    // Add to Calendar
    func addToCalendar(timeZoneIdentifier: String, cityName: String) {
        eventStore.requestFullAccessToEvents { granted, error in
            if granted && error == nil {
                DispatchQueue.main.async {
                    let event = EKEvent(eventStore: self.eventStore)
                    
                    let currentDate = Date()
                    let formatter = DateFormatter()
                    formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    
                    let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
                    
                    event.startDate = currentDate
                    event.endDate = currentDate.addingTimeInterval(self.defaultEventDuration)
                    
                    if !self.selectedCalendarIdentifier.isEmpty,
                       let selectedCalendar = self.eventStore.calendars(for: .event).first(where: { $0.calendarIdentifier == self.selectedCalendarIdentifier }) {
                        event.calendar = selectedCalendar
                    } else {
                        event.calendar = self.eventStore.defaultCalendarForNewEvents
                    }
                    
                    formatter.timeZone = targetTimeZone
                    if self.use24HourFormat {
                        formatter.dateFormat = "HH:mm"
                    } else {
                        formatter.dateFormat = "h:mm a"
                    }
                    let timeString = formatter.string(from: currentDate)
                    
                    formatter.dateFormat = "E, d MMM"
                    let dateString = formatter.string(from: currentDate)
                    
                    event.notes = "Time in \(cityName): \(timeString) · \(dateString)"
                    
                    self.eventToEdit = event
                    self.showEventEditor = true
                }
            } else {
                print("Calendar access denied or error: \(String(describing: error))")
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
    
    // Save world clocks to UserDefaults
    func saveWorldClocks() {
        if let encoded = try? JSONEncoder().encode(worldClocks) {
            UserDefaults.standard.set(encoded, forKey: "savedWorldClocks")
        }
    }
    
    // Start the timer
    func startTimer() {
        // Immediately update the current date
        currentDate = Date()
        
        // Cancel any existing timer
        timerCancellable?.cancel()
        
        // Create a new timer
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                currentDate = Date()
            }
    }
    
    // Stop the timer
    func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $position, bounds: cameraBounds) {
                // Show local time marker
                if showLocalTime {
                    if let coordinate = getCoordinate(for: TimeZone.current.identifier) {
                        Annotation(customLocalName.isEmpty ? localCityName : customLocalName, coordinate: coordinate) {
                            VStack(spacing: 6) {
                                // Time bubble with SkyDot - wrapped in Menu
                                Menu {
                                    Button(action: {
                                        let cityName = customLocalName.isEmpty ? localCityName : customLocalName
                                        addToCalendar(timeZoneIdentifier: TimeZone.current.identifier, cityName: cityName)
                                    }) {
                                        Label("Schedule Event", systemImage: "calendar.badge.plus")
                                    }
                                    
                                    Button(action: {
                                        renamingClockId = nil // Use nil to indicate local time
                                        originalClockName = localCityName
                                        newClockName = customLocalName.isEmpty ? localCityName : customLocalName
                                        showingRenameAlert = true
                                    }) {
                                        Label("Rename", systemImage: "pencil.tip.crop.circle")
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        
                                        if showSkyDot {
                                            SkyDotView(
                                                date: currentDate,
                                                timeZoneIdentifier: TimeZone.current.identifier
                                            )
                                            .overlay(
                                                Capsule(style: .continuous)
                                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                                    .blendMode(.plusLighter)
                                            )
                                            .transition(.blurReplace)
                                        }
                                        
                                        HStack(spacing: 4) {
                                            Text({
                                                let formatter = DateFormatter()
                                                formatter.timeZone = TimeZone.current
                                                formatter.locale = Locale(identifier: "en_US_POSIX")
                                                if use24HourFormat {
                                                    formatter.dateFormat = "HH:mm"
                                                } else {
                                                    formatter.dateFormat = "h:mma"
                                                }
                                                return formatter.string(from: currentDate).lowercased()
                                            }())
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                            .monospacedDigit()
                                            .contentTransition(.numericText())
                                            .animation(.spring(), value: currentDate)
                                            
                                            Image(systemName: "location.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.white)
                                        }

                                    }
                                    .animation(.spring(), value: showSkyDot)
                                    // Overall Paddings
                                    .padding(.leading, showSkyDot ? 4 : 8)
                                    .padding(.trailing, 8)
                                    .padding(.vertical, 4)
                                    .clipShape(Capsule())
                                    .glassEffect(.clear.interactive())
                                }
                            }
                        }
                    }
                }
                
                // Show world clock markers
                ForEach(worldClocks) { clock in
                    // Skip if this clock has the same timezone as local time and local time is shown
                    if showLocalTime && clock.timeZoneIdentifier == TimeZone.current.identifier {
                        // Don't show duplicate of local time
                    } else if let coordinate = getCoordinate(for: clock.timeZoneIdentifier) {
                        Annotation(clock.cityName, coordinate: coordinate) {
                            
                            VStack(spacing: 6) {
                                // Time bubble with SkyDot - wrapped in Menu
                                Menu {
                                    Button(action: {
                                        addToCalendar(timeZoneIdentifier: clock.timeZoneIdentifier, cityName: clock.cityName)
                                    }) {
                                        Label("Schedule Event", systemImage: "calendar.badge.plus")
                                    }
       
                                    Button(action: {
                                        renamingClockId = clock.id
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
                                    
                                    Button(role: .destructive, action: {
                                        if let index = worldClocks.firstIndex(where: { $0.id == clock.id }) {
                                            withAnimation {
                                                worldClocks.remove(at: index)
                                                saveWorldClocks()
                                            }
                                        }
                                    }) {
                                        Label("Delete", systemImage: "xmark.circle")
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        if showSkyDot {
                                            SkyDotView(
                                                date: currentDate,
                                                timeZoneIdentifier: clock.timeZoneIdentifier
                                            )
                                            .overlay(
                                                Capsule(style: .continuous)
                                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                                    .blendMode(.plusLighter)
                                            )
                                            .transition(.blurReplace)
                                        }
                                        
                                        Text({
                                            let formatter = DateFormatter()
                                            formatter.timeZone = TimeZone(identifier: clock.timeZoneIdentifier)
                                            formatter.locale = Locale(identifier: "en_US_POSIX")
                                            if use24HourFormat {
                                                formatter.dateFormat = "HH:mm"
                                            } else {
                                                formatter.dateFormat = "h:mma"
                                            }
                                            return formatter.string(from: currentDate).lowercased()
                                        }())
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .monospacedDigit()
                                        .contentTransition(.numericText())
                                        .animation(.spring(), value: currentDate)
                                    }
                                    .animation(.spring(), value: showSkyDot)
                                    .padding(.leading, showSkyDot ? 4 : 8)
                                    .padding(.trailing, 8)
                                    .padding(.vertical, 4)
                                    .clipShape(Capsule())
                                    .glassEffect(.clear.interactive())
                                }
                            }
                        }
                    }
                }
            }
            .mapStyle(isUsingExploreMode ? .standard(elevation: .realistic) : .imagery(elevation: .realistic))
            .mapControls {
                MapScaleView()
                MapCompass()
            }
            
            // Bottom Control Bar
            HStack(spacing: 0) {
                
                // Back to Local Time Button
                Button(action: {
                    if hapticEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                        impactFeedback.prepare()
                        impactFeedback.impactOccurred()
                    }
                    
                    // Navigate to local time location
                    if let localCoordinate = getCoordinate(for: TimeZone.current.identifier) {
                        withAnimation(.smooth()) {
                            position = MapCameraPosition.region(MKCoordinateRegion(
                                center: localCoordinate,
                                span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
                            ))
                        }
                    }
                }) {
                    Image(systemName: "location.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        
                }
                
                // Map Mode Toggle Button
                Button(action: {
                    if hapticEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                        impactFeedback.prepare()
                        impactFeedback.impactOccurred()
                    }
                    
                    withAnimation(.smooth()) {
                        isUsingExploreMode.toggle()
                    }
                }) {
                    Image(systemName: isUsingExploreMode ? "view.2d" : "view.3d")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .clipShape(.capsule)
            .glassEffect(.regular.interactive())
            .padding(.bottom, 8)
        }
            .navigationTitle("Touch Time")
            .navigationBarTitleDisplayMode(.inline)
            
        .animation(.spring(), value: worldClocks)
        .animation(.smooth(), value: isUsingExploreMode)
            
        .task {
            // 立即更新时间，避免显示缓存的时间
            currentDate = Date()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // Hide share button when no cities
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
            .sheet(isPresented: $showShareSheet) {
                ShareCitiesSheet(
                    worldClocks: $worldClocks,
                    showSheet: $showShareSheet,
                    currentDate: currentDate,
                    timeOffset: 0
                )
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView(worldClocks: $worldClocks)
            }
            
            // Rename Alert
            .alert("Rename", isPresented: $showingRenameAlert) {
                TextField(originalClockName, text: $newClockName)
                Button("Cancel", role: .cancel) {
                    newClockName = ""
                    originalClockName = ""
                    renamingClockId = nil
                }
                Button("Save") {
                    let nameToSave = newClockName.isEmpty ? originalClockName : newClockName
                    
                    if renamingClockId == nil {
                        // Renaming local time
                        customLocalName = nameToSave == localCityName ? "" : nameToSave
                    } else if let clockId = renamingClockId,
                              let index = worldClocks.firstIndex(where: { $0.id == clockId }) {
                        // Renaming a world clock
                        worldClocks[index].cityName = nameToSave
                        saveWorldClocks()
                    }
                    newClockName = ""
                    originalClockName = ""
                    renamingClockId = nil
                }
            } message: {
                Text("Customize the name of this city")
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
        }
    }  
}
