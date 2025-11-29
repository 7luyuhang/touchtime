//
//  AnalogClockFullView.swift
//  touchtime
//
//  Created on 28/11/2025.
//

import SwiftUI
import Combine

struct AnalogClockFullView: View {
    @Binding var worldClocks: [WorldClock]
    @State private var currentDate = Date()
    @State private var timeOffset: TimeInterval = 0
    @State private var showScrollTimeButtons = false
    @State private var selectedCityId: UUID? = nil // nil means Local is selected
    
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showLocalTime") private var showLocalTime = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    
    @Environment(\.dismiss) private var dismiss
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Get selected city name
    private var selectedCityName: String {
        if let cityId = selectedCityId,
           let city = worldClocks.first(where: { $0.id == cityId }) {
            return city.localizedCityName
        }
        return String(localized: "Local")
    }
    
    // Get selected timezone
    private var selectedTimeZone: TimeZone {
        if let cityId = selectedCityId,
           let city = worldClocks.first(where: { $0.id == cityId }),
           let timeZone = TimeZone(identifier: city.timeZoneIdentifier) {
            return timeZone
        }
        return TimeZone.current
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                let displayDate = currentDate.addingTimeInterval(timeOffset)
                let skyGradient = SkyColorGradient(
                    date: displayDate,
                    timeZoneIdentifier: selectedTimeZone.identifier
                )
                
                ZStack {
                    // Background
                    skyGradient.linearGradient()
                        .ignoresSafeArea()
                        .opacity(0.65)
                        .animation(.spring(), value: selectedTimeZone.identifier)
                    
                    // Analog Clock - always centered
                    AnalogClockFaceView(
                        date: currentDate.addingTimeInterval(timeOffset),
                        size: size,
                        worldClocks: worldClocks,
                        showLocalTime: showLocalTime,
                        selectedCityId: $selectedCityId,
                        hapticEnabled: hapticEnabled
                    )
                    
                    // Digital time and scroll controls overlay
                    VStack(spacing: 0) {
                        // Top section - Digital time centered between nav bar and clock
                        VStack {
                            Spacer()
                            DigitalTimeDisplayView(
                                currentDate: currentDate,
                                timeOffset: timeOffset,
                                selectedTimeZone: selectedTimeZone,
                                use24HourFormat: use24HourFormat
                            )
                            .animation(.spring(), value: selectedTimeZone.identifier)
                            Spacer()
                        }
                        .frame(height: (geometry.size.height - size) / 2)
                        
                        // Middle - clock area (transparent placeholder)
                        Color.clear
                            .frame(height: size)
                        
                        // Bottom section - Scroll controls
                        VStack {
                            Spacer()
                            // Local time display
                            if selectedCityId != nil {
                                HStack(spacing: 4) {
                                    Image(systemName: "location.fill")
                                        .font(.footnote.weight(.semibold))
                                    Text({
                                        let formatter = DateFormatter()
                                        formatter.timeZone = TimeZone.current
                                        if use24HourFormat {
                                            formatter.dateFormat = "HH:mm"
                                        } else {
                                            formatter.dateFormat = "h:mm"
                                        }
                                        return formatter.string(from: displayDate)
                                    }())
                                    .font(.subheadline.weight(.semibold))
                                }
                                .foregroundStyle(.secondary)
                                .blendMode(.plusLighter)
                                .contentTransition(.numericText())
                                .padding(.bottom, 16)
                            }
                            Spacer()
                            ScrollTimeView(
                                timeOffset: $timeOffset,
                                showButtons: $showScrollTimeButtons,
                                worldClocks: $worldClocks
                            )
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                        .frame(height: (geometry.size.height - size) / 2)
                    }
                }
            }
            .navigationTitle(selectedCityName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if hapticEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                    }
                }
            }
            .onReceive(timer) { _ in
                withAnimation(.spring()) {
                    currentDate = Date()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetScrollTime"))) { _ in
                withAnimation(.smooth()) { // Hands Animation
                    timeOffset = 0
                    showScrollTimeButtons = false
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Analog Clock Face View
struct AnalogClockFaceView: View {
    let date: Date
    let size: CGFloat
    let worldClocks: [WorldClock]
    let showLocalTime: Bool
    @Binding var selectedCityId: UUID?
    let hapticEnabled: Bool
    
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    
    // Get local time components
    private var localTime: (hour: Int, minute: Int) {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0, components.minute ?? 0)
    }
    
    // Get time for a specific timezone
    private func getTime(for timeZoneIdentifier: String) -> (hour: Int, minute: Int) {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return (0, 0)
        }
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0, components.minute ?? 0)
    }
    
    // Calculate angle for a given hour and minute
    private func angleForTime(hour: Int, minute: Int) -> Double {
        // 24-hour clock: full rotation = 24 hours
        // 12 o'clock = 0 degrees (top)
        // Each hour = 15 degrees (360/24)
        let hourAngle = Double(hour) * 15.0
        let minuteAngle = Double(minute) * 0.25 // 15 degrees per hour / 60 minutes
        return hourAngle + minuteAngle - 90 // Adjust so 0 hours is at top
    }
    
    
    var body: some View {
        ZStack {
            // Clock face background
            Circle()
                .fill(Color.black.opacity(0.25))
                .glassEffect(.clear.interactive())
                .frame(width: max(size - 24, 0), height: max(size - 24, 0))
            
            // Hour numbers - Right side (1-12 for hours 0-12)
            ForEach(1..<13, id: \.self) { hour in
                let angle = Double(hour) * 15.0 - 90 // 15 degrees per hour, starting from top
                let radius = size / 2 - 36
                let x = radius * cos(angle * .pi / 180)
                let y = radius * sin(angle * .pi / 180)
                
                Text("\(hour)")
                    .font(.title3.weight(.medium))
                    .fontDesign(.rounded)
                    .foregroundColor(.white)
                    .position(x: size / 2 + x, y: size / 2 + y)
            }
            
            // Hour numbers - Left side (1-12 for hours 12-24)
            ForEach(1..<13, id: \.self) { hour in
                let displayHour = hour
                let angle = Double(hour + 12) * 15.0 - 90 // Continue from 12, 15 degrees per hour
                let radius = size / 2 - 36
                let x = radius * cos(angle * .pi / 180)
                let y = radius * sin(angle * .pi / 180)
                
                Text("\(displayHour)")
                    .font(.title3.weight(.medium))
                    .fontDesign(.rounded)
                    .foregroundColor(.white)
                    .position(x: size / 2 + x, y: size / 2 + y)
            }
            
            // World clock hands with city labels (non-selected first)
            ForEach(worldClocks.filter { $0.id != selectedCityId }) { clock in
                let time = getTime(for: clock.timeZoneIdentifier)
                // Only show if time is different from local time
                if !showLocalTime || time.hour != localTime.hour || time.minute != localTime.minute {
                    ClockHandWithLabel(
                        cityId: clock.id,
                        cityName: clock.localizedCityName,
                        hour: time.hour,
                        minute: time.minute,
                        size: size,
                        color: .white.opacity(0.25), // Hand colour
                        isSelected: false,
                        isLocal: false,
                        selectedCityId: $selectedCityId,
                        hapticEnabled: hapticEnabled
                    )
                }
            }
            
            // Local time hand (non-selected)
            if showLocalTime && selectedCityId != nil {
                ClockHandWithLabel(
                    cityId: nil,
                    cityName: String(localized: "Local"),
                    hour: localTime.hour,
                    minute: localTime.minute,
                    size: size,
                    color: .yellow,
                    isSelected: false,
                    isLocal: true,
                    selectedCityId: $selectedCityId,
                    hapticEnabled: hapticEnabled
                )
            }
            
            // Selected city hand (rendered last to be on top)
            if let cityId = selectedCityId,
               let clock = worldClocks.first(where: { $0.id == cityId }) {
                let time = getTime(for: clock.timeZoneIdentifier)
                if !showLocalTime || time.hour != localTime.hour || time.minute != localTime.minute {
                    ClockHandWithLabel(
                        cityId: clock.id,
                        cityName: clock.localizedCityName,
                        hour: time.hour,
                        minute: time.minute,
                        size: size,
                        color: .white.opacity(0.25),
                        isSelected: true,
                        isLocal: false,
                        selectedCityId: $selectedCityId,
                        hapticEnabled: hapticEnabled
                    )
                }
            } else if showLocalTime && selectedCityId == nil {
                // Local is selected - render on top
                ClockHandWithLabel(
                    cityId: nil,
                    cityName: String(localized: "Local"),
                    hour: localTime.hour,
                    minute: localTime.minute,
                    size: size,
                    color: .yellow,
                    isSelected: true,
                    isLocal: true,
                    selectedCityId: $selectedCityId,
                    hapticEnabled: hapticEnabled
                )
            }
            
            // Center circle (yellow when Local is selected)
            Circle()
                .fill(selectedCityId == nil ? Color.yellow : Color.white)
                .frame(width: 8, height: 8)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Clock Hand with Label
struct ClockHandWithLabel: View {
    let cityId: UUID?
    let cityName: String
    let hour: Int
    let minute: Int
    let size: CGFloat
    let color: Color
    let isSelected: Bool
    let isLocal: Bool
    @Binding var selectedCityId: UUID?
    let hapticEnabled: Bool
    
    private var angle: Double {
        // 24-hour clock: full rotation = 24 hours
        let hourAngle = Double(hour) * 15.0 // 15 degrees per hour
        let minuteAngle = Double(minute) * 0.25 // 15/60 degrees per minute
        return hourAngle + minuteAngle
    }
    
    // Counter-rotation: flip text 180° when pointing down/left to keep it readable
    private var textCounterRotation: Double {
        // When angle is greater than 180° (bottom half), flip the text
        angle > 180 ? 180 : 0
    }
    
    // Hand color: Local always yellow, others white when selected
    private var handColor: Color {
        if isLocal {
            return .yellow
        }
        return isSelected ? .white : color
    }
    
    var body: some View {
        // Rotate the entire group together so hand and label animate in sync
        ZStack {
            // Hand line - positioned straight up
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(handColor)
                .frame(width: (isSelected || isLocal) ? 2.5 : 1.25, height: max(size / 2 - 95, 0))
                .offset(y: -(size / 4 - 47.5))
                .blendMode((isSelected || isLocal) ? .normal : .plusLighter)
            
            // City label - positioned straight up, at outer end, parallel to hand
            Group {
                if isLocal {
                    // Local: always yellow background with black text
                    Text(cityName)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: 95)
                        .background(Color.yellow, in: Capsule(style: .continuous))
                } else if isSelected {
                    Text(cityName)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: 95)
                        .background(Color.white, in: Capsule(style: .continuous))
                } else {
                    Text(cityName)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: 95)
                        .blendMode(.plusLighter)
                        .background(.thinMaterial, in: Capsule(style: .continuous))
                }
            }
            .contentShape(Capsule())
            .onTapGesture {
                if hapticEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                    impactFeedback.impactOccurred()
                }
                selectedCityId = cityId
            }
            // Rotate 90° to align parallel with hand, then flip if needed for readability
            .rotationEffect(.degrees(-90 + textCounterRotation))
            // Position closer to center
            .offset(y: -(size / 2 - 95))
            .animation(nil, value: angle)
        }
        .rotationEffect(.degrees(angle))
    }
}

