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
        let cityName: String
        if components.count >= 2 {
            cityName = components.last!.replacingOccurrences(of: "_", with: " ")
        } else {
            cityName = identifier
        }
        // Return localized city name
        return String(localized: String.LocalizationValue(cityName))
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
    
    // Sort cities from West to East (by longitude, smallest to largest)
    func sortCitiesWestToEast() {
        worldClocks.sort { clock1, clock2 in
            let coords1 = TimeZoneCoordinates.getCoordinate(for: clock1.timeZoneIdentifier)
            let coords2 = TimeZoneCoordinates.getCoordinate(for: clock2.timeZoneIdentifier)
            return (coords1?.longitude ?? 0) < (coords2?.longitude ?? 0)
        }
        saveWorldClocks()
        
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    // Sort cities from East to West (by longitude, largest to smallest)
    func sortCitiesEastToWest() {
        worldClocks.sort { clock1, clock2 in
            let coords1 = TimeZoneCoordinates.getCoordinate(for: clock1.timeZoneIdentifier)
            let coords2 = TimeZoneCoordinates.getCoordinate(for: clock2.timeZoneIdentifier)
            return (coords1?.longitude ?? 0) > (coords2?.longitude ?? 0)
        }
        saveWorldClocks()
        
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Collections Section
                Section {
                    if collections.isEmpty {
                        // Empty state - prompt to create collection
                        Button {
                            showAddCollectionAlert = true
                            if hapticEnabled {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                                
                                VStack (alignment: .leading) {
                                    Text("Create Collection")
                                        .font(.headline)
                                    Text("Organize your time in collection")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .blendMode(.plusLighter)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(Color.black.opacity(0.20))
                                .glassEffect(.clear.interactive(),
                                             in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                        )
                    } else {
                        ForEach(collections) { collection in
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { 
                                        // Disable expansion if collection has no cities
                                        guard !collection.cities.isEmpty else { return false }
                                        return expandedCollections.contains(collection.id) 
                                    },
                                    set: { isExpanding in
                                        // Prevent expansion if collection has no cities
                                        guard !collection.cities.isEmpty else { return }
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
                                        Text(city.localizedCityName)
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
                                        Label(String(localized: "Rename"), systemImage: "pencil.tip.crop.circle")
                                    }
                                    Button(role: .destructive) {
                                        deleteSingleCollection(collection: collection)
                                    } label: {
                                        Label(String(localized: "Delete"), systemImage: "xmark.circle")
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    if !collections.isEmpty {
                        Text("Collections")
                    }
                }
                
                // City Time Section
                Section {
                    // Local Time Section
                    if showLocalTimeInHome {
                        Section {
                            HStack {
                                // City name
                                Text(String(localized: "Local"))
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
                    if !showLocalTimeInHome && worldClocks.isEmpty {
                        HStack {
                            Spacer()
                            Text(String(localized: "No Cities"))
                                .foregroundStyle(.secondary)
                            Spacer()}
                    }
                    
                    ForEach(worldClocks) { clock in
                        HStack(spacing: 12) {
                            // Plus icon for collection selection
                            if !collections.isEmpty {
                                Menu {
                                    Section(String(localized: "Add to Collection")) {
                                        ForEach(collections) { collection in
                                            Button {
                                                if isCityInCollection(city: clock, collectionId: collection.id) {
                                                    removeCityFromCollection(city: clock, collectionId: collection.id)
                                                } else {
                                                    copyCityToCollection(city: clock, collectionId: collection.id)
                                                }
                                            } label: {
                                                if isCityInCollection(city: clock, collectionId: collection.id) {
                                                    Label(collection.name, systemImage: "checkmark.circle")
                                                } else {
                                                    Text(collection.name)
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .font(.title3)
                                }
                                .tint(.secondary)
                            }
                            
                            // City name
                            Text(clock.localizedCityName)
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
                    }
                    .onMove { source, destination in
                        worldClocks.move(fromOffsets: source, toOffset: destination)
                        saveWorldClocks()
                        if hapticEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.prepare()
                            impactFeedback.impactOccurred()
                        }
                    }
                } header: {
                    HStack {
                        Text("All Cities")
                        Spacer()
                        Menu {
                            Section(String(localized: "Sort by")) {
                                Button {
                                    sortCitiesEastToWest()
                                } label: {
                                    Label(String(localized: "East to West"), systemImage: "arrow.left")
                                }

                                Button {
                                    sortCitiesWestToEast()
                                } label: {
                                    Label(String(localized: "West to East"), systemImage: "arrow.right")
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.subheadline.weight(.medium))
                                .tint(.primary)
                        }
                    }
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
                    }
                }
            }
            .alert(String(localized: "New Collection"), isPresented: $showAddCollectionAlert) {
                TextField(String(localized: "Collection Name"), text: $newCollectionName)
                Button(String(localized: "Cancel"), role: .cancel) {
                    newCollectionName = ""
                }
                Button(String(localized: "Add")) {
                    addCollection()
                }
                .disabled(newCollectionName.isEmpty)
            } message: {
                Text(String(localized: "Enter a name for your new collection"))
            }
            .alert(String(localized: "Rename Collection"), isPresented: $showRenameCollectionAlert) {
                TextField(String(localized: "Collection Name"), text: $renameCollectionName)
                Button(String(localized: "Cancel"), role: .cancel) {
                    renameCollectionName = ""
                    collectionToRename = nil
                }
                Button(String(localized: "Rename")) {
                    renameCollection()
                }
                .disabled(renameCollectionName.isEmpty)
            } message: {
                Text(String(localized: "Enter a new name for your collection"))
            }
        }
    }
}
