//
//  CityListView.swift
//  touchtimeWatch
//

import SwiftUI

/// Every clock at a glance, each row tinted with the sky over its city.
struct CityListView: View {
    let cities: [ClockCity]
    @Binding var selection: String?

    @Environment(WatchCityStore.self) private var cityStore

    var body: some View {
        TimelineView(.everyMinute) { context in
            List(selection: $selection) {
                Section {
                    ForEach(cities) { city in
                        NavigationLink(value: city.id) {
                            CityRow(city: city, date: context.date, dateStyle: cityStore.dateStyle)
                        }
                        .listRowBackground(CityRowBackground(date: context.date, timeZone: city.timeZone))
                    }
                } footer: {
                    Text("Add and arrange cities in Touch Time on iPhone.")
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

private struct CityRow: View {
    let city: ClockCity
    let date: Date
    let dateStyle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text(city.name)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Spacer(minLength: 4)
                
                Text(date.formattedDate(style: dateStyle, timeZone: city.timeZone, relativeTo: date))
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
