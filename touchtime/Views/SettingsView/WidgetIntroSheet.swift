//
//  WidgetIntroSheet.swift
//  touchtime
//
//  Introduces the home screen widgets with 1:1 previews of the small
//  City Time widget, the medium World Cities widget, the small Daylight
//  widget (in its transparent home screen appearance), the small
//  Moon Phase widget (with the phase name shown) and the small Moon
//  Calendar widget, shown in a swipeable carousel.
//

import SwiftUI
import MoonKit
import CoreLocation

// Mirrors WidgetComplicationKind from the widget extension (not visible to
// the app target): the five complications the City Time widget supports.
private enum WidgetPreviewComplication {
    case analogClock
    case sunPosition
    case sunriseSunset
    case sunAzimuth
    case solarCurve
}

// The five pages of the widget preview carousel
private enum WidgetPreviewPage: CaseIterable {
    case small
    case medium
    case daylight
    case moonPhase
    case moonCalendar

    // Matches each widget's configurationDisplayName in the extension
    var widgetName: String {
        switch self {
        case .small: String(localized: "City Time")
        case .medium: String(localized: "World Cities")
        case .daylight: String(localized: "Daylight")
        case .moonPhase: String(localized: "Moon Phase")
        case .moonCalendar: String(localized: "Moon Calendar")
        }
    }
}

// Shared by both previews: matches the height of a real home screen widget
private let widgetPreviewHeight: CGFloat = 164

