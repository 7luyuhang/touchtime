//
//  HomeView.swift
//  touchtime
//
//  Created on 23/09/2025.
//

import SwiftUI
import Combine

struct HomeView: View {
    @State private var worldClocks: [WorldClock] = []
    @State private var currentDate = Date()
    @State private var showingAddClock = false
    @State private var timeOffset: TimeInterval = 0
    @State private var showingRenameAlert = false
    @State private var renamingClockId: UUID? = nil
    @State private var renamingLocalTime = false
    @State private var newClockName = ""
    @State private var originalClockName = ""
    
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showTimeDifference") private var showTimeDifference = true
    @AppStorage("showLocalTime") private var showLocalTime = true
    @AppStorage("customLocalName") private var customLocalName = ""
    
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
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // Main List Content
                List {
                    // Local Time Section
                    if showLocalTime {
                        Section {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "location.fill")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Text(customLocalName.isEmpty ? localCityName : customLocalName)
                                            .font(.headline)
                                    }
                                    Text("Local")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text({
                                        let formatter = DateFormatter()
                                        formatter.timeZone = TimeZone.current
                                        formatter.locale = Locale(identifier: "en_US_POSIX")
                                        if use24HourFormat {
                                            formatter.dateFormat = "HH:mm"
                                        } else {
                                            formatter.dateFormat = "h:mm a"
                                            formatter.amSymbol = "am"
                                            formatter.pmSymbol = "pm"
                                        }
                                        let adjustedDate = Date().addingTimeInterval(timeOffset)
                                        return formatter.string(from: adjustedDate)
                                    }())
                                    .font(.title)
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                                    
                                    Text({
                                        let formatter = DateFormatter()
                                        formatter.timeZone = TimeZone.current
                                        formatter.locale = Locale(identifier: "en_US_POSIX")
                                        formatter.dateStyle = .medium
                                        formatter.timeStyle = .none
                                        let adjustedDate = Date().addingTimeInterval(timeOffset)
                                        return formatter.string(from: adjustedDate)
                                    }())
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .contentTransition(.numericText())
                                }
                            }
                            .contextMenu {
                                Button(action: {
                                    renamingLocalTime = true
                                    originalClockName = localCityName
                                    newClockName = customLocalName.isEmpty ? localCityName : customLocalName
                                    showingRenameAlert = true
                                }) {
                                    Label("Rename", systemImage: "pencil")
                                }
                            }
                        }
                    }
                    
                    ForEach(worldClocks) { clock in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(clock.cityName)
                                    .font(.headline)
                                if showTimeDifference && !clock.timeDifference.isEmpty {
                                    Text(clock.timeDifference)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(clock.currentTime(use24Hour: use24HourFormat, offset: timeOffset))
                                .font(.title)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            
                            Text(clock.currentDate(offset: timeOffset))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                        }
                        // Delete Time Row
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                if let index = worldClocks.firstIndex(where: { $0.id == clock.id }) {
                                    worldClocks.remove(at: index)
                                    saveWorldClocks()
                                }
                            } label: {
                                Label("", systemImage: "trash")
                            }
                        }
                        .contextMenu {
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
                                Label("Rename", systemImage: "pencil")
                            }
                            
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
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onMove(perform: moveClocks)
                    
                    
                }
                
                // Scroll Time View
                ScrollTimeView(timeOffset: $timeOffset)
                    .padding(.horizontal)
                    .padding(.bottom, 16)

            }
            .navigationTitle("Touch Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddClock = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAddClock) {
                TimeZonePickerView(worldClocks: $worldClocks)
                    .onDisappear {
                        saveWorldClocks()
                    }
            }
            .onReceive(timer) { _ in
                currentDate = Date()
            }
            .onAppear {
                loadWorldClocks()
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
                Text("Customize the name of this location")
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
    
    // Load world clocks from UserDefaults
    func loadWorldClocks() {
        if let data = UserDefaults.standard.data(forKey: worldClocksKey),
           let decoded = try? JSONDecoder().decode([WorldClock].self, from: data) {
            worldClocks = decoded
        } else {
            // 如果没有保存的数据，使用默认时钟
            worldClocks = WorldClockData.defaultClocks
            saveWorldClocks() // 保存默认数据
        }
    }
}

#Preview {
    HomeView()
}
