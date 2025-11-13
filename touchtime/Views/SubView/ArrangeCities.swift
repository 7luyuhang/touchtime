//
//  ArrangeListView.swift
//  touchtime
//
//  Created on 28/10/2025.
//

import SwiftUI

struct ArrangeListView: View {
    @Binding var worldClocks: [WorldClock]
    @Binding var showSheet: Bool
    @State private var editMode: EditMode = .active
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showLocalTime") private var showLocalTimeInHome = true
    @AppStorage("customLocalName") private var customLocalName = ""
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    
    let currentDate: Date
    let timeOffset: TimeInterval
    
    // Collection management
    @State private var collections: [CityCollection] = []
    @State private var showAddCollectionAlert = false
    @State private var newCollectionName = ""
    @State private var showCopyToCitiesMenu: WorldClock?
    @State private var expandedCollections: Set<UUID> = []
    @State private var showRenameCollectionAlert = false
    @State private var collectionToRename: CityCollection?
    @State private var renameCollectionName = ""
    
    // UserDefaults key for storing world clocks
    private let worldClocksKey = "savedWorldClocks"
    private let collectionsKey = "savedCityCollections"
    
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
    
    // Format time for display
    func formatTime(for timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        if use24HourFormat {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "h:mm a"
            formatter.amSymbol = "am"
            formatter.pmSymbol = "pm"
        }
        
        let adjustedDate = currentDate.addingTimeInterval(timeOffset)
        return formatter.string(from: adjustedDate).lowercased()
    }
    
    // Save world clocks to UserDefaults
    func saveWorldClocks() {
        if let encoded = try? JSONEncoder().encode(worldClocks) {
            UserDefaults.standard.set(encoded, forKey: worldClocksKey)
        }
    }
    
    // Save collections to UserDefaults
    func saveCollections() {
        if let encoded = try? JSONEncoder().encode(collections) {
            UserDefaults.standard.set(encoded, forKey: collectionsKey)
        }
    }
    
    // Load collections from UserDefaults
    func loadCollections() {
        if let data = UserDefaults.standard.data(forKey: collectionsKey),
           let decoded = try? JSONDecoder().decode([CityCollection].self, from: data) {
            collections = decoded
        }
    }
    