struct WidgetIntroSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @State private var animateIcon = false
    @State private var animateText = false
    // The later pages and the page dots come in after the small widget
    @State private var animateTrailingWidgets = false
    @State private var currentPage: WidgetPreviewPage? = .small
    @State private var showWidgetSupport = false
    // Global frame of the carousel; swipes starting inside it are
    // already handled by the ScrollView itself
    @State private var carouselFrame: CGRect = .zero

    // Carousel layout: pages are inset so the medium widget peeks in
    // from the trailing edge, hinting that the carousel can be swiped.
    private static let pageInset: CGFloat = 40
    private static let pageSpacing: CGFloat = 12

    // Apple's widget guide, localized to the language the app is running in
    private var widgetSupportURL: URL {
        let region: String
        switch Bundle.main.preferredLocalizations.first {
        case "zh-Hans":
            region = "zh-cn"
        case "zh-Hant":
            region = "zh-tw"
        default:
            region = "en-gb"
        }
        return URL(string: "https://support.apple.com/\(region)/118610")!
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Dot matrix background, same treatment as OnboardingView
                DotMatrixOverlay()
                    .ignoresSafeArea()
                    .blendMode(.plusLighter)
                    .opacity(0.75)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                Spacer()

                TimelineView(.everyMinute) { context in
                    GeometryReader { geometry in
                        let pageWidth = max(geometry.size.width - Self.pageInset * 2, widgetPreviewHeight)
                        // Same proportions as a real home screen medium widget:
                        // two smalls plus the column gap, clamped to the sheet.
                        // The lower bound guards against the zero-width first
                        // layout pass, which would push negative sizes into
                        // the complication views (same clamp as pageWidth).
                        let mediumWidth = max(min(widgetPreviewHeight * 2 + 22, geometry.size.width - 32), widgetPreviewHeight)

                        ScrollView(.horizontal) {
                            HStack(spacing: Self.pageSpacing) {
                                // Small City Time widget
                                CityWidgetPreview(
                                    date: context.date,
                                    cityName: String(localized: "City"),
                                    timeZoneIdentifier: TimeZone.current.identifier,
                                    use24Hour: use24HourFormat,
                                    complication: .sunriseSunset
                                )
                                // Entrance animation, same as the app icon in OnboardingView
                                .brightness(animateIcon ? 0 : 0.50)
                                .blur(radius: animateIcon ? 0 : 25)
                                .scaleEffect(animateIcon ? 1.0 : 0.5)
                                .opacity(animateIcon ? 1.0 : 0.0)
                                .offset(y: animateText ? 0 : 50)
                                .animation(
                                    .bouncy(duration: 1.0), value: animateIcon
                                )
                                .frame(width: pageWidth)
                                .id(WidgetPreviewPage.small)

                                // Medium World Cities widget, peeking in after the small one
                                WorldCitiesWidgetPreview(
                                    date: context.date,
                                    use24Hour: use24HourFormat,
                                    complication: .analogClock,
                                    width: mediumWidth
                                )
                                .brightness(animateTrailingWidgets ? 0 : 0.50)
                                .blur(radius: animateTrailingWidgets ? 0 : 25)
                                .scaleEffect(animateTrailingWidgets ? 1.0 : 0.5)
                                .opacity(animateTrailingWidgets ? 1.0 : 0.0)
                                .offset(y: animateTrailingWidgets ? 0 : 50)
                                .animation(
                                    .bouncy(duration: 1.0), value: animateTrailingWidgets
                                )
                                .frame(width: pageWidth)
                                .id(WidgetPreviewPage.medium)

                                // Small Daylight widget in its transparent home screen
                                // appearance, revealed with the medium one
                                DaylightWidgetPreview(
                                    date: context.date,
                                    timeZoneIdentifier: TimeZone.current.identifier,
                                    use24Hour: use24HourFormat
                                )
                                .brightness(animateTrailingWidgets ? 0 : 0.50)
                                .blur(radius: animateTrailingWidgets ? 0 : 25)
                                .scaleEffect(animateTrailingWidgets ? 1.0 : 0.5)
                                .opacity(animateTrailingWidgets ? 1.0 : 0.0)
                                .offset(y: animateTrailingWidgets ? 0 : 50)
                                .animation(
                                    .bouncy(duration: 1.0), value: animateTrailingWidgets
                                )
                                .frame(width: pageWidth)
                                .id(WidgetPreviewPage.daylight)

                                // Small Moon Phase widget with the phase name
                                // shown, revealed with the other trailing pages
                                MoonPhaseWidgetPreview(date: context.date)
                                    .brightness(animateTrailingWidgets ? 0 : 0.50)
                                    .blur(radius: animateTrailingWidgets ? 0 : 25)
                                    .scaleEffect(animateTrailingWidgets ? 1.0 : 0.5)
                                    .opacity(animateTrailingWidgets ? 1.0 : 0.0)
                                    .offset(y: animateTrailingWidgets ? 0 : 50)
                                    .animation(
                                        .bouncy(duration: 1.0), value: animateTrailingWidgets
                                    )
                                    .frame(width: pageWidth)
                                    .id(WidgetPreviewPage.moonPhase)

                                // Small Moon Calendar widget: the whole month's
                                // moon phases with a dot under today, revealed
                                // with the other trailing pages
                                MoonCalendarWidgetPreview(date: context.date)
                                    .brightness(animateTrailingWidgets ? 0 : 0.50)
                                    .blur(radius: animateTrailingWidgets ? 0 : 25)
                                    .scaleEffect(animateTrailingWidgets ? 1.0 : 0.5)
                                    .opacity(animateTrailingWidgets ? 1.0 : 0.0)
                                    .offset(y: animateTrailingWidgets ? 0 : 50)
                                    .animation(
                                        .bouncy(duration: 1.0), value: animateTrailingWidgets
                                    )
                                    .frame(width: pageWidth)
                                    .id(WidgetPreviewPage.moonCalendar)
                            }
                            .scrollTargetLayout()
                        }
                        .contentMargins(.horizontal, Self.pageInset, for: .scrollContent)
                        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                        .scrollPosition(id: $currentPage)
                        .scrollIndicators(.hidden)
                        .scrollClipDisabled()
                    }
                    .frame(height: widgetPreviewHeight)
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .global)
                    } action: { frame in
                        carouselFrame = frame
                    }
                    // One shared sky glow behind the carousel; it stays put
                    // while the pages scroll over it.
                    .background {
                        skyGlow(date: context.date)
                            .opacity(animateIcon ? 1.0 : 0.0)
                            .animation(.bouncy(duration: 1.0), value: animateIcon)
                    }
                }

                Text("Check the time in your favourite cities at a glance on the Home Screen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
                    .padding(.horizontal, 24)
                    // Entrance animation, same as the description in OnboardingView
                    .blur(radius: animateText ? 0 : 10)
                    .opacity(animateText ? 1.0 : 0.0)
                    .offset(y: animateText ? 0 : 75)
                    .animation(
                        .smooth(duration: 1.0), value: animateText
                    )

                // Page dots, revealed together with the later pages
                HStack(spacing: 8) {
                    ForEach(WidgetPreviewPage.allCases, id: \.self) { page in
                        Circle()
                            .fill(.primary)
                            .frame(width: 7, height: 7)
                            .opacity(currentPage == page ? 0.9 : 0.3)
                    }
                }
                .blendMode(.plusLighter)
                .padding(.top, 20)
                .blur(radius: animateTrailingWidgets ? 0 : 10)
                .opacity(animateTrailingWidgets ? 1.0 : 0.0)
                .animation(.smooth(duration: 1.0), value: animateTrailingWidgets)
                .animation(.smooth(duration: 0.3), value: currentPage)

                // Current widget's name in a glass capsule, swapping with a
                // blur as the carousel turns; revealed with the page dots.
                Text((currentPage ?? .small).widgetName)
                    .font(.subheadline.weight(.semibold))
                    .transition(.blurReplace)
                    .id(currentPage)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassEffect(.clear, in: Capsule(style: .continuous))
                    .padding(.top, 24)
                    .blur(radius: animateTrailingWidgets ? 0 : 10)
                    .opacity(animateTrailingWidgets ? 1.0 : 0.0)
                    .animation(.smooth(duration: 1.0), value: animateTrailingWidgets)
                    .animation(.smooth(duration: 0.5), value: currentPage)

                Spacer()

                // Use your current location, same as OnboardingView
                HStack {
                    Image(systemName: "location.fill")
                        .font(.footnote.weight(.semibold))
                    Text(String(localized: "Use your current location"))
                        .font(.footnote.weight(.medium))
                }
                .foregroundStyle(.secondary)
                .blendMode(.plusLighter)
                .padding(.bottom, 24)

                Button {
                    if hapticEnabled {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                    dismiss()
                    // Send the app to the Home Screen so the user can add the widget
                    UIApplication.shared.perform(NSSelectorFromString("suspend"))
                } label: {
                    Text("Add to Home Screen")
                        .font(.headline)
                        .foregroundStyle(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                        .contentShape(Capsule(style: .continuous))
                        .glassEffect(.clear.interactive().tint(.primary), in: Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)
                }
            }
            // Whole sheet is swipeable, not just the carousel: horizontal
            // swipes anywhere else also turn the page. Swipes starting on
            // the carousel are left to the ScrollView itself.
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .global)
                    .onEnded { value in
                        guard !carouselFrame.contains(value.startLocation) else { return }
                        let dx = value.translation.width
                        guard abs(dx) > abs(value.translation.height), abs(dx) > 30 else { return }
                        let forward = layoutDirection == .rightToLeft ? dx > 0 : dx < 0
                        turnPage(by: forward ? 1 : -1)
                    }
            )
            // Light haptic whenever the carousel lands on a new page,
            // whether swiped directly or from anywhere else on the sheet
            .onChange(of: currentPage) { oldValue, newValue in
                guard hapticEnabled, oldValue != nil, newValue != nil else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .navigationTitle("Widgets")
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

                // Tips: Apple guide on adding widgets to the Home Screen
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if hapticEnabled {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        showWidgetSupport = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
            .onAppear {
                // Defer one runloop so the sheet's first layout settles;
                // otherwise the animation starts from the pre-layout frame
                // (top-leading zero rect) and flies in from the corner.
                DispatchQueue.main.async {
                    animateIcon = true
                    animateText = true
                }
                // The medium widget peeks in once the small one has settled
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                    animateTrailingWidgets = true
                }
            }
            .sheet(isPresented: $showWidgetSupport) {
                SafariView(url: widgetSupportURL)
                    .ignoresSafeArea()
            }
        }
    }

    // Advance the carousel by the given number of pages, clamped to the ends
    private func turnPage(by delta: Int) {
        let all = WidgetPreviewPage.allCases
        let index = all.firstIndex(of: currentPage ?? .small) ?? 0
        let newIndex = min(max(index + delta, 0), all.count - 1)
        guard newIndex != index else { return }
        withAnimation(.smooth(duration: 0.4)) {
            currentPage = all[newIndex]
        }
    }

    // Blurred sky glow behind the widget previews, same treatment as
    // the local time row at the top of HomeView
    private func skyGlow(date: Date) -> some View {
        SkyBackgroundView(
            date: date,
            timeZoneIdentifier: TimeZone.current.identifier,
            appliesCardChrome: false
        )
        .frame(width: 300, height: 300)
        .blur(radius: 100)
        .opacity(0.60)
        .allowsHitTesting(false)
    }
}

