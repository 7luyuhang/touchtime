//
//  SearchTabView.swift
//  touchtime
//
//  Created on 26/09/2025.
//

import SwiftUI
import UIKit
import Combine

struct SearchTabView: View {
    @Binding var worldClocks: [WorldClock]
    @State private var isShowingPicker = false
    
    var body: some View {
        // Directly embed TimeZonePickerView for the search tab
        TimeZonePickerViewWrapper(worldClocks: $worldClocks)
    }
}

// Precomputed timezone data structure
struct TimeZoneData: Identifiable {
    let id: String // identifier
    let cityName: String
    let region: String
    let identifier: String
    let localizedCityName: String
    let localizedRegion: String
    let groupKey: String
}

struct CollectionMenuItem: Identifiable {
    let id: UUID
    let name: String
    let isIncluded: Bool
}

// Wrapper to adapt TimeZonePickerView for tab usage
struct TimeZonePickerViewWrapper: View {
    @Binding var worldClocks: [WorldClock]
    @State private var searchText = ""
    @State private var currentDate = Date()
    @State private var collections: [CityCollection] = []
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("showWhatsNewLongpressCity") private var showWhatsNewLongpressCity = true
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Precomputed timezone data
    @State private var precomputedTimeZones: [TimeZoneData] = []
    @State private var groupedTimeZones: [String: [TimeZoneData]] = [:]
    @State private var sortedKeys: [String] = []
    
    // Check if current language is Chinese
    private let isChineseLanguage: Bool = {
        let languageCode = Locale.current.language.languageCode?.identifier ?? ""
        return languageCode.hasPrefix("zh")
    }()
    
    // Get pinyin first letter for Chinese text
    private func getPinyinFirstLetter(_ text: String) -> String {
        // Convert Chinese to pinyin
        if let pinyin = text.applyingTransform(.toLatin, reverse: false)?
            .applyingTransform(.stripDiacritics, reverse: false) {
            let firstChar = pinyin.prefix(1).uppercased()
            // Ensure it's a letter, otherwise categorize as "#"
            if firstChar.rangeOfCharacter(from: .letters) != nil {
                return firstChar
            }
        }
        return "#"
    }
    
    // Precompute all timezone data
    private func precomputeTimeZones() {
        let isChinese = isChineseLanguage
        
        let timeZones = TimeZone.knownTimeZoneIdentifiers.compactMap { identifier -> TimeZoneData? in
            // Extract city name from timezone identifier
            let components = identifier.split(separator: "/")
            guard let lastComponent = components.last else { return nil }
            
            // Replace underscore with space for readability
            let cityName = lastComponent.replacingOccurrences(of: "_", with: " ")
            
            // English region for search matching, localized region for display
            let (region, localizedRegion) = regionNames(for: identifier)
            
            // Get localized city name
            let localizedCityName = String(localized: String.LocalizationValue(cityName))
            
            // Calculate group key
            let groupKey: String
            if isChinese {
                groupKey = getPinyinFirstLetter(localizedCityName)
            } else {
                let firstChar = cityName.prefix(1).uppercased()
                if firstChar.rangeOfCharacter(from: .letters) != nil {
                    groupKey = firstChar
                } else {
                    groupKey = "#"
                }
            }
            
            return TimeZoneData(
                id: identifier,
                cityName: cityName,
                region: region,
                identifier: identifier,
                localizedCityName: localizedCityName,
                localizedRegion: localizedRegion,
                groupKey: groupKey
            )
        }
        .sorted { $0.cityName < $1.cityName }
        
        // Group by key
        let grouped = Dictionary(grouping: timeZones) { $0.groupKey }
        
        // Sort keys
        let sorted = Self.sortedGroupKeys(grouped.keys)
        
        precomputedTimeZones = timeZones
        groupedTimeZones = grouped
        sortedKeys = sorted
    }
    
    // English locale for search matching regardless of device language
    private static let englishLocale = Locale(identifier: "en_US")
    
    // Get country name for timezone: English (for search) + localized (for display).
    // Country codes come from the IANA table; display names from CLDR via Locale,
    // so every zone gets a real country name in every language for free.
    private func regionNames(for identifier: String) -> (english: String, localized: String) {
        guard let code = TimeZoneCountryCodes.countryCode(for: identifier) else {
            // Zones without a country (UTC, GMT)
            return ("Standard Time", String(localized: "Standard Time"))
        }
        
        let english = Self.englishLocale.localizedString(forRegionCode: code) ?? code
        let localized = Locale.current.localizedString(forRegionCode: code) ?? english
        return (english, localized)
    }
    