    // Add new collection
    func addCollection() {
        guard !newCollectionName.isEmpty else { return }
        let newCollection = CityCollection(name: newCollectionName)
        collections.append(newCollection)
        saveCollections()
        newCollectionName = ""
        
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    // Check if city is in collection
    func isCityInCollection(city: WorldClock, collectionId: UUID) -> Bool {
        if let collection = collections.first(where: { $0.id == collectionId }) {
            return collection.cities.contains(where: { $0.cityName == city.cityName && $0.timeZoneIdentifier == city.timeZoneIdentifier })
        }
        return false
    }
    
    // Copy city to collection
    func copyCityToCollection(city: WorldClock, collectionId: UUID) {
        if let index = collections.firstIndex(where: { $0.id == collectionId }) {
            // Check if city already exists in collection
            if !collections[index].cities.contains(where: { $0.cityName == city.cityName && $0.timeZoneIdentifier == city.timeZoneIdentifier }) {
                collections[index].cities.append(city)
                saveCollections()
                
                if hapticEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }
        }
    }
    
    // Remove city from collection
    func removeCityFromCollection(city: WorldClock, collectionId: UUID) {
        if let collectionIndex = collections.firstIndex(where: { $0.id == collectionId }),
           let cityIndex = collections[collectionIndex].cities.firstIndex(where: { $0.id == city.id }) {
            collections[collectionIndex].cities.remove(at: cityIndex)
            saveCollections()
            
            if hapticEnabled {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        }
    }
    
    // Delete collection
    func deleteCollection(at offsets: IndexSet) {
        collections.remove(atOffsets: offsets)
        saveCollections()
        
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    // Delete single collection
    func deleteSingleCollection(collection: CityCollection) {
        if let index = collections.firstIndex(where: { $0.id == collection.id }) {
            collections.remove(at: index)
            saveCollections()
            
            if hapticEnabled {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        }
    }
    
    // Rename collection
    func renameCollection() {
        guard let collection = collectionToRename,
              !renameCollectionName.isEmpty else { return }
        
        if let index = collections.firstIndex(where: { $0.id == collection.id }) {
            collections[index].name = renameCollectionName
            saveCollections()
            
            if hapticEnabled {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        }
        
        renameCollectionName = ""
        collectionToRename = nil
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Collections Section
                if !collections.isEmpty {
                    Section {
                        ForEach(collections) { collection in
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { expandedCollections.contains(collection.id) },
                                    set: { isExpanding in
                                        if isExpanding {
                                            expandedCollections.insert(collection.id)
                                        } else {
                                            expandedCollections.remove(collection.id)
                                        }
                                    }
                                )
                            ) {
                                // Cities in Collection
                                ForEach(collection.cities) { city in
                                    HStack {
                                        Text(city.cityName)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                        
                                        Spacer()
                                        
                                        if let timeZone = TimeZone(identifier: city.timeZoneIdentifier) {
                                            Text(formatTime(for: timeZone))
                                                .monospacedDigit()
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .onDelete { offsets in
                                    for index in offsets {
                                        let city = collection.cities[index]
                                        removeCityFromCollection(city: city, collectionId: collection.id)
                                    }
                                }
                                .onMove { source, destination in
                                    if let index = collections.firstIndex(where: { $0.id == collection.id }) {
                                        collections[index].cities.move(fromOffsets: source, toOffset: destination)
                                        saveCollections()
                                        
                                        if hapticEnabled {
                                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                            impactFeedback.impactOccurred()
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(collection.name)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(collection.cities.count)")
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                                .contextMenu {
                                    Button(role:.confirm) {
                                        collectionToRename = collection
                                        renameCollectionName = collection.name
                                        showRenameCollectionAlert = true
                                    } label: {
                                        Label("Rename", systemImage: "pencil.tip.crop.circle")
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        deleteSingleCollection(collection: collection)
                                    } label: {
                                        Label("Delete", systemImage: "xmark.circle")
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Collections")
                    } footer : {
                        Text("Press and hold a city to add it to the collection.")
                    }
                }
                
                // City Time Section
                Section {
                    // Local Time Section
                    if showLocalTimeInHome {
                        Section {
                            HStack {
                                // City name
                                Text(customLocalName.isEmpty ? localCityName : customLocalName)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                
                                Spacer()
                                
                                // Time
                                HStack(spacing: 6) {
                                    Image(systemName: "location.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    Text(formatTime(for: TimeZone.current))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .deleteDisabled(true)
                            .moveDisabled(true)
                        }
                    }
                    
                    // World Clocks Section (All Cities)
                    ForEach(worldClocks) { clock in
                        HStack {
                            // City name
                            Text(clock.cityName)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            Spacer()
                            
                            // Time
                            if let timeZone = TimeZone(identifier: clock.timeZoneIdentifier) {
                                Text(formatTime(for: timeZone))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contextMenu {
                            if !collections.isEmpty {
                                Menu("Add to Collection") {
                                    ForEach(collections) { collection in
                                        Button {
                                            copyCityToCollection(city: clock, collectionId: collection.id)
                                        } label: {
                                            Label(
                                                collection.name,
                                                systemImage: isCityInCollection(city: clock, collectionId: collection.id) ? "checkmark.circle.fill" : ""
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .onMove { source, destination in
                        worldClocks.move(fromOffsets: source, toOffset: destination)
                        saveWorldClocks()
                        
                        // Provide haptic feedback if enabled
                        if hapticEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.prepare()
                            impactFeedback.impactOccurred()
                        }
                    }
                } header: {
                    Text("All Cities")
                }
            }
            .scrollIndicators(.hidden)
            .listStyle(.insetGrouped)
            .environment(\.editMode, $editMode)
            .navigationTitle("Arrange")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadCollections()
            }
            
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAddCollectionAlert = true
                        if hapticEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        if hapticEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        showSheet = false
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.white)
                            .fontWeight(.semibold)
                    }
                }
            }
            .alert("New Collection", isPresented: $showAddCollectionAlert) {
                TextField("Collection Name", text: $newCollectionName)
                    .autocapitalization(.words)
                Button("Cancel", role: .cancel) {
                    newCollectionName = ""
                }
                Button("Add") {
                    addCollection()
                }
                .disabled(newCollectionName.isEmpty)
            } message: {
                Text("Enter a name for your new collection")
            }
            .alert("Rename Collection", isPresented: $showRenameCollectionAlert) {
                TextField("Collection Name", text: $renameCollectionName)
                    .autocapitalization(.words)
                Button("Cancel", role: .cancel) {
                    renameCollectionName = ""
                    collectionToRename = nil
                }
                Button("Rename") {
                    renameCollection()
                }
                .disabled(renameCollectionName.isEmpty)
            } message: {
                Text("Enter a new name for your collection")
            }
        }
    }
}