// 1:1 replica of the small City Time widget (CityComplicationWidgetView):
// city name on top, the chosen complication in the center,
// time at the bottom, glass background.
private struct CityWidgetPreview: View {
    let date: Date
    let cityName: String
    let timeZoneIdentifier: String
    let use24Hour: Bool
    let complication: WidgetPreviewComplication

    // Same customisations the real widget mirrors from the app
    @AppStorage("analogClockShowScale") private var analogClockShowScale = false
    @AppStorage("solarCurveShowSun") private var solarCurveShowSun = false

    private static let widgetSize: CGFloat = widgetPreviewHeight
    private static let cornerRadius: CGFloat = 28
    private static let complicationSize: CGFloat = 80

    private var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = use24Hour ? "HH:mm" : "h:mm"
        return formatter.string(from: date)
    }

    var body: some View {
        ZStack {
            complicationView
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.10), lineWidth: 1.50)
                        .blendMode(.plusLighter)
                }
                .frame(width: Self.complicationSize, height: Self.complicationSize)

            VStack {
                Text(cityName)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 8)

                Spacer(minLength: 0)

                Text(timeString)
                    .font(.system(size: 15, weight: .medium))
                    .monospacedDigit()
                    .transition(.blurReplace)
                    .id(timeString)
            }
        }
        .animation(.smooth(duration: 0.5), value: timeString)
        .foregroundStyle(.white)
        .padding(14)
        .frame(width: Self.widgetSize, height: Self.widgetSize)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
    }

    // Same complications as CityComplicationWidgetView, without any
    // background fill: the stroke overlay above is the only chrome.
    @ViewBuilder
    private var complicationView: some View {
        let size = Self.complicationSize
        switch complication {
        case .analogClock:
            AnalogClockView(date: date, size: size, timeZone: timeZone, showBackground: false, showScale: analogClockShowScale)
        case .sunPosition:
            SunPositionIndicator(date: date, timeZone: timeZone, size: size, showBackground: false)
        case .sunriseSunset:
            SunriseSunsetIndicator(date: date, timeZone: timeZone, size: size, showBackground: false)
        case .sunAzimuth:
            SunAzimuthIndicator(date: date, timeZone: timeZone, size: size, showBackground: false)
        case .solarCurve:
            SolarCurve(date: date, timeZone: timeZone, size: size, showBackground: false, showSun: solarCurveShowSun)
        }
    }
}

