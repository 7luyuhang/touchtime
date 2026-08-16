//
//  MoonPhaseView.swift
//  touchtime
//
//  Created on 25/01/2026.
//

import SwiftUI
import MoonKit

// MARK: - Global Moon Phase Cache using NSCache

/// Per-day moon data: asset name, phase name, plus whether the day contains the exact full/new/quarter moon instant.
final class MoonPhaseDayInfo {
    let imageName: String
    let isFullMoonDay: Bool
    let isNewMoonDay: Bool
    let isFirstQuarterDay: Bool
    let isLastQuarterDay: Bool
    let phase: MoonPhase
    
    init(imageName: String, isFullMoonDay: Bool, isNewMoonDay: Bool, isFirstQuarterDay: Bool, isLastQuarterDay: Bool, phase: MoonPhase) {
        self.imageName = imageName
        self.isFullMoonDay = isFullMoonDay
        self.isNewMoonDay = isNewMoonDay
        self.isFirstQuarterDay = isFirstQuarterDay
        self.isLastQuarterDay = isLastQuarterDay
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
    /// Uses the lightweight MoonAstronomy math instead of MoonKit's Moon: setting a new
    /// day on a Moon triggers its moonrise/moonset search (dozens of full coordinate
    /// passes per day), while the age alone is location independent and just a handful
    /// of trig calls. Months of days cost well under a millisecond, so callers can run
    /// this synchronously and have the data ready for their first frame.
    func prefetch(dates: [Date], calendar: Calendar) {
        // Day-start ages memoized so consecutive days share their boundary computation
        var agesByDay: [NSString: Double] = [:]
        
        func moonAge(atStartOf date: Date) -> Double {
            let ageKey = key(for: date, calendar: calendar)
            if let age = agesByDay[ageKey] { return age }
            
            let age = MoonAstronomy.snapshot(for: date).ageDays
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
                    isFirstQuarterDay: isFirstQuarterDay,
                    isLastQuarterDay: isLastQuarterDay,
                    phase: phase
                ),
                forKey: cacheKey
            )
        }
    }
}

// MARK: - Moon Phase View

/// Identifiable wrapper so tapping a day can drive a details sheet.
private struct MoonDetailsSelection: Identifiable {
    let id = UUID()
    /// Exact instant the details view should open with.
    let date: Date
}

struct MoonPhaseView: View {
    let cityName: String
    let timeZoneIdentifier: String
    let timeOffset: TimeInterval
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @State private var currentDate: Date = Date()
    @State private var selectedMonthIndex: Int = 1
    
    // Day whose phase name is shown in the subtitle; nil means today
    @State private var selectedDate: Date? = nil
    
    // Set when the user taps a day; presents the moon details sheet
    @State private var detailsSelection: MoonDetailsSelection? = nil
    
    // Cached month data (lightweight, computed synchronously)
    @State private var cachedMonths: [Date] = []
    @State private var cachedDays: [[Date?]] = []
    
    // Bumped after each prefetch, forcing grids to re-read the cache even when
    // none of their other inputs changed (e.g. a refill after an NSCache purge)
    @State private var phaseCacheVersion: Int = 0
    
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
        cal.firstWeekday = 2 // Monday
        return cal
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
    
    // Show the Today button when the user picked a day other than today
    private var isNonTodaySelected: Bool {
        guard let selectedDate else { return false }
        return !isToday(selectedDate)
    }
    
    // Instant the details view opens with: the adjusted "now" for today,
    // and the same current time of day carried onto any other tapped day,
    // so the details sheet always opens showing the current clock time.
    private func detailInstant(for dayStart: Date) -> Date {
        let adjustedNow = currentDate.addingTimeInterval(timeOffset)
        if isToday(dayStart) {
            return adjustedNow
        }
        let cal = calendar
        let time = cal.dateComponents([.hour, .minute, .second], from: adjustedNow)
        return cal.date(
            bySettingHour: time.hour ?? 12,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: dayStart
        ) ?? dayStart
    }
    
