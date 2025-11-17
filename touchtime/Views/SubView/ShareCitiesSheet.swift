//
//  ShareCitiesSheet.swift
//  touchtime
//
//  Created on 27/09/2025.
//

import SwiftUI
import UIKit

struct ShareCitiesSheet: View {
    @Binding var worldClocks: [WorldClock]
    @Binding var showSheet: Bool
    @State private var selectedCities: Set<UUID> = []
    @State private var showLocalTime = false
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showLocalTime") private var showLocalTimeInHome = true
    @AppStorage("customLocalName") private var customLocalName = ""
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    
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
            shareLines.append("\(localName) \(localTime)")
        }
        
        // Add selected world clocks
        for clock in worldClocks {
            if selectedCities.contains(clock.id) {
                if let timeZone = TimeZone(identifier: clock.timeZoneIdentifier) {
                    let time = formatTime(for: timeZone)
                    shareLines.append("\(clock.localizedCityName) \(time)")
                }
            }
        }
        
        return shareLines.joined(separator: "\n")
    }
    
    // Check if all cities are selected
    var allCitiesSelected: Bool {
        let allWorldClocksSelected = worldClocks.allSatisfy { selectedCities.contains($0.id) }
        let localTimeSelected = !showLocalTimeInHome || showLocalTime
        return allWorldClocksSelected && localTimeSelected
    }
    
    // Toggle all selections
    func toggleSelectAll() {
        // Provide haptic feedback if enabled
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
        
        withAnimation(.spring()) {
            if allCitiesSelected {
                // Deselect all
                selectedCities.removeAll()
                if showLocalTimeInHome {
                    showLocalTime = false
                }
            } else {
                // Select all
                selectedCities = Set(worldClocks.map { $0.id })
                if showLocalTimeInHome {
                    showLocalTime = true
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 0) {
                        // Local time card
                        if showLocalTimeInHome {
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
                                    .foregroundStyle(.secondary)}

                            }
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    showLocalTime.toggle()
                                }
                                if hapticEnabled {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                            }
//                            Divider()
//                                .padding(.vertical, 12)
                        }
                        
                        // World clocks cards
                        ForEach(worldClocks) { clock in
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
                                Text(clock.localizedCityName)
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
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    if selectedCities.contains(clock.id) {
                                        selectedCities.remove(clock.id)
                                    } else {
                                        selectedCities.insert(clock.id)
                                    }
                                }
                                if hapticEnabled {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                            }
                        }
                    }
                    // Overall List
                    .padding(.horizontal)
                }
                
                // Select All button
                VStack {
                    Spacer()
                    
                Button(action: toggleSelectAll) {
                    Text(allCitiesSelected ? String(localized: "Deselect All") : String(localized: "Select All"))
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .contentTransition(.numericText())
                }
                .buttonStyle(.glass)
                }
                
            }
            .navigationTitle(String(localized: "Share Cities"))
            .navigationBarTitleDisplayMode(.inline)
            .scrollIndicators(.hidden)
            
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Only show share button if at least one city is selected
                    if !selectedCities.isEmpty || (showLocalTimeInHome && showLocalTime) {
                        
                        ShareLink(item: generateShareText()) {
                            Text(String(localized: "Share"))
//                                .foregroundStyle(.white)
                                .font(.headline)
                        }
//                        .buttonStyle(.glassProminent)
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        
                        if hapticEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }

                        showSheet = false
                    }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