// MARK: - Digital Time Display
struct DigitalTimeDisplayView: View {
    let currentDate: Date
    let timeOffset: TimeInterval
    let selectedTimeZone: TimeZone
    let use24HourFormat: Bool
    
    @AppStorage("dateStyle") private var dateStyle = "Relative"
    @AppStorage("additionalTimeDisplay") private var additionalTimeDisplay = "None"
    
    // Calculate additional time display text (follows WorldClock model pattern)
    private func additionalTimeText() -> String {
        switch additionalTimeDisplay {
        case "Time Difference":
            let selectedOffset = selectedTimeZone.secondsFromGMT()
            let localOffset = TimeZone.current.secondsFromGMT()
            let differenceSeconds = selectedOffset - localOffset
            let differenceHours = differenceSeconds / 3600
            if differenceHours == 0 {
                return ""
            } else if differenceHours > 0 {
                return String(format: String(localized: "+%d hours"), differenceHours)
            } else {
                return String(format: String(localized: "%d hours"), differenceHours)
            }
        case "UTC":
            let offsetSeconds = selectedTimeZone.secondsFromGMT()
            let offsetHours = offsetSeconds / 3600
            if offsetHours == 0 {
                return "UTC +0"
            } else if offsetHours > 0 {
                return "UTC +\(offsetHours)"
            } else {
                return "UTC \(offsetHours)"
            }
        default:
            return ""
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Additional time display
            let additionalText = additionalTimeText()
            if !additionalText.isEmpty || additionalTimeDisplay == "UTC" {
                Text(additionalText)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .transition(.blurReplace.combined(with: .move(edge: .bottom)))
                    .blendMode(.plusLighter)
            }
            
            Text({
                let formatter = DateFormatter()
                formatter.timeZone = selectedTimeZone
                formatter.locale = Locale(identifier: "en_US_POSIX")
                if use24HourFormat {
                    formatter.dateFormat = "HH:mm"
                } else {
                    formatter.dateFormat = "h:mm"
                }
                let adjustedDate = currentDate.addingTimeInterval(timeOffset)
                return formatter.string(from: adjustedDate)
            }())
            .font(.system(size: 52))
            .fontWeight(.light)
            .fontDesign(.rounded)
            .monospacedDigit()
            .foregroundColor(.white)
            .contentTransition(.numericText())
            
            // Date display - follows app's dateStyle setting
            Text({
                let adjustedDate = currentDate.addingTimeInterval(timeOffset)
                return adjustedDate.formattedDate(style: dateStyle, timeZone: selectedTimeZone)
            }())
            .font(.body.weight(.medium))
            .foregroundColor(.secondary)
            .blendMode(.plusLighter)
            .contentTransition(.numericText())
        }
    }
}