    // Filter search results using precomputed data
    private var filteredGroupedTimeZones: [String: [TimeZoneData]] {
        if searchText.isEmpty {
            return groupedTimeZones
        } else {
            let filtered = precomputedTimeZones.filter {
                $0.cityName.localizedCaseInsensitiveContains(searchText) ||
                $0.region.localizedCaseInsensitiveContains(searchText) ||
                $0.identifier.localizedCaseInsensitiveContains(searchText) ||
                $0.localizedCityName.localizedCaseInsensitiveContains(searchText) ||
                $0.localizedRegion.localizedCaseInsensitiveContains(searchText)
            }
            return Dictionary(grouping: filtered) { $0.groupKey }
        }
    }
    
    // Sort group keys alphabetically, with "#" last
    private static func sortedGroupKeys(_ keys: some Sequence<String>) -> [String] {
        keys.sorted { key1, key2 in
            if key1 == "#" { return false }
            if key2 == "#" { return true }
            return key1 < key2
        }
    }
    
    var body: some View {
        // Compute filtered data once per body evaluation:
        // the filter walks all timezones, so it must not run per section
        let displayedGroups = filteredGroupedTimeZones
        let displayedKeys = searchText.isEmpty ? sortedKeys : Self.sortedGroupKeys(displayedGroups.keys)
        let selectedIdentifiers = Set(worldClocks.map(\.timeZoneIdentifier))
        
        NavigationStack {
            Group {
                if displayedGroups.isEmpty {
                    // Empty state when no search results
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        // Dots world map with every added city highlighted and
                        // the solar terminator curve (hidden while searching)
                        if searchText.isEmpty {
                            Section {
                                DotsWorldMapView(
                                    timeZoneIdentifiers: worldClocks.map(\.timeZoneIdentifier),
                                    date: currentDate
                                )
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                            }
                        }
                        
                        // What's New Section
                        if showWhatsNewLongpressCity {
                            Section {
                                HStack(spacing: 16) {
                                    Image(systemName: "hand.tap.fill")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                        .blendMode(.plusLighter)
                                        .frame(width: 24, height: 24)
                                    
                                    Text(String(localized: "Press and hold to view more about the city"))
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
                                        .glassEffect(.regular.interactive(),
                                                     in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        showWhatsNewLongpressCity = false
                                    }
                                    if hapticEnabled {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                                        impactFeedback.impactOccurred()
                                    }
                                }
                            }
                        }
                        
                        ForEach(displayedKeys, id: \.self) { key in
                            Section(header: Text(key)) {
                                ForEach(displayedGroups[key] ?? [], id: \.id) { timeZoneData in
                                    TimeZoneCellView(
                                        timeZoneData: timeZoneData,
                                        isSelected: selectedIdentifiers.contains(timeZoneData.identifier),
                                        currentDate: currentDate,
                                        use24HourFormat: use24HourFormat,
                                        collectionMenuItems: collectionMenuItems(for: timeZoneData.identifier),
                                        onToggle: {
                                            toggleClock(cityName: timeZoneData.cityName, identifier: timeZoneData.identifier)
                                        },
                                        onToggleCollectionMembership: { collectionId in
                                            toggleCityInCollection(
                                                cityName: timeZoneData.cityName,
                                                identifier: timeZoneData.identifier,
                                                collectionId: collectionId
                                            )
                                        }
                                    )
                                }
                            }
                            .sectionIndexLabel(searchText.isEmpty ? key : nil)
                        }
                        
                        // Earth image at the bottom (only show when not searching)
                        if searchText.isEmpty {
                            Section {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 16) {
                                        EarthImageView()
                                        Text(String(format: String(localized: "Total %d Cities"), precomputedTimeZones.count))
                                            .font(.system(.caption, design: .monospaced).weight(.medium))
                                            .foregroundStyle(.secondary)
                                            .textCase(.uppercase)
                                    }
                                    Spacer()
                                }
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0))
                            }
                        }
                    }