// 1:1 replica of the medium World Cities widget (WorldCitiesWidgetView):
// four city columns side by side, each showing the chosen complication
// with name / time below, glass background.
private struct WorldCitiesWidgetPreview: View {
    let date: Date
    let use24Hour: Bool
    let complication: WidgetPreviewComplication
    let width: CGFloat

    private static let cornerRadius: CGFloat = 28

    private struct PreviewCity: Identifiable {
        let name: String
        let timeZoneIdentifier: String
        var id: String { timeZoneIdentifier }
    }

    // Default cities shown in the preview
    private static let cities: [PreviewCity] = [
        PreviewCity(name: String(localized: "London"), timeZoneIdentifier: "Europe/London"),
        PreviewCity(name: String(localized: "Shanghai"), timeZoneIdentifier: "Asia/Shanghai"),
        PreviewCity(name: String(localized: "New York"), timeZoneIdentifier: "America/New_York"),
        PreviewCity(name: String(localized: "Tokyo"), timeZoneIdentifier: "Asia/Tokyo")
    ]

    // Same 68pt complication as the real widget, shrunk evenly when the
    // preview is narrower than a real medium widget.
    private var complicationSize: CGFloat {
        min(68, (width - 32 - 24) / 4)
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Self.cities) { city in
                WorldCityPreviewColumn(
                    date: date,
                    cityName: city.name,
                    timeZoneIdentifier: city.timeZoneIdentifier,
                    use24Hour: use24Hour,
                    complication: complication,
                    size: complicationSize,
                    // The real widget defaults its selection to the first city
                    isSelected: city.id == Self.cities.first?.id
                )
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(width: width, height: widgetPreviewHeight)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
    }
}

