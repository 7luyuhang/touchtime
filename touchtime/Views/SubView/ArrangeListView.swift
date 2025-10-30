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
    
    var body: some View {
        NavigationView {
            List {
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
                        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
                        .deleteDisabled(true)
                        .moveDisabled(true)
                    }
                }
                
                // World Clocks Section
                Section {
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
                }
            }
            .scrollIndicators(.hidden)
            .listStyle(.insetGrouped)
            .environment(\.editMode, $editMode)
            .navigationTitle("Reorder Cities")
            .navigationBarTitleDisplayMode(.inline)
            
            .toolbar {
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
        }
    }
}