    // Scrub window for the details view: the same previous/current/next
    // months this calendar shows, from the first month's start to the last
    // second of the last month.
    private var detailsDateRange: ClosedRange<Date> {
        let cal = calendar
        if let firstMonth = cachedMonths.first,
           let lastMonth = cachedMonths.last,
           let end = cal.date(byAdding: .month, value: 1, to: lastMonth) {
            return firstMonth...end.addingTimeInterval(-1)
        }
        
        // Fallback before the calendar data exists, same window derived from now
        let adjustedNow = currentDate.addingTimeInterval(timeOffset)
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: adjustedNow)) ?? adjustedNow
        let lower = cal.date(byAdding: .month, value: -1, to: monthStart) ?? monthStart
        let upper = (cal.date(byAdding: .month, value: 2, to: monthStart) ?? monthStart).addingTimeInterval(-1)
        return lower...max(lower, upper)
    }
    
    // Mirrors MonthGridView's selection: today is the default selection
    // until the user picks another day.
    private func isSelectedDay(_ date: Date) -> Bool {
        if let selectedDate {
            return calendar.isDate(date, inSameDayAs: selectedDate)
        }
        return isToday(date)
    }
    
    // Phase name of the selected day (today by default), nil until prefetched
    private var selectedDayPhaseName: String? {
        let date = selectedDate ?? currentDate.addingTimeInterval(timeOffset)
        guard let info = MoonPhaseCache.shared.dayInfo(for: date, calendar: calendar) else { return nil }
        return Self.phaseName(for: info.phase)
    }
    
    static func phaseName(for phase: MoonKit.MoonPhase) -> String? {
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
    
    // Prefetch moon phases for visible and adjacent months, then bump the cache
    // version so the grids re-read the cache. The age math is cheap enough to run
    // synchronously, so the calendar is fully populated on its very first frame —
    // the old background pass left placeholder circles during the sheet's open
    // animation and its completion re-rendered every cell mid-flight.
    private func prefetchMoonPhases(around index: Int) {
        let indicesToPrefetch = [index, index - 1, index + 1].filter { $0 >= 0 && $0 < cachedDays.count }
        let dates = indicesToPrefetch.flatMap { cachedDays[$0].compactMap { $0 } }
        
        MoonPhaseCache.shared.prefetch(dates: dates, calendar: calendar)
        phaseCacheVersion += 1
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
                                if isSelectedDay(date) {
                                    // Second tap on the already-selected day opens the details
                                    detailsSelection = MoonDetailsSelection(date: detailInstant(for: date))
                                } else {
                                    selectedDate = date
                                }
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
            .overlay(alignment: .bottomTrailing) {
                ZStack {
                    if isNonTodaySelected {
                        Button {
                            if hapticEnabled {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                            withAnimation(.spring()) {
                                selectedDate = nil
                                selectedMonthIndex = 1
                            }
                        } label: {
                            Text("Today")
                                .font(.headline)
                                .foregroundStyle(.black)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .contentShape(Capsule(style: .continuous))
                                .glassEffect(.regular.tint(.white).interactive())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 4)
                        .transition(.blurReplace.combined(with: .opacity))
                    }
                }
                .animation(.spring(), value: isNonTodaySelected)
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
            .presentationDetents([.height(600)]) // Sheet Height
            .sheet(item: $detailsSelection) { selection in
                MoonPhaseDetailsView(
                    timeZoneIdentifier: timeZoneIdentifier,
                    initialDate: selection.date,
                    dateRange: detailsDateRange
                )
            }
        }
        .onAppear {
            prepareCalendarData()
            prefetchMoonPhases(around: selectedMonthIndex)
            // Prime the details sheet's formatters off the main thread so this
            // sheet's first frame doesn't pay for their ICU setup either.
            DispatchQueue.global(qos: .utility).async {
                MoonPhaseDetailsView.warmupFormatters()
            }
            if hapticEnabled {
                UIImpactFeedbackGenerator(style: .light).prepare()
            }
        }
        .onChange(of: selectedMonthIndex) { _, newIndex in
            prefetchMoonPhases(around: newIndex)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // iOS purges the NSCache-backed moon data while the app is
            // backgrounded. The sheet stays presented, so onAppear never
            // re-fires and the grid would be stuck on empty placeholders.
            // Re-prefetch (already-cached days are skipped) and refresh
            // "today" in case the date rolled over while suspended.
            guard newPhase == .active else { return }
            currentDate = Date()
            prepareCalendarData()
            prefetchMoonPhases(around: selectedMonthIndex)
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
                            isFirstQuarterDay: dayInfo?.isFirstQuarterDay ?? false,
                            isLastQuarterDay: dayInfo?.isLastQuarterDay ?? false,
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
    let isFirstQuarterDay: Bool
    let isLastQuarterDay: Bool
    let isToday: Bool
    let isSelected: Bool
    
    // The moon disc only spans ~86% of the source photo (626px of 730px),
    // the rest is black margin. Scaling inside the circular clip crops the
    // margin away, matching MoonPhaseWidget.
    private static let discCropScale: CGFloat = 1.18
    
    var body: some View {
        VStack(spacing: 8) {
            // The day number and (on key phase days) the small phase dot are
            // laid out as one group, so the pair centers in the cell together
            // instead of the number staying centered with the dot hanging off
            // its trailing edge.
            HStack(spacing: 4) {
                Text("\(dayNumber)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isToday || isSelected ? .primary : .secondary)

                // Filled dot marks a full moon day, outlined dot a new moon day,
                // half-filled dot a first/last quarter day
                if isFullMoonDay || isNewMoonDay || isFirstQuarterDay || isLastQuarterDay {
                    Group {
                        if isFullMoonDay {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 6, height: 6)
                        } else if isNewMoonDay {
                            // Negative inset draws the 1.5pt line entirely outside the 6pt circle
                            Circle()
                                .inset(by: -0.75)
                                .stroke(Color.white, lineWidth: 1.5)
                                .frame(width: 5, height: 5)
                        } else {
                            // Outlined dot with the lit half filled: right half while
                            // waxing (first quarter), left half while waning (last quarter)
                            ZStack {
                                Circle()
                                    .trim(from: 0, to: 0.5)
                                    .rotation(.degrees(isFirstQuarterDay ? -90 : 90))
                                    .fill(Color.white)
                                    .frame(width: 6, height: 6)
                                Circle()
                                    .inset(by: -0.75)
                                    .stroke(Color.white, lineWidth: 1.5)
                                    .frame(width: 5, height: 5)
                            }
                        }
                    }
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