// Mirrors WorldCityColumn from the widget extension
private struct WorldCityPreviewColumn: View {
    let date: Date
    let cityName: String
    let timeZoneIdentifier: String
    let use24Hour: Bool
    let complication: WidgetPreviewComplication
    let size: CGFloat
    let isSelected: Bool

    // Same customisations the real widget mirrors from the app
    @AppStorage("analogClockShowScale") private var analogClockShowScale = false
    @AppStorage("solarCurveShowSun") private var solarCurveShowSun = false

    private var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = use24Hour ? "HH:mm" : "h:mm"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 8) {
            complicationView
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.10), lineWidth: 1.50)
                        .blendMode(.plusLighter)
                }
                .frame(width: size, height: size)

            VStack(spacing: 0) {
                Text(cityName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(timeString)
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .transition(.blurReplace)
                    .id(timeString)

                // Selection indicator: a small dot under the selected city's
                // time. Kept in the layout (opacity 0) so columns stay aligned.
                Circle()
                    .frame(width: 5, height: 5)
                    .padding(.top, 5)
                    .opacity(isSelected ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .animation(.smooth(duration: 0.5), value: timeString)
    }

    // Same complications as WorldCityColumn, without any background
    // fill, matching the small widget preview.
    @ViewBuilder
    private var complicationView: some View {
        switch complication {
        case .analogClock:
            AnalogClockView(date: date, size: size, timeZone: timeZone, showBackground: false, showScale: analogClockShowScale)
        case .sunPosition:
            SunPositionIndicator(date: date, timeZone: timeZone, size: size, showBackground: false)
        case .sunriseSunset:
            SunriseSunsetIndicator(date: date, timeZone: timeZone, size: size, showBackground: false)
        case .sunAzimuth:
            SunAzimuthIndicator(date: date, timeZone: timeZone, size: size, showBackground: false)
        case .solarCurve:
            SolarCurve(date: date, timeZone: timeZone, size: size, showBackground: false, showSun: solarCurveShowSun)
        }
    }
}

// 1:1 replica of the small Daylight widget (DaylightWidgetView) as it looks
// with the transparent home screen appearance: the monochrome opacity-band
// sky ring (shared DaylightRing) on glass, time and date in the center.
private struct DaylightWidgetPreview: View {
    let date: Date
    let timeZoneIdentifier: String
    let use24Hour: Bool

    private static let widgetSize: CGFloat = widgetPreviewHeight
    private static let cornerRadius: CGFloat = 28
    // Same 12pt content inset as the real widget
    private static let contentInset: CGFloat = 12

    private var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = use24Hour ? "HH:mm" : "h:mm"
        return formatter.string(from: date)
    }

    // City-local "Sat 25": abbreviated weekday + day number, ordered
    // per locale (e.g. zh renders "25 周六"). Matches the real widget.
    private var dateString: String {
        date.formatted(
            Date.FormatStyle(timeZone: timeZone)
                .weekday(.abbreviated)
                .day()
        )
    }

    var body: some View {
        // Same proportions as the real widget: ring width is 20% of the
        // side, center text fits in 75% of the hole.
        let side = Self.widgetSize - Self.contentInset * 2
        let ringWidth = side * 0.20
        let holeDiameter = side - ringWidth * 2

        ZStack {
            DaylightRing(
                date: date,
                timeZoneIdentifier: timeZoneIdentifier,
                size: side,
                ringWidth: ringWidth,
                monochrome: true
            )

            VStack(spacing: 0) {
                Text(timeString)
                    .font(.system(size: 15, weight: .medium))
                    .monospacedDigit()
                    .transition(.blurReplace)
                    .id(timeString)

                Text(dateString)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: holeDiameter * 0.75)
        }
        .animation(.smooth(duration: 0.5), value: timeString)
        .foregroundStyle(.white)
        .frame(width: Self.widgetSize, height: Self.widgetSize)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
    }
}

