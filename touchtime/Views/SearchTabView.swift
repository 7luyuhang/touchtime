//
//  SearchTabView.swift
//  touchtime
//
//  Created on 26/09/2025.
//

import SwiftUI

struct SearchTabView: View {
    @Binding var worldClocks: [WorldClock]
    @State private var isShowingPicker = false
    
    var body: some View {
        // Directly embed TimeZonePickerView for the search tab
        TimeZonePickerViewWrapper(worldClocks: $worldClocks)
    }
}

// Wrapper to adapt TimeZonePickerView for tab usage
struct TimeZonePickerViewWrapper: View {
    @Binding var worldClocks: [WorldClock]
    @State private var searchText = ""
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    
    // Get all time zones and create city name and country/region information
    var availableTimeZones: [(cityName: String, region: String, identifier: String)] {
        TimeZone.knownTimeZoneIdentifiers.compactMap { identifier in
            // Extract city name and region info from timezone identifier
            let components = identifier.split(separator: "/")
            if components.count >= 2 {
                // Replace underscore with space for readability
                let cityName = components.last!
                    .replacingOccurrences(of: "_", with: " ")
                
                // Get region/country info
                let region = getRegionForTimeZone(identifier: identifier)
                
                return (cityName: cityName, region: region, identifier: identifier)
            } else if components.count == 1 {
                // Handle timezones without slashes (like UTC, GMT)
                return (cityName: String(components[0]), region: "Standard Time", identifier: identifier)
            }
            return nil
        }
        .sorted { $0.cityName < $1.cityName }
    }
    
    // Get country/region name for timezone
    func getRegionForTimeZone(identifier: String) -> String {
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
    
    // Filter search results
    var filteredTimeZones: [(cityName: String, region: String, identifier: String)] {
        if searchText.isEmpty {
            return availableTimeZones
        } else {
            return availableTimeZones.filter { 
                $0.cityName.localizedCaseInsensitiveContains(searchText) ||
                $0.region.localizedCaseInsensitiveContains(searchText) ||
                $0.identifier.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // Group timezones by first letter
    var groupedTimeZones: [String: [(cityName: String, region: String, identifier: String)]] {
        Dictionary(grouping: filteredTimeZones) { timeZone in
            let firstChar = timeZone.cityName.prefix(1).uppercased()
            // Ensure it's a letter, otherwise categorize as "#"
            if firstChar.rangeOfCharacter(from: .letters) != nil {
                return firstChar
            } else {
                return "#"
            }
        }
    }
    
    // Get sorted group keys
    var sortedKeys: [String] {
        groupedTimeZones.keys.sorted { key1, key2 in
            // "#" symbol comes last
            if key1 == "#" { return false }
            if key2 == "#" { return true }
            return key1 < key2
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if filteredTimeZones.isEmpty {
                    // Empty state when no search results
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(sortedKeys, id: \.self) { key in
                            Section(header: Text(key)
                                ) {
                                    
                                ForEach(groupedTimeZones[key] ?? [], id: \.identifier) { timeZone in
                                    Button(action: {
                                        addClock(cityName: timeZone.cityName, identifier: timeZone.identifier)
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(timeZone.cityName)
    
                                                Text(timeZone.region)
                                                    .foregroundStyle(.secondary)
                                                    .font(.subheadline)
                                            }
                                            Spacer()
                                            // Show current time preview and added indicator
                                            HStack(spacing: 8) {
                                                if let tz = TimeZone(identifier: timeZone.identifier) {
                                                    Text(currentTime(for: tz))
                                                        .foregroundStyle(.secondary)
                                                        .monospacedDigit()
                                                }
                                                
                                                // Show checkmark if already added
                                                if worldClocks.contains(where: { $0.timeZoneIdentifier == timeZone.identifier }) {
                                                    Image(systemName: "checkmark")
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                }
                                            }
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .searchable(text: $searchText, prompt: "Search")
            .navigationTitle("Cities")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // UserDefaults key for storing world clocks
    private let worldClocksKey = "savedWorldClocks"
    
    // Add clock
    func addClock(cityName: String, identifier: String) {
        let newClock = WorldClock(cityName: cityName, timeZoneIdentifier: identifier)
        
        // Check if the same timezone already exists
        if !worldClocks.contains(where: { $0.timeZoneIdentifier == identifier }) {
            worldClocks.append(newClock)
            saveWorldClocks()
        }
    }
    
    // Save world clocks to UserDefaults
    func saveWorldClocks() {
        if let encoded = try? JSONEncoder().encode(worldClocks) {
            UserDefaults.standard.set(encoded, forKey: worldClocksKey)
        }
    }
    
    // Get current time for timezone (for preview)
    func currentTime(for timeZone: TimeZone) -> String {
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
        return formatter.string(from: Date())
    }
}

#Preview {
    SearchTabView(worldClocks: .constant(WorldClockData.defaultClocks))
}