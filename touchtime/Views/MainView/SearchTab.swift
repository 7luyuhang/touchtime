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

// Wrapper to adapt TimeZonePickerView for tab usage
struct TimeZonePickerViewWrapper: View {
    @Binding var worldClocks: [WorldClock]
    @State private var searchText = ""
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    
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
            // Extract city name and region info from timezone identifier
            let components = identifier.split(separator: "/")
            let cityName: String
            let region: String
            
            if components.count >= 2 {
                // Replace underscore with space for readability
                cityName = components.last!
                    .replacingOccurrences(of: "_", with: " ")
                region = getRegionForTimeZone(identifier: identifier)
            } else if components.count == 1 {
                // Handle timezones without slashes (like UTC, GMT)
                cityName = String(components[0])
                region = "Standard Time"
            } else {
                return nil
            }
            
            // Get localized names
            let localizedCityName = String(localized: String.LocalizationValue(cityName))
            let localizedRegion = String(localized: String.LocalizationValue(region))
            
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
        let sorted = grouped.keys.sorted { key1, key2 in
            // "#" symbol comes last
            if key1 == "#" { return false }
            if key2 == "#" { return true }
            return key1 < key2
        }
        
        precomputedTimeZones = timeZones
        groupedTimeZones = grouped
        sortedKeys = sorted
    }
    
    // Get country/region name for timezone
    private func getRegionForTimeZone(identifier: String) -> String {
        let components = identifier.split(separator: "/")
        
        // Handle timezones with country info (e.g. America/Argentina/Buenos_Aires)
        if components.count >= 3 {
            let country = String(components[1]).replacingOccurrences(of: "_", with: " ")
            
            // Special handling for some country names
            switch country {
            case "Indiana", "Kentucky", "North Dakota": return "United States"
            default: return country
            }
        }
        
        // Map country directly based on timezone identifier
        switch identifier {
        // United States
        case let id where id.starts(with: "America/") && 
            ["New_York", "Chicago", "Denver", "Los_Angeles", "Phoenix", "Anchorage", "Honolulu", "Detroit", "Indianapolis"].contains(where: { id.contains($0) }):
            return "United States"
            
        // Canada
        case let id where id.starts(with: "America/") &&
            ["Toronto", "Vancouver", "Montreal", "Edmonton", "Winnipeg", "Halifax", "St_Johns", "Regina"].contains(where: { id.contains($0) }):
            return "Canada"
            
        // China
        case "Asia/Shanghai", "Asia/Urumqi", "Asia/Harbin", "Asia/Chongqing":
            return "China"
            
        // Japan
        case "Asia/Tokyo":
            return "Japan"
            
        // South Korea
        case "Asia/Seoul":
            return "South Korea"
            
        // India
        case "Asia/Kolkata", "Asia/Calcutta":
            return "India"
            
        // Australia
        case let id where id.starts(with: "Australia/"):
            return "Australia"
            
        // United Kingdom
        case "Europe/London", "Europe/Belfast":
            return "United Kingdom"
            
        // France
        case "Europe/Paris":
            return "France"
            
        // Germany
        case "Europe/Berlin":
            return "Germany"
            
        // Russia
        case let id where id.starts(with: "Europe/") &&
            ["Moscow", "Kaliningrad", "Samara", "Volgograd"].contains(where: { id.contains($0) }):
            return "Russia"
            
        // Brazil
        case let id where id.starts(with: "America/") && id.contains("Brazil"):
            return "Brazil"
            
        // Mexico
        case let id where id.starts(with: "America/") && 
            ["Mexico_City", "Cancun", "Tijuana", "Monterrey"].contains(where: { id.contains($0) }):
            return "Mexico"
            
        // Singapore
        case "Asia/Singapore":
            return "Singapore"
            
        // Hong Kong
        case "Asia/Hong_Kong":
            return "Hong Kong"
            
        // Taiwan
        case "Asia/Taipei":
            return "Taiwan"
            
        // Dubai
        case "Asia/Dubai":
            return "United Arab Emirates"
            
        // Other major cities
        case "Europe/Rome": return "Italy"
        case "Europe/Madrid": return "Spain"
        case "Europe/Amsterdam": return "Netherlands"
        case "Europe/Brussels": return "Belgium"
        case "Europe/Zurich": return "Switzerland"
        case "Europe/Stockholm": return "Sweden"
        case "Europe/Oslo": return "Norway"
        case "Europe/Copenhagen": return "Denmark"
        case "Europe/Helsinki": return "Finland"
        case "Europe/Vienna": return "Austria"
        case "Europe/Prague": return "Czech Republic"
        case "Europe/Warsaw": return "Poland"
        case "Europe/Athens": return "Greece"
        case "Europe/Lisbon": return "Portugal"
        case "Europe/Dublin": return "Ireland"
        case "Asia/Bangkok": return "Thailand"
        case "Asia/Jakarta": return "Indonesia"
        case "Asia/Manila": return "Philippines"
        case "Asia/Kuala_Lumpur": return "Malaysia"
        case "Asia/Ho_Chi_Minh": return "Vietnam"
        case "Asia/Yangon": return "Myanmar"
        case "Asia/Dhaka": return "Bangladesh"
        case "Asia/Karachi": return "Pakistan"
        case "Asia/Tehran": return "Iran"
        case "Asia/Baghdad": return "Iraq"
        case "Asia/Jerusalem": return "Israel"
        case "Asia/Beirut": return "Lebanon"
        case "Asia/Amman": return "Jordan"
        case "Asia/Riyadh": return "Saudi Arabia"
        case "Africa/Cairo": return "Egypt"
        case "Africa/Lagos": return "Nigeria"
        case "Africa/Johannesburg": return "South Africa"
        case "Africa/Nairobi": return "Kenya"
        case "Africa/Casablanca": return "Morocco"
        case "Pacific/Auckland": return "New Zealand"
        case "Pacific/Fiji": return "Fiji"
        case "America/Buenos_Aires": return "Argentina"
        case "America/Santiago": return "Chile"
        case "America/Lima": return "Peru"
        case "America/Bogota": return "Colombia"
        case "America/Caracas": return "Venezuela"
        case "America/Panama": return "Panama"
        case "America/Guatemala": return "Guatemala"
        case "America/Havana": return "Cuba"
        case "America/Jamaica": return "Jamaica"
            
        // Other cases, return continent name
        default:
            if components.count >= 1 {
                let continent = String(components[0])
                switch continent {
                case "Africa": return "Africa"
                case "America": return "Americas"
                case "Antarctica": return "Antarctica"
                case "Arctic": return "Arctic"
                case "Asia": return "Asia"
                case "Atlantic": return "Atlantic Ocean"
                case "Australia": return "Australia"
                case "Europe": return "Europe"
                case "Indian": return "Indian Ocean"
                case "Pacific": return "Pacific Ocean"
                default: return continent
                }
            }
            return "Unknown"
        }
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
    
    // Get sorted keys for filtered results
    private var filteredSortedKeys: [String] {
        filteredGroupedTimeZones.keys.sorted { key1, key2 in
            // "#" symbol comes last
            if key1 == "#" { return false }
            if key2 == "#" { return true }
            return key1 < key2
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if filteredGroupedTimeZones.isEmpty {
                    // Empty state when no search results
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(filteredSortedKeys, id: \.self) { key in
                            Section(header: Text(key)) {
                                ForEach(filteredGroupedTimeZones[key] ?? [], id: \.id) { timeZoneData in
                                    TimeZoneCellView(
                                        timeZoneData: timeZoneData,
                                        isSelected: worldClocks.contains(where: { $0.timeZoneIdentifier == timeZoneData.identifier }),
                                        use24HourFormat: use24HourFormat,
                                        onToggle: {
                                            toggleClock(cityName: timeZoneData.cityName, identifier: timeZoneData.identifier)
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
                                    EarthImageView()
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
            if precomputedTimeZones.isEmpty {
                precomputeTimeZones()
            }
        }
    }
    
    // UserDefaults key for storing world clocks
    private let worldClocksKey = "savedWorldClocks"
    
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
                worldClocks.remove(at: index)
                saveWorldClocks()
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

// Individual cell view with its own timer
struct TimeZoneCellView: View {
    let timeZoneData: TimeZoneData
    let isSelected: Bool
    let use24HourFormat: Bool
    let onToggle: () -> Void
    
    @State private var currentDate = Date()
    // Timer to update time every second - each cell has its own timer
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                HStack (spacing: 16) {
                    // Show checkmark if already added
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body.weight(.bold))
                            .frame(width: 24)
                            .transition(.identity)
                            .id("checkmark-\(timeZoneData.identifier)")
                    } else {
                        Image(systemName: "circle")
                            .font(.body.weight(.medium))
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
                        Text(currentTime(for: tz))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onReceive(timer) { _ in
            currentDate = Date()
        }
    }
    
    // Get current time for timezone (for preview)
    private func currentTime(for timeZone: TimeZone) -> String {
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
        return formatter.string(from: currentDate)
    }
}