// 1:1 replica of the small Moon Phase widget (MoonPhaseWidgetView) in its
// "Show Moon Phase Name" configuration: the current moon rendered large in
// the center with the same grayscale + plus-lighter treatment as the app's
// Moon Phase sheet, and the phase name at the bottom.
private struct MoonPhaseWidgetPreview: View {
    let date: Date

    private static let widgetSize: CGFloat = widgetPreviewHeight
    private static let cornerRadius: CGFloat = 28
    // Same 16pt content inset as the real widget
    private static let contentInset: CGFloat = 16
    // Same crop as the real widget: the moon disc only spans ~86% of the
    // source photo, the rest is black margin. Scaling inside the circular
    // clip crops that margin away.
    private static let discCropScale: CGFloat = 1.18

    private struct MoonInfo {
        let imageName: String
        let phaseName: String
    }

    // Memoized per day: MoonKit recomputes rise/set times for every new
    // day, too slow to redo on every minute tick of the TimelineView.
    private static var cachedInfo: (day: Date, info: MoonInfo)?

    // Same as MoonPhaseWidgetProvider in the widget extension: the moon's
    // age (image and phase name) is the same for every city at a given
    // instant, so the device time zone is fine. Coordinates only feed
    // MoonKit's internal math.
    private static func moonInfo(for date: Date) -> MoonInfo {
        let day = Calendar.current.startOfDay(for: date)
        if let cached = cachedInfo, cached.day == day {
            return cached.info
        }

        let timeZone = TimeZone.current
        let coordinate = TimeZoneCoordinates.getCoordinate(for: timeZone.identifier)
        let location = CLLocation(
            latitude: coordinate?.latitude ?? 51.5074,
            longitude: coordinate?.longitude ?? -0.1278
        )

        let moon = Moon(location: location, timeZone: timeZone)
        moon.setDate(date)

        // Age wraps at the end of the synodic cycle (~29.5 days) back to new moon
        let imageIndex = Int(moon.ageOfTheMoonInDays.rounded()) % 30

        let info = MoonInfo(
            imageName: String(format: "moon_age_%02d", imageIndex),
            phaseName: phaseName(for: moon.currentMoonPhase)
        )
        cachedInfo = (day, info)
        return info
    }

    private static func phaseName(for phase: MoonKit.MoonPhase) -> String {
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
            return String(localized: "Moon Phase")
        }
    }

    var body: some View {
        let info = Self.moonInfo(for: date)

        VStack(spacing: 8) {
            Image(info.imageName)
                .resizable()
                .scaledToFit()
                .scaleEffect(Self.discCropScale)
                .clipShape(Circle())
                .grayscale(1)
                .blendMode(.plusLighter)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(info.phaseName)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
        }
        .padding(Self.contentInset)
        .foregroundStyle(.white)
        .frame(width: Self.widgetSize, height: Self.widgetSize)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
    }
}

// 1:1 replica of the small Moon Calendar widget (MoonCalendarWidgetView):
// the current month as a grid of moon phases in the same Monday-first
// weekday-aligned layout as the app's Moon Phase calendar — no weekday
// headers or day numbers — with a small dot under today's moon.
private struct MoonCalendarWidgetPreview: View {
    let date: Date

