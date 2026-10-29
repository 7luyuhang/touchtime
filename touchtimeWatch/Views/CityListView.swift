//
//  CityListView.swift
//  touchtimeWatch
//

import SwiftUI

/// Every clock at a glance, each row tinted with the sky over its city.
struct CityListView: View {
    let cities: [ClockCity]
    @Binding var selection: String?
    /// The time every clock shows in place of now, or nil for now.
    @Binding var adjustedDate: Date?

    @Environment(WatchCityStore.self) private var cityStore
    /// The slide under way on the Scroll Time bar, or nil while it's at rest.
    @State private var timeSlide: ScrollTimeSlide?
    /// The list's bottom edge and the Scroll Time bar's top, on screen. How
    /// far apart they are differs from watch to watch.
    @State private var listBottom: CGFloat = 0
    @State private var scrollTimeBarTop: CGFloat = 0

    /// Whether the button that brings the clocks back to now shows. A slide
    /// leaves it as it was until the finger lifts.
    private var showsResetButton: Bool {
        timeSlide.map { $0.start != nil } ?? (adjustedDate != nil)
    }

    /// Room below the last city, so it scrolls clear of the Scroll Time bar,
    /// with a little to spare. The button above the bar covers the list
    /// rather than adding room, which would shift the rows as it comes and goes.
    private var bottomClearance: CGFloat {
        listBottom - scrollTimeBarTop + 8
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let date = adjustedDate ?? context.date

            List(selection: $selection) {
                Section {
                    ForEach(cities) { city in
                        NavigationLink(value: city.id) {
                            CityRow(city: city, date: date, now: context.date, dateStyle: cityStore.dateStyle)
                        }
                        .listRowBackground(CityRowBackground(date: date, timeZone: city.timeZone))
                    }
                } footer: {
                    Color.clear
                        .frame(height: bottomClearance)
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { listBottom = $0 }
            // Resting on the Scroll Time bar rather than in the bottom bar with
            // it, which would push the bar down to keep what it holds centered
            .overlay(alignment: .bottom) {
                if showsResetButton {
                    ScrollTimeResetButton(adjustedDate: $adjustedDate)
                        .offset(y: scrollTimeBarTop - listBottom)
                        .transition(.blurReplace.combined(with: .scale).combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.smooth, value: adjustedDate)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    ScrollTimeBar(adjustedDate: $adjustedDate, slide: $timeSlide, now: context.date)
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { scrollTimeBarTop = $0 }
                }
            }
        }
    }
}

private struct CityRow: View {
    let city: ClockCity
    let date: Date
    let now: Date
    let dateStyle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text(city.name)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Spacer(minLength: 4)
                
                Text(date.formattedDate(style: dateStyle, timeZone: city.timeZone, relativeTo: now))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .lineLimit(1)
                    .layoutPriority(1)
            }

            HStack(alignment: .lastTextBaseline) {
                Group {
                    if city.isLocal {
                        Image(systemName: "location.fill")
                            .accessibilityHidden(true)
                    } else {
                        Text(WorldClock.timeDifference(to: city.timeZone, at: date))
                            .lineLimit(1)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .blendMode(.plusLighter)
                .layoutPriority(1)

                Spacer(minLength: 4)

                ClockTimeText(date: date, timeZone: city.timeZone)
            }
        }
        // Less below, as the time's digits leave the space under their
        // baseline empty
        .padding(.top, 12)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
    }
}

/// A row's sky, in the rounded shape the list gives its rows.
private struct CityRowBackground: View {
    let date: Date
    let timeZone: TimeZone

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        // As thick with stars as the iPhone app's rows, which are twice as big
        CitySkyBackground(date: date, timeZone: timeZone, starCount: 12)
            .clipShape(shape)
            .overlay {
                shape
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    .blendMode(.plusLighter)
            }
    }
}
