//
//  WidgetIntroSheet.swift
//  touchtime
//
//  Introduces the home screen widget with a 1:1 preview of the small
//  City Time widget, defaulting to the local city.
//

import SwiftUI

struct WidgetIntroSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("hapticEnabled") private var hapticEnabled = true

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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                TimelineView(.everyMinute) { context in
                    CityWidgetPreview(
                        date: context.date,
                        cityName: localCityName,
                        timeZoneIdentifier: TimeZone.current.identifier,
                        use24Hour: use24HourFormat
                    )
                }

                Text("Check the time in your favourite cities at a glance and show more information")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .multilineTextAlignment(.center)
                    .padding(.top, 32)
                    .padding(.horizontal, 24)

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
                    Link(destination: URL(string: "https://support.apple.com/en-gb/118610")!) {
                        Image(systemName: "questionmark")
                    }
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
    private static let cornerRadius: CGFloat = 24
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
                size: Self.complicationSize
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