//                    .listStyle(.plain)
                    .listSectionIndexVisibility(searchText.isEmpty ? .visible : .hidden)
                    .safeAreaPadding(.bottom, searchText.isEmpty ? 0 : 48)
                    .tint(.primary) // A-Z Colour
                }
            }
            .searchable(text: $searchText, prompt: String(localized: "Cities & Countries"))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("Cities")
                            .font(.headline)
                        
                        if !worldClocks.isEmpty {
                            Text(String(format: String(localized: "%d added"), worldClocks.count))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                    }
                }
            }
        }
        .onAppear {
            currentDate = Date()
            if precomputedTimeZones.isEmpty {
                precomputeTimeZones()
            }
            loadCollections()
        }
        .onReceive(timer) { now in
            let calendar = Calendar.current
            if calendar.component(.minute, from: now) != calendar.component(.minute, from: currentDate) {
                currentDate = now
            }
        }
    }
    
    // UserDefaults key for storing world clocks
    private let worldClocksKey = "savedWorldClocks"
    
    private func loadCollections() {
        collections = CollectionsStore.load()
    }
    
    private func collectionMenuItems(for identifier: String) -> [CollectionMenuItem] {
        collections.map { collection in
            CollectionMenuItem(
                id: collection.id,
                name: collection.name,
                isIncluded: collection.cities.contains(where: { $0.timeZoneIdentifier == identifier })
            )
        }
    }
    
    private func ensureClockExists(cityName: String, identifier: String) -> WorldClock {
        if let existing = worldClocks.first(where: { $0.timeZoneIdentifier == identifier }) {
            return existing
        }
        
        let newClock = WorldClock(cityName: cityName, timeZoneIdentifier: identifier)
        worldClocks.append(newClock)
        saveWorldClocks()
        return newClock
    }
    
    private func toggleCityInCollection(cityName: String, identifier: String, collectionId: UUID) {
        var allCollections = CollectionsStore.load()
        
        guard let collectionIndex = allCollections.firstIndex(where: { $0.id == collectionId }) else { return }
        
        if let cityIndex = allCollections[collectionIndex].cities.firstIndex(where: { $0.timeZoneIdentifier == identifier }) {
            allCollections[collectionIndex].cities.remove(at: cityIndex)
        } else {
            let clock = ensureClockExists(cityName: cityName, identifier: identifier)
            allCollections[collectionIndex].cities.append(clock)
        }
        
        CollectionsStore.save(allCollections)
        collections = allCollections
        
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
    }
    
    // Toggle clock selection
    func toggleClock(cityName: String, identifier: String) {
        // Provide haptic feedback if enabled
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
        
        withAnimation(.spring(duration: 0.25)) {
            // Check if the same timezone already exists
            if let index = worldClocks.firstIndex(where: { $0.timeZoneIdentifier == identifier }) {
                // If exists, remove it
                let removedClock = worldClocks.remove(at: index)
                CollectionsStore.removeCity(withId: removedClock.id)
                saveWorldClocks()
                loadCollections()
            } else {
                // If doesn't exist, add it
                let newClock = WorldClock(cityName: cityName, timeZoneIdentifier: identifier)
                worldClocks.append(newClock)
                saveWorldClocks()
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

// Individual cell view driven by the parent timestamp
struct TimeZoneCellView: View {
    let timeZoneData: TimeZoneData
    let isSelected: Bool
    let currentDate: Date
    let use24HourFormat: Bool
    let collectionMenuItems: [CollectionMenuItem]
    let onToggle: () -> Void
    let onToggleCollectionMembership: (UUID) -> Void
    @AppStorage("additionalTimeDisplay") private var additionalTimeDisplay = "None"
    @AppStorage("dateStyle") private var dateStyle = "Relative"
    @AppStorage("showSkyDot") private var showSkyDot = true
    private static let formatterCache: NSCache<NSString, DateFormatter> = {
        let cache = NSCache<NSString, DateFormatter>()
        cache.countLimit = 50
        return cache
    }()
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                HStack (spacing: 16) {
                    // Show checkmark if already added
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3.weight(.bold))
                            .frame(width: 24)
                            .transition(.identity)
                            .id("checkmark-\(timeZoneData.identifier)")
                    } else {
                        Image(systemName: "circle")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                            .transition(.identity)
                            .id("circle-\(timeZoneData.identifier)")
                    }
                    
                    VStack(alignment: .leading) {
                        Text(timeZoneData.localizedCityName)
                        
                        Text(timeZoneData.localizedRegion)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
                
                Spacer()
                
                // Show current time preview
                HStack(spacing: 8) {
                    if let tz = TimeZone(identifier: timeZoneData.identifier) {
                        VStack(alignment: .trailing) {
                            Text(currentTime(for: tz))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            
                            if !listAdditionalText.isEmpty || additionalTimeDisplay == "UTC" {
                                Text(listAdditionalText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if isSelected {
                Button(role: .destructive, action: onToggle) {
                    Label(String(localized: "Delete"), systemImage: "xmark.circle")
                        .tint(.red)
                }
            } else {
                Button(action: onToggle) {
                    Label(String(localized: "Add"), systemImage: "plus.circle")
                }
            }
            
            if !collectionMenuItems.isEmpty {
                Divider()
                
                Menu {
                    ForEach(collectionMenuItems) { collection in
                        Button {
                            onToggleCollectionMembership(collection.id)
                        } label: {
                            if collection.isIncluded {
                                Label(collection.name, systemImage: "checkmark.circle.fill")
                            } else {
                                Text(collection.name)
                            }
                        }
                    }
                } label: {
                    Label(String(localized: "Add to Collection"), systemImage: "folder.badge.plus")
                }
            }
        } preview: {
            TimeZoneSectionPreviewCard(
                cityName: timeZoneData.localizedCityName,
                timeString: currentTime(for: TimeZone(identifier: timeZoneData.identifier) ?? .current),
                dateString: previewDateString,
                additionalText: previewAdditionalText,
                showAdditionalText: additionalTimeDisplay != "None",
                showSkyDotBadge: showSkyDot && additionalTimeDisplay == "None",
                showSkyBackground: showSkyDot,
                timeZoneIdentifier: timeZoneData.identifier,
                currentDate: currentDate
            )
        }
    }

    private static func formatter(for timeZone: TimeZone, use24HourFormat: Bool) -> DateFormatter {
        let key = "\(timeZone.identifier)_\(use24HourFormat)" as NSString
        if let cached = formatterCache.object(forKey: key) {
            return cached
        }

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
        formatterCache.setObject(formatter, forKey: key)
        return formatter
    }
    
    // Get current time for timezone (for preview)
    private func currentTime(for timeZone: TimeZone) -> String {
        let formatter = Self.formatter(for: timeZone, use24HourFormat: use24HourFormat)
        return formatter.string(from: currentDate)
    }
    
    private var previewDateString: String {
        let timeZone = TimeZone(identifier: timeZoneData.identifier) ?? .current
        return currentDate.formattedDate(
            style: dateStyle,
            timeZone: timeZone,
            relativeTo: currentDate
        )
    }
    
    private var listAdditionalText: String {
        let clock = WorldClock(cityName: timeZoneData.cityName, timeZoneIdentifier: timeZoneData.identifier)
        return additionalText(for: clock)
    }
    
    private var previewAdditionalText: String {
        let previewClock = WorldClock(cityName: timeZoneData.cityName, timeZoneIdentifier: timeZoneData.identifier)
        return additionalText(for: previewClock)
    }
    
    private func additionalText(for clock: WorldClock) -> String {
        switch additionalTimeDisplay {
        case "Time Difference":
            return clock.timeDifference
        case "UTC":
            return clock.utcOffset
        default:
            return ""
        }
    }
}

private struct TimeZoneSectionPreviewCard: View {
    let cityName: String
    let timeString: String
    let dateString: String
    let additionalText: String
    let showAdditionalText: Bool
    let showSkyDotBadge: Bool
    let showSkyBackground: Bool
    let timeZoneIdentifier: String
    let currentDate: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if showAdditionalText {
                    if !additionalText.isEmpty {
                        Text(additionalText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .blendMode(.plusLighter)
                    }
                } else if showSkyDotBadge {
                    SkyDotView(
                        date: currentDate,
                        timeZoneIdentifier: timeZoneIdentifier,
                        weatherCondition: nil
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                            .blendMode(.plusLighter)
                    )
                }
                
                Spacer()
                
                Text(dateString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
            }
            
            HStack(alignment: .lastTextBaseline) {
                Text(cityName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                Text(timeString)
                    .font(.system(size: 36))
                    .fontWeight(.light)
                    .fontDesign(.rounded)
                    .monospacedDigit()
            }
            .padding(.bottom, -4)
        }
        .frame(width: 320)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            if showSkyBackground {
                SkyBackgroundView(
                    date: currentDate,
                    timeZoneIdentifier: timeZoneIdentifier,
                    weatherCondition: nil
                )
            } else {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color(UIColor.secondarySystemBackground))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(8)
    }
}
