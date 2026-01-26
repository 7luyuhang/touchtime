//
//  MoonPhaseView.swift
//  touchtime
//
//  Created on 25/01/2026.
//

import SwiftUI
import MoonKit
import CoreLocation

// MARK: - Global Moon Phase Cache using NSCache
final class MoonPhaseCache {
    static let shared = MoonPhaseCache()
    
    private let cache = NSCache<NSString, NSString>()
    
    private init() {
        cache.countLimit = 1500  // Cache up to ~4 years of daily data
    }
    
    func getPhase(year: Int, month: Int, day: Int) -> String? {
        let key = "\(year)-\(month)-\(day)" as NSString
        return cache.object(forKey: key) as String?
    }
    
    func setPhase(_ icon: String, year: Int, month: Int, day: Int) {
        let key = "\(year)-\(month)-\(day)" as NSString
        cache.setObject(icon as NSString, forKey: key)
    }
    
    func computeAndCache(for date: Date, coordinates: (latitude: Double, longitude: Double)?, timeZone: TimeZone, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        
        // Check cache first
        if let cached = getPhase(year: year, month: month, day: day) {
            return cached
        }
        
        // Compute moon phase
        let icon: String
        if let coords = coordinates {
            let moon = Moon(
                location: CLLocation(latitude: coords.latitude, longitude: coords.longitude),
                timeZone: timeZone
            )
            moon.setDate(date)
            
            let phase = moon.currentMoonPhase
            let phaseString = String(describing: phase)
                .replacingOccurrences(of: "MoonPhase.", with: "")
                .replacingOccurrences(of: "_", with: " ")
                .lowercased()
            
            switch phaseString {
            case "newmoon", "new moon":
                icon = "moonphase.new.moon"
            case "waxingcrescent", "waxing crescent":
                icon = "moonphase.waxing.crescent"
            case "firstquarter", "first quarter":
                icon = "moonphase.first.quarter"
            case "waxinggibbous", "waxing gibbous":
                icon = "moonphase.waxing.gibbous"
            case "fullmoon", "full moon":
                icon = "moonphase.full.moon"
            case "waninggibbous", "waning gibbous":
                icon = "moonphase.waning.gibbous"
            case "lastquarter", "last quarter", "thirdquarter", "third quarter":
                icon = "moonphase.last.quarter"
            case "waningcrescent", "waning crescent":
                icon = "moonphase.waning.crescent"
            default:
                icon = "moonphase.new.moon"
            }
        } else {
            icon = "moonphase.new.moon"
        }
        
        // Store in cache
        setPhase(icon, year: year, month: month, day: day)
        return icon
    }
}

// MARK: - Moon Phase View
struct MoonPhaseView: View {
    let cityName: String
    let timeZoneIdentifier: String
    let timeOffset: TimeInterval
    
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @State private var currentDate: Date = Date()
    @State private var selectedMonthIndex: Int = 1
    
