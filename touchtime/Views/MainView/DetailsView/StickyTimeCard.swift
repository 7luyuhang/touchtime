//
//  StickyTimeCard.swift
//  touchtime
//
//  Created on 15/10/2026.
//

import SwiftUI
import WeatherKit

/// The city's time, pinned above the content at the large detent.
struct StickyTimeCard: View {
    let cityName: String
    let timeZoneIdentifier: String
    let currentDate: Date
    let timeOffset: TimeInterval
    let weather: CurrentWeather?
    let skyWeatherCondition: WeatherCondition?
    let dateFormat: DetailsDateFormat

    @AppStorage("showWeather") private var showWeather = false
    @AppStorage("useCelsius") private var useCelsius = true
    @AppStorage("showSkyDot") private var showSkyDot = true
    @AppStorage("dateStyle") private var dateStyle = "Relative"

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            ZStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Top row: Weather and Date
                    HStack {
                        if cityName == String(localized: "Local") {
                            Image(systemName: "location.fill")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .blendMode(.plusLighter)
                        }

                        Spacer()

                        // Weather display
                        if showWeather, let weather {
                            WeatherView(
                                weather: weather,
                                useCelsius: useCelsius
                            )
                            .transition(.blurReplace())
                        }

                        Text(currentDate.formattedDate(
                            style: dateStyle,
                            timeZoneIdentifier: timeZoneIdentifier,
                            timeOffset: timeOffset
                        ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)
                        .contentTransition(.numericText())
                    }
                    .animation(.spring(), value: showWeather)
                    .animation(.spring(), value: weather)

                    // Bottom row: City name and Time (baseline aligned)
                    HStack(alignment: .lastTextBaseline) {
                        Text(cityName)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentTransition(.numericText())

                        Spacer()

                        Text(dateFormat.timeWithoutPeriod(currentDate.addingTimeInterval(timeOffset)))
                            .font(.system(size: 36))
                            .fontWeight(.light)
                            .fontDesign(.rounded)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                }
                .padding()
                .padding(.bottom, -4)
            }
            .background(
                showSkyDot ?
                StickyTimeSky(
                    date: currentDate.addingTimeInterval(timeOffset),
                    timeZoneIdentifier: timeZoneIdentifier,
                    weatherCondition: skyWeatherCondition
                ) : nil
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
            .glassEffect(.clear.interactive(), in:
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
            .animation(.spring(), value: showSkyDot)
        }
    }
}

/// The sky behind the sticky time card. Its rain and stars land out of step
/// with the card as the card changes size, as when the iPhone Duo's panes
/// resize: the stars jump straight to where the final size puts them while the
/// card's outline is still on its way. So a plain sky stands in until the size
/// settles.
private struct StickyTimeSky: View {
    let date: Date
    let timeZoneIdentifier: String
    let weatherCondition: WeatherCondition?

    @State private var isResizing = false
    @State private var resizeCount = 0

    var body: some View {
        let skyColorGradient = SkyColorGradient(
            date: date,
            timeZoneIdentifier: timeZoneIdentifier,
            weatherCondition: weatherCondition
        )
        // A plain sky keeps pace with the card on its own
        let needsStandIn = (weatherCondition?.rainIntensity ?? 0) > 0 || skyColorGradient.starOpacity > 0

        ZStack {
            if needsStandIn {
                CoreAnimationGradient(colors: skyColorGradient.colorsOverBlack(opacity: 0.65))
            }

            SkyBackgroundView(
                date: date,
                timeZoneIdentifier: timeZoneIdentifier,
                weatherCondition: weatherCondition,
                showRainEffect: true,
                drawsOverBlack: true
            )
            .opacity(needsStandIn && isResizing ? 0 : 1)
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { oldSize, newSize in
            guard oldSize != newSize else { return }
            isResizing = true
            resizeCount += 1
        }
        // Back to the rain or stars once the size has held still for a moment
        .task(id: resizeCount) {
            guard isResizing else { return }
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                isResizing = false
            }
        }
    }
}

/// A top-to-bottom gradient drawn by Core Animation. It keeps pace with a
/// system-animated resize, where SwiftUI's own drawing can take the final
/// size up front.
private struct CoreAnimationGradient: UIViewRepresentable {
    let colors: [Color]

    func makeUIView(context: Context) -> GradientView {
        let view = GradientView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: GradientView, context: Context) {
        view.gradientLayer.colors = colors.map { UIColor($0).cgColor }
    }

    final class GradientView: UIView {
        override class var layerClass: AnyClass { CAGradientLayer.self }

        var gradientLayer: CAGradientLayer { layer as! CAGradientLayer }
    }
}
