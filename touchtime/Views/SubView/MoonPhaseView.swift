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

/// Per-day moon data: asset name, phase name, plus whether the day contains the exact full/new moon instant.
final class MoonPhaseDayInfo {
    let imageName: String
    let isFullMoonDay: Bool
    let isNewMoonDay: Bool
    let phase: MoonPhase
    
    init(imageName: String, isFullMoonDay: Bool, isNewMoonDay: Bool, phase: MoonPhase) {
        self.imageName = imageName
        self.isFullMoonDay = isFullMoonDay
        self.isNewMoonDay = isNewMoonDay
        self.phase = phase
    }
}

final class MoonPhaseCache {
    static let shared = MoonPhaseCache()
    
    private let cache = NSCache<NSString, MoonPhaseDayInfo>()
    
    private static let synodicMonth = 29.53058867
    // MoonKit's conversion factor from moon age in days to degrees (see Moon.ageOfTheMoonDegress)
    private static let degreesPerAgeDay = 12.1907
    
    private init() {
        cache.countLimit = 1500  // Cache up to ~4 years of daily data
    }
    
    private func key(for date: Date, calendar: Calendar) -> NSString {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)" as NSString
    }
    
    /// Cache-only lookup, cheap enough for view bodies. Returns nil until prefetched.
    func dayInfo(for date: Date, calendar: Calendar) -> MoonPhaseDayInfo? {
        cache.object(forKey: key(for: date, calendar: calendar))
    }
    
    /// Computes moon ages for all given dates and stores asset names (moon_age_00...moon_age_29)
    /// along with full/new moon day flags.
    /// Call from a background queue: MoonKit recomputes rise/set times for every new day,
    /// which is far too slow for the main thread. Reuses one Moon instance for the whole batch.
    func prefetch(dates: [Date], coordinates: (latitude: Double, longitude: Double)?, timeZone: TimeZone, calendar: Calendar) {
        guard let coords = coordinates else {
            for date in dates {
                let cacheKey = key(for: date, calendar: calendar)
                if cache.object(forKey: cacheKey) == nil {
                    cache.setObject(
                        MoonPhaseDayInfo(imageName: "moon_age_00", isFullMoonDay: false, isNewMoonDay: false, phase: .newMoon),
                        forKey: cacheKey
                    )
                }
            }
            return
        }
        
        var moon: Moon?
        // Day-start ages memoized so consecutive days share their boundary computation
        var agesByDay: [NSString: Double] = [:]
        
        func moonAge(atStartOf date: Date) -> Double {
            let ageKey = key(for: date, calendar: calendar)
            if let age = agesByDay[ageKey] { return age }
            
            let instance: Moon
            if let moon {
                instance = moon
            } else {
                instance = Moon(
                    location: CLLocation(latitude: coords.latitude, longitude: coords.longitude),
                    timeZone: timeZone
                )
                moon = instance
            }
            instance.setDate(date)
            
            let age = instance.ageOfTheMoonInDays
            agesByDay[ageKey] = age
            return age
        }
        
        for date in dates {
            let cacheKey = key(for: date, calendar: calendar)
            if cache.object(forKey: cacheKey) != nil { continue }
            
            let ageAtDayStart = moonAge(atStartOf: date)
            let nextDayStart = calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86400)
            let ageAtDayEnd = moonAge(atStartOf: nextDayStart)
            
            // Age wraps at the end of the synodic cycle (~29.5 days) back to new moon
            let imageIndex = Int(ageAtDayStart.rounded()) % 30
            
            // New moon day: the age wraps back to zero during the day.
            // Full moon day: the age crosses half a synodic month during the day.
            let halfCycle = Self.synodicMonth / 2
            let isNewMoonDay = ageAtDayEnd < ageAtDayStart
            let isFullMoonDay = ageAtDayStart <= halfCycle && ageAtDayEnd > halfCycle
            
            // Quarter days: the age crosses a quarter/three-quarter cycle during the day.
            // Detected via crossings because MoonKit's own quarter windows span only ~4h,
            // which a single midday sample would usually miss.
            let quarterCycle = Self.synodicMonth / 4
            let threeQuarterCycle = Self.synodicMonth * 3 / 4
            let isFirstQuarterDay = ageAtDayStart <= quarterCycle && ageAtDayEnd > quarterCycle
            let isLastQuarterDay = ageAtDayStart <= threeQuarterCycle && ageAtDayEnd > threeQuarterCycle
            
            let phase: MoonPhase
            if isNewMoonDay {
                phase = .newMoon
            } else if isFullMoonDay {
                phase = .fullMoon
            } else if isFirstQuarterDay {
                phase = .firstQuarter
            } else if isLastQuarterDay {
                phase = .lastQuarter
            } else {
                // Midday age gives a stable representative phase for the whole day
                let middayDegrees = ((ageAtDayStart + ageAtDayEnd) / 2 * Self.degreesPerAgeDay)
                    .truncatingRemainder(dividingBy: 360)
                phase = MoonPhase.ageOfTheMoonDegrees2MoonPhase(middayDegrees)
            }
            
            cache.setObject(
                MoonPhaseDayInfo(
                    imageName: String(format: "moon_age_%02d", imageIndex),
                    isFullMoonDay: isFullMoonDay,
                    isNewMoonDay: isNewMoonDay,
                    phase: phase
                ),
                forKey: cacheKey
            )
        }
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
    
    // Day whose phase name is shown in the subtitle; nil means today
    @State private var selectedDate: Date? = nil
    
    // Cached month data (lightweight, computed synchronously)
    @State private var cachedMonths: [Date] = []
    @State private var cachedDays: [[Date?]] = []
    
    // Bumped when background prefetch finishes, forcing grids to re-read the cache
    @State private var phaseCacheVersion: Int = 0
    
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
    
    // Phase name of the selected day (today by default), nil until prefetched
    private var selectedDayPhaseName: String? {
        let date = selectedDate ?? currentDate.addingTimeInterval(timeOffset)
        guard let info = MoonPhaseCache.shared.dayInfo(for: date, calendar: calendar) else { return nil }
        return Self.phaseName(for: info.phase)
    }
    
    private static func phaseName(for phase: MoonKit.MoonPhase) -> String? {
        switch phase {
        case .newMoon:
            return String(localized: "New Moon")
        case .waxingCrescent:
            return String(localized: "Waxing Crescent")
        case .firstQuarter:
            return String(localized: "First Quarter")
        case .waxingGibbous:
            return String(localized: "Waxing Gibbous")
        case .fullMoon:
            return String(localized: "Full Moon")
        case .waningGibbous:
            return String(localized: "Waning Gibbous")
        case .lastQuarter:
            return String(localized: "Last Quarter")
        case .waningCrescent:
            return String(localized: "Waning Crescent")
        case .error:
            return nil
        }
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
    
    // Prefetch moon phases for visible and adjacent months in background,
    // then bump the cache version so the grids re-read the cache.
    private func prefetchMoonPhases(around index: Int) {
        let indicesToPrefetch = [index, index - 1, index + 1].filter { $0 >= 0 && $0 < cachedDays.count }
        let dates = indicesToPrefetch.flatMap { cachedDays[$0].compactMap { $0 } }
        let cal = calendar
        let coords = coordinates
        let tz = timeZone
        
        DispatchQueue.global(qos: .userInitiated).async {
            MoonPhaseCache.shared.prefetch(dates: dates, coordinates: coords, timeZone: tz, calendar: cal)
            
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.25)) {
                    phaseCacheVersion += 1
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
                            currentDate: currentDate,
                            timeOffset: timeOffset,
                            cacheVersion: phaseCacheVersion,
                            selectedDate: selectedDate,
                            onSelect: { date in
                                if hapticEnabled {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                                selectedDate = date
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if hapticEnabled {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                
                ToolbarItem(placement: .title) {
                    Text(monthYearString(for: currentDisplayedMonth))
                        .font(.headline)
                        .contentTransition(.numericText())
                        .animation(.spring(), value: selectedMonthIndex)
                }
                
                ToolbarItem(placement: .subtitle) {
                    if let phaseName = selectedDayPhaseName {
                        Text(phaseName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                            .animation(.spring(), value: phaseName)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
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
            }
            .animation(.spring(), value: selectedMonthIndex != 1)
            .presentationDetents([.height(550)]) // Sheet Height
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
    let currentDate: Date
    let timeOffset: TimeInterval
    let cacheVersion: Int
    let selectedDate: Date?
    let onSelect: (Date) -> Void
    
    private static let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    
    private func isToday(_ date: Date) -> Bool {
        let adjustedToday = currentDate.addingTimeInterval(timeOffset)
        return calendar.isDate(date, inSameDayAs: adjustedToday)
    }
    
    // Today acts as the default selection until the user picks another day
    private func isSelected(_ date: Date) -> Bool {
        if let selectedDate {
            return calendar.isDate(date, inSameDayAs: selectedDate)
        }
        return isToday(date)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Calendar grid
            LazyVGrid(columns: Self.gridColumns, spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        let dayInfo = MoonPhaseCache.shared.dayInfo(for: date, calendar: calendar)
                        DayCellView(
                            date: date,
                            dayNumber: calendar.component(.day, from: date),
                            moonPhaseIcon: dayInfo?.imageName,
                            isFullMoonDay: dayInfo?.isFullMoonDay ?? false,
                            isNewMoonDay: dayInfo?.isNewMoonDay ?? false,
                            isToday: isToday(date),
                            isSelected: isSelected(date)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onTapGesture {
                            onSelect(date)
                        }
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
    let moonPhaseIcon: String?
    let isFullMoonDay: Bool
    let isNewMoonDay: Bool
    let isToday: Bool
    let isSelected: Bool
    
    // The moon disc only spans ~86% of the source photo (626px of 730px),
    // the rest is black margin. Scaling inside the circular clip crops the
    // margin away, matching MoonPhaseWidget.
    private static let discCropScale: CGFloat = 1.18
    
    var body: some View {
        VStack(spacing: 8) {
            Text("\(dayNumber)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isToday || isSelected ? .primary : .secondary)
                .overlay(alignment: .trailing) {
                    // Filled dot marks a full moon day, outlined dot a new moon day
                    if isFullMoonDay || isNewMoonDay {
                        Group {
                            if isFullMoonDay {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 6, height: 6)
                            } else {
                                // Negative inset draws the 1.5pt line entirely outside the 6pt circle
                                Circle()
                                    .inset(by: -0.75)
                                    .stroke(Color.white, lineWidth: 1.5)
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .offset(x: 10)
                    }
                }
            
            Group {
                if let moonPhaseIcon {
                    Image(moonPhaseIcon)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(Self.discCropScale)
                        .transition(.opacity)
                } else {
                    // Placeholder while the moon age is computed in the background
                    Circle()
                        .fill(.white.opacity(0.06))
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            .grayscale(1)
            .blendMode(.plusLighter)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background {
            // Selected day (today by default) is filled; today keeps an
            // outline when another day is selected.
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.15))
            } else if isToday {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1.5)
            }
        }
    }
}