    // Cached month data (lightweight, computed synchronously)
    @State private var cachedMonths: [Date] = []
    @State private var cachedDays: [[Date?]] = []
    
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
        cal.firstWeekday = 2 // Monday
        return cal
    }
    
    private var coordinates: (latitude: Double, longitude: Double)? {
        TimeZoneCoordinates.getCoordinate(for: timeZoneIdentifier)
    }
    
    private var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    private func monthYearString(for date: Date) -> String {
        dateFormatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        return dateFormatter.string(from: date)
    }
    
    private var currentDisplayedMonth: Date {
        guard selectedMonthIndex >= 0 && selectedMonthIndex < cachedMonths.count else {
            return currentDate.addingTimeInterval(timeOffset)
        }
        return cachedMonths[selectedMonthIndex]
    }
    
    private func isToday(_ date: Date) -> Bool {
        let adjustedToday = currentDate.addingTimeInterval(timeOffset)
        return calendar.isDate(date, inSameDayAs: adjustedToday)
    }
    
    // Synchronously prepare month and day data (fast, no moon calculation)
    private func prepareCalendarData() {
        let cal = calendar
        let baseDate = currentDate.addingTimeInterval(timeOffset)
        let currentMonth = cal.date(from: cal.dateComponents([.year, .month], from: baseDate))!
        
        // Generate months array (1 past + current + 1 future = 3 months)
        var months: [Date] = []
        for i in -1...1 {
            if let month = cal.date(byAdding: .month, value: i, to: currentMonth) {
                months.append(month)
            }
        }
        
        // Generate days for each month
        var allDays: [[Date?]] = []
        for monthDate in months {
            let range = cal.range(of: .day, in: .month, for: monthDate)!
            let firstDayOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: monthDate))!
            
            var firstWeekday = cal.component(.weekday, from: firstDayOfMonth)
            firstWeekday = firstWeekday == 1 ? 7 : firstWeekday - 1
            
            var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
            
            for day in range {
                if let date = cal.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                    days.append(date)
                }
            }
            
            while days.count % 7 != 0 {
                days.append(nil)
            }
            
            allDays.append(days)
        }
        
        cachedMonths = months
        cachedDays = allDays
    }
    
    // Prefetch moon phases for visible and adjacent months in background
    private func prefetchMoonPhases(around index: Int) {
        let indicesToPrefetch = [index - 1, index, index + 1].filter { $0 >= 0 && $0 < cachedDays.count }
        let cal = calendar
        let coords = coordinates
        let tz = timeZone
        
        DispatchQueue.global(qos: .userInitiated).async {
            for idx in indicesToPrefetch {
                for date in cachedDays[idx].compactMap({ $0 }) {
                    _ = MoonPhaseCache.shared.computeAndCache(
                        for: date,
                        coordinates: coords,
                        timeZone: tz,
                        calendar: cal
                    )
                }
            }
        }
    }
    
    private static let weekdayKeys = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                
                // Weekday Headers
                HStack(spacing: 0) {
                    ForEach(Self.weekdayKeys, id: \.self) { key in
                        Text(LocalizedStringKey(key))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top)
                .padding(.horizontal)
                
                // Swipeable month pages
                TabView(selection: $selectedMonthIndex) {
                    ForEach(Array(cachedMonths.enumerated()), id: \.offset) { index, monthDate in
                        MonthGridView(
                            days: cachedDays.indices.contains(index) ? cachedDays[index] : [],
                            calendar: calendar,
                            coordinates: coordinates,
                            timeZone: timeZone,
                            currentDate: currentDate,
                            timeOffset: timeOffset
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selectedMonthIndex != 1 {
                        Button {
                            if hapticEnabled {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                            withAnimation(.spring()) {
                                selectedMonthIndex = 1
                            }
                        } label: {
                            Image(systemName: selectedMonthIndex < 1 ? "arrow.forward" : "arrow.backward")
                                .font(.headline)
                        }
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text(monthYearString(for: currentDisplayedMonth))
                        .font(.headline)
                        .contentTransition(.numericText())
                        .animation(.spring(), value: selectedMonthIndex)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if hapticEnabled {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .animation(.spring(), value: selectedMonthIndex != 1)
            .presentationDetents([.height(500)])
        }
        .onAppear {
            prepareCalendarData()
            prefetchMoonPhases(around: selectedMonthIndex)
        }
        .onChange(of: selectedMonthIndex) { _, newIndex in
            prefetchMoonPhases(around: newIndex)
        }
    }
}

// MARK: - Month Grid View
private struct MonthGridView: View {
    let days: [Date?]
    let calendar: Calendar
    let coordinates: (latitude: Double, longitude: Double)?
    let timeZone: TimeZone
    let currentDate: Date
    let timeOffset: TimeInterval
    
    private static let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    
    private func isToday(_ date: Date) -> Bool {
        let adjustedToday = currentDate.addingTimeInterval(timeOffset)
        return calendar.isDate(date, inSameDayAs: adjustedToday)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Calendar grid
            LazyVGrid(columns: Self.gridColumns, spacing: 12) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        DayCellView(
                            date: date,
                            dayNumber: calendar.component(.day, from: date),
                            moonPhaseIcon: MoonPhaseCache.shared.computeAndCache(
                                for: date,
                                coordinates: coordinates,
                                timeZone: timeZone,
                                calendar: calendar
                            ),
                            isToday: isToday(date)
                        )
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
}

// MARK: - Day Cell View
private struct DayCellView: View {
    let date: Date
    let dayNumber: Int
    let moonPhaseIcon: String
    let isToday: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text("\(dayNumber)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isToday ? .primary : .secondary)
            
            Image(systemName: moonPhaseIcon)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isToday ? Color.white.opacity(0.10) : .clear)
        )
    }
}
