//
//  WidgetIntroSheet.swift
//  touchtime
//
//  Introduces the home screen widget with a 1:1 preview of the small
//  City Time widget, defaulting to the local city.
//

import SwiftUI
import VariableBlur

struct WidgetIntroSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @State private var animateIcon = false
    @State private var animateText = false

    // Local city name derived from the current timezone (same as HomeView)
    private var localCityName: String {
        let identifier = TimeZone.current.identifier
        let components = identifier.split(separator: "/")
        let cityName: String
        if components.count >= 2 {
            cityName = components.last!.replacingOccurrences(of: "_", with: " ")
        } else {
            cityName = identifier
        }
        return String(localized: String.LocalizationValue(cityName))
    }

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

                // VariableBlur
                GeometryReader { geom in
                    VariableBlurView(maxBlurRadius: 10, direction: .blurredBottomClearTop)
                        .frame(height: geom.safeAreaInsets.bottom + 100)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .ignoresSafeArea()
                }

                VStack(spacing: 0) {
                Spacer()

                TimelineView(.everyMinute) { context in
                    CityWidgetPreview(
                        date: context.date,
                        cityName: localCityName,
                        timeZoneIdentifier: TimeZone.current.identifier,
                        use24Hour: use24HourFormat
                    )
                    // Blurred sky glow behind the widget, same treatment as
                    // the local time row at the top of HomeView
                    .background {
                        SkyBackgroundView(
                            date: context.date,
                            timeZoneIdentifier: TimeZone.current.identifier,
                            appliesCardChrome: false
                        )
                        .frame(width: 300, height: 300)
                        .blur(radius: 50)
                        .opacity(0.35)
                        .allowsHitTesting(false)
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

                Spacer()

                Button {
                    if hapticEnabled {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                    dismiss()
                    // Send the app to the Home Screen so the user can add the widget
                    UIApplication.shared.perform(NSSelectorFromString("suspend"))
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "apps.iphone")
                        Text("Add to Home Screen")
                    }
                    .font(.headline)
                    .foregroundStyle(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .contentShape(Capsule(style: .continuous))
                    .glassEffect(.clear.interactive().tint(.primary), in: Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom)
                }
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
            }
        }
    }
}

// 1:1 replica of the small City Time widget (CityComplicationWidgetView):
// city name on top, sunrise & sunset complication in the center,
// time at the bottom, glass background.
private struct CityWidgetPreview: View {
    let date: Date
    let cityName: String
    let timeZoneIdentifier: String
    let use24Hour: Bool

    private static let widgetSize: CGFloat = 164
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
            SunriseSunsetIndicator(
                date: date,
                timeZone: timeZone,
                size: Self.complicationSize,
                useMaterialBackground: true
            )
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
        .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
    }
}

#Preview {
    WidgetIntroSheet()
}
