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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(city.name)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if city.isLocal {
                    Image(systemName: "location.fill")
                        .font(.footnote)
                        .accessibilityHidden(true)
                }
            }

            ClockTimeText(date: date, timeZone: city.timeZone)

            Text(WatchTimeFormat.dayAndOffset(date, in: city.timeZone, now: date, dateStyle: dateStyle))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .blendMode(.plusLighter)
                .lineLimit(1)
        }
        .padding(.vertical, 6)
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
