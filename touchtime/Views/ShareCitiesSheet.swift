//
//  ShareCitiesSheet.swift
//  touchtime
//
//  Created on 27/09/2025.
//

import SwiftUI

struct ShareCitiesSheet: View {
    @Binding var worldClocks: [WorldClock]
    @Binding var showSheet: Bool
    @State private var selectedCities: Set<UUID> = []
    @State private var showLocalTime = false
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showLocalTime") private var showLocalTimeInHome = true
    @AppStorage("customLocalName") private var customLocalName = ""
    
    let currentDate: Date
    let timeOffset: TimeInterval
    
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
    
    // Generate share text
    func generateShareText() -> String {
        var shareLines: [String] = []
        
        // Add local time if selected and shown in home
        if showLocalTimeInHome && showLocalTime {
            let localName = customLocalName.isEmpty ? localCityName : customLocalName
            let localTime = formatTime(for: TimeZone.current)
            shareLines.append("\(localName): \(localTime)")
        }
        
        // Add selected world clocks
        for clock in worldClocks {
            if selectedCities.contains(clock.id) {
                if let timeZone = TimeZone(identifier: clock.timeZoneIdentifier) {
                    let time = formatTime(for: timeZone)
                    shareLines.append("\(clock.cityName) \(time)")
                }
            }
        }
        
        return shareLines.joined(separator: "\n")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Local time card
                    if showLocalTimeInHome {
                        Button(action: {
                            withAnimation(.spring()) {
                                showLocalTime.toggle()
                            }
                        }) {
                            HStack(spacing: 16) {
                                
                                // Selection indicator
                                ZStack {
                                    if showLocalTime {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.primary)
                                            .transition(.blurReplace.combined(with: .scale))
                                    } else {
                                        Image(systemName: "circle")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.primary.opacity(0.25))
                                            .transition(.blurReplace.combined(with: .scale))
                                    }
                                }
                                
                                // City name
                                HStack {
                                    Image(systemName: "location.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(customLocalName.isEmpty ? localCityName : customLocalName)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                
                                Spacer()
                                
                                // Time
                                Text(formatTime(for: TimeZone.current))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)

                            }
                        }
                        .padding(.vertical, 10)
                        .contentShape(.rect)
                        .buttonStyle(.plain)
                        
                        Divider()
                            .padding(.vertical, 10)
                    }
                    
                    // World clocks cards
                    ForEach(worldClocks) { clock in
                        Button(action: {
                            withAnimation(.spring()) {
                                if selectedCities.contains(clock.id) {
                                    selectedCities.remove(clock.id)
                                } else {
                                    selectedCities.insert(clock.id)
                                }
                            }
                        }) {
                            HStack(spacing: 16) {
                                // Selection indicator
                                ZStack {
                                    if selectedCities.contains(clock.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.primary)
                                            .transition(.blurReplace.combined(with: .scale))
                                    } else {
                                        Image(systemName: "circle")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.primary.opacity(0.25))
                                            .transition(.blurReplace.combined(with: .scale))
                                    }
                                }
                                
                                // City name
                                Text(clock.cityName)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                
                                Spacer()
                                
                                // Time on the right
                                if let timeZone = TimeZone(identifier: clock.timeZoneIdentifier) {
                                    Text(formatTime(for: timeZone))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 10)
                        .contentShape(.rect)
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Share Cities")
            .navigationBarTitleDisplayMode(.inline)
            .scrollIndicators(.hidden)
            
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Only show share button if at least one city is selected
                    if !selectedCities.isEmpty || (showLocalTimeInHome && showLocalTime) {
                        ShareLink(item: generateShareText()) {
                            Text("Share")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showSheet = false
                    }
                }
            }
        }
        .presentationDetents([.height(280)])
    }
}