    private static let widgetSize: CGFloat = widgetPreviewHeight
    private static let cornerRadius: CGFloat = 28
    // Same 14pt content inset as the real widget
    private static let contentInset: CGFloat = 14
    // Same crop as the real widget: the moon disc only spans ~86% of the
    // source photo, the rest is black margin. Scaling inside the circular
    // clip crops that margin away.
    private static let discCropScale: CGFloat = 1.18

    private static let columnSpacing: CGFloat = 4
    private static let rowSpacing: CGFloat = 2
    private static let dotGap: CGFloat = 2
    private static let dotSize: CGFloat = 3

    private struct MonthInfo {
        /// nil for the blank slots before the 1st, then one image name per day.
        let cells: [String?]
        let todayIndex: Int
    }

    // Memoized per day: the grid only changes at midnight, no need to
    // recompute the whole month on every minute tick of the TimelineView.
    private static var cachedInfo: (day: Date, info: MonthInfo)?

    // Same math as MoonCalendarWidgetProvider in the widget extension:
    // day-start ages via the lightweight MoonAstronomy, rounded to the
    // moon_age_00...29 assets, Monday-first leading blanks.
    private static func monthInfo(for date: Date) -> MonthInfo {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        if let cached = cachedInfo, cached.day == day {
            return cached.info
        }

        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: date)
        ) ?? date
        let dayCount = calendar.range(of: .day, in: .month, for: date)?.count ?? 30

        let weekdayOfFirst = calendar.component(.weekday, from: monthStart) // 1 = Sunday
        let leadingBlanks = (weekdayOfFirst + 5) % 7

        var cells: [String?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<dayCount {
            let dayStart = calendar.date(byAdding: .day, value: offset, to: monthStart) ?? monthStart
            let age = MoonAstronomy.snapshot(for: dayStart).ageDays
            cells.append(String(format: "moon_age_%02d", Int(age.rounded()) % 30))
        }

        let info = MonthInfo(
            cells: cells,
            todayIndex: leadingBlanks + calendar.component(.day, from: date) - 1
        )
        cachedInfo = (day, info)
        return info
    }

    private static func rows(for info: MonthInfo) -> [[(index: Int, imageName: String?)]] {
        let cells = info.cells.enumerated().map { (index: $0.offset, imageName: $0.element) }
        return stride(from: 0, to: cells.count, by: 7).map {
            Array(cells[$0..<min($0 + 7, cells.count)])
        }
    }

    var body: some View {
        let info = Self.monthInfo(for: date)

        // Same space-driven cell sizing as the real widget: weekday-aligned
        // months span 4 to 6 rows, so the cells adapt instead of overflowing.
        GeometryReader { geometry in
            let rows = Self.rows(for: info)
            let rowCount = CGFloat(rows.count)
            let cellWidth = (geometry.size.width - Self.columnSpacing * 6) / 7
            let cellHeight = (geometry.size.height - Self.rowSpacing * (rowCount - 1)) / rowCount
            let moonSize = min(cellWidth, cellHeight - Self.dotGap - Self.dotSize)

            VStack(spacing: Self.rowSpacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: Self.columnSpacing) {
                        ForEach(row, id: \.index) { cell in
                            VStack(spacing: Self.dotGap) {
                                if let imageName = cell.imageName {
                                    Image(imageName)
                                        .resizable()
                                        .scaledToFit()
                                        .scaleEffect(Self.discCropScale)
                                        .clipShape(Circle())
                                        .grayscale(1)
                                        .blendMode(.plusLighter)
                                        .frame(width: moonSize, height: moonSize)
                                } else {
                                    // Blank slot before the 1st of the month
                                    Color.clear
                                        .frame(width: moonSize, height: moonSize)
                                }

                                // Today marker; kept in every cell (opacity 0
                                // elsewhere) so all rows keep the same height.
                                Circle()
                                    .fill(.white)
                                    .frame(width: Self.dotSize, height: Self.dotSize)
                                    .opacity(cell.index == info.todayIndex ? 1 : 0)
                            }
                            .frame(width: cellWidth, height: cellHeight)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .padding(Self.contentInset)
        .frame(width: Self.widgetSize, height: Self.widgetSize)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
    }
}

#Preview {
    WidgetIntroSheet()
}
