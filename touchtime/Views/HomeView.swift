//
//  HomeView.swift
//  touchtime
//
//  Created on 23/09/2025.
//

import SwiftUI
import Combine
import UIKit

struct HomeView: View {
    @Binding var worldClocks: [WorldClock]
    @State private var currentDate = Date()
    @State private var timeOffset: TimeInterval = 0
    @State private var showingRenameAlert = false
    @State private var renamingClockId: UUID? = nil
    @State private var renamingLocalTime = false
    @State private var newClockName = ""
    @State private var originalClockName = ""
    @State private var isEditing = false
    @State private var showScrollTimeButtons = false
    @State private var showShareSheet = false
    @State private var showSettingsSheet = false
    
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showTimeDifference") private var showTimeDifference = true
    @AppStorage("showLocalTime") private var showLocalTime = true
    @AppStorage("customLocalName") private var customLocalName = ""
    @AppStorage("showSkyDot") private var showSkyDot = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    
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
                // Main List Content
                List {
                    // Local Time Section
                    if showLocalTime {
                        Section {
                            VStack(alignment: .leading, spacing: 4) {
                                // Top row: "Local" label and Date
                                HStack {
                                    
                                    HStack (spacing: 4) {
                                        Image(systemName: "location.fill")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        
                                        Text("Local")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    
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
                                }
                                
                                // Bottom row: Location and Time (baseline aligned)
                                HStack(alignment: .lastTextBaseline) {
                                    
                                   
                                
                                        Text(customLocalName.isEmpty ? localCityName : customLocalName)
                                            .font(.headline)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .contentTransition(.numericText())
                                    
                                    
                                    Spacer()
                                    
                                    HStack(alignment: .lastTextBaseline, spacing: 4) {
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
                            }
                            .contextMenu {
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
                                    
                                    Spacer()
                                    
                                    Text(clock.currentDate(baseDate: currentDate, offset: timeOffset))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
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
                                
                                HStack(alignment: .lastTextBaseline, spacing: 4) {
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
                            Button(action: {
                                copyTimeAsText(cityName: clock.cityName, timeZoneIdentifier: clock.timeZoneIdentifier)
                            }) {
                                Label("Copy as Text", systemImage: "quote.opening")
                            }
                            
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
                    .onMove(perform: moveClocks)
                }
                .scrollIndicators(.hidden)
                .safeAreaPadding(.bottom, 64)
                
                // Scroll Time View - Hide when in edit mode or renaming
                if !isEditing && !showingRenameAlert {
                    ScrollTimeView(timeOffset: $timeOffset, showButtons: $showScrollTimeButtons, worldClocks: $worldClocks)
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                        .transition(.blurReplace)
                }
            }
            .animation(.spring, value: isEditing)
            .animation(.spring, value: showingRenameAlert)
            .animation(.spring, value: customLocalName)
            .animation(.spring, value: worldClocks)
            .environment(\.editMode, .constant(isEditing ? .active : .inactive))
            
            .navigationTitle("Touch Time")
            .navigationBarTitleDisplayMode(.inline)
            
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isEditing {
                        Button(action: {
                            withAnimation(.spring()) {
                                isEditing.toggle()
                            }
                        }) {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .animation(.spring(), value: isEditing)
                        }
                    } else {
                        Menu {
                            Button(action: {
                                withAnimation(.spring()) {
                                    isEditing.toggle()
                                }
                            }) {
                                Label("Edit List", systemImage: "list.bullet")
                            }
                            
                            Divider()
                            
                            Button(action: {
                                showShareSheet = true
                            }) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .animation(.spring(), value: isEditing)
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
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
        
        }
        
    }
    
    // Move function
    func moveClocks(from source: IndexSet, to destination: Int) {
        worldClocks.move(fromOffsets: source, toOffset: destination)
        saveWorldClocks()
    }
    
    // Save world clocks to UserDefaults
    func saveWorldClocks() {
        if let encoded = try? JSONEncoder().encode(worldClocks) {
            UserDefaults.standard.set(encoded, forKey: worldClocksKey)
        }
    }
    
}
