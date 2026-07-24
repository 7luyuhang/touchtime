//
//  WidgetIntroSheet.swift
//  touchtime
//
//  Introduces the home screen widgets with 1:1 previews of the small
//  City Time widget and the medium World Cities widget, shown in a
//  swipeable carousel. Tapping a preview cycles through the
//  complications the widget supports.
//

import SwiftUI

// Mirrors WidgetComplicationKind from the widget extension (not visible to
// the app target): the five complications the City Time widget supports.
private enum WidgetPreviewComplication: CaseIterable {
    case analogClock
    case sunPosition
    case sunriseSunset
    case sunAzimuth
    case solarCurve

    var next: WidgetPreviewComplication {
        let all = Self.allCases
        let index = all.firstIndex(of: self)!
        return all[(index + 1) % all.count]
    }
}

// The two pages of the widget preview carousel
private enum WidgetPreviewPage: CaseIterable {
    case small
    case medium
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
    // The medium widget and the page dots come in after the small widget
    @State private var animateMediumWidget = false
    @State private var currentPage: WidgetPreviewPage? = .small
    // Widget defaults; tapping a preview cycles through all five
    @State private var complication: WidgetPreviewComplication = .sunriseSunset
    @State private var mediumComplication: WidgetPreviewComplication = .analogClock
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
                        let mediumWidth = min(widgetPreviewHeight * 2 + 22, geometry.size.width - 32)

                        ScrollView(.horizontal) {
                            HStack(spacing: Self.pageSpacing) {
                                // Small City Time widget
                                CityWidgetPreview(
                                    date: context.date,
                                    cityName: String(localized: "City"),
                                    timeZoneIdentifier: TimeZone.current.identifier,
                                    use24Hour: use24HourFormat,
                                    complication: complication
                                )
                                .onTapGesture {
                                    if hapticEnabled {
                                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                    }
                                    withAnimation(.smooth(duration: 0.5)) {
                                        complication = complication.next
                                    }
                                }
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

                                // Medium World Cities widget, revealed after the small one
                                WorldCitiesWidgetPreview(
                                    date: context.date,
                                    use24Hour: use24HourFormat,
                                    complication: mediumComplication,
                                    width: mediumWidth
                                )
                                .onTapGesture {
                                    if hapticEnabled {
                                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                    }
                                    withAnimation(.smooth(duration: 0.5)) {
                                        mediumComplication = mediumComplication.next
                                    }
                                }
                                .brightness(animateMediumWidget ? 0 : 0.50)
                                .blur(radius: animateMediumWidget ? 0 : 25)
                                .scaleEffect(animateMediumWidget ? 1.0 : 0.5)
                                .opacity(animateMediumWidget ? 1.0 : 0.0)
                                .offset(y: animateMediumWidget ? 0 : 50)
                                .animation(
                                    .bouncy(duration: 1.0), value: animateMediumWidget
                                )
                                .frame(width: pageWidth)
                                .id(WidgetPreviewPage.medium)
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

                // Page dots, revealed together with the medium widget
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
                .blur(radius: animateMediumWidget ? 0 : 10)
                .opacity(animateMediumWidget ? 1.0 : 0.0)
                .animation(.smooth(duration: 1.0), value: animateMediumWidget)
                .animation(.smooth(duration: 0.3), value: currentPage)

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
                    Link(destination: widgetSupportURL) {
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
                    animateMediumWidget = true
                }
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
                .transition(.blurReplace)
                .id(complication)

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
        .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        // Make the whole widget tappable, not just the opaque content inside
        .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
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
                    size: complicationSize
                )
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(width: width, height: widgetPreviewHeight)
        .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        // Make the whole widget tappable, not just the opaque content inside
        .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
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
                .transition(.blurReplace)
                .id(complication)

            VStack(spacing: 0) {
                Text(cityName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(timeString)
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .transition(.blurReplace)
                    .id(timeString)
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

#Preview {
    WidgetIntroSheet()
}
