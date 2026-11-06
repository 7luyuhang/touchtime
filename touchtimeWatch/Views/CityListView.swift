//
//  CityListView.swift
//  touchtimeWatch
//

import SwiftUI

/// Every clock at a glance, each row tinted with the sky over its city, and
/// below them a page for each of the iPhone's collections. The Digital Crown
/// scrolls to the end of a page's cities and on into the next page.
struct CityListView: View {
    let pages: [CityListPage]
    /// The page showing.
    @Binding var pageID: String
    @Binding var selection: String?
    /// The time every clock shows in place of now, or nil for now.
    @Binding var adjustedDate: Date?
    let onAnalogClockTap: () -> Void

    @Environment(WatchCityStore.self) private var cityStore
    @State private var showsSettings = false
    /// Taps on Current Time, each felt. Not the adjusted date, which a city's
    /// details and the analog clock also clear, with haptics of their own.
    @State private var currentTimeTaps = 0

    var body: some View {
        let title = pages.first { $0.id == pageID }?.title

        TimelineView(.everyMinute) { context in
            let date = adjustedDate ?? context.date

            TabView(selection: $pageID) {
                ForEach(pages) { page in
                    List(selection: $selection) {
                        ForEach(page.cities) { city in
                            NavigationLink(value: city.id) {
                                CityRow(city: city, date: date, now: context.date, dateStyle: cityStore.dateStyle)
                            }
                            .listRowBackground(CityRowBackground(date: date, timeZone: city.timeZone))
                        }
                    }
                    .tag(page.id)
                }
            }
            .tabViewStyle(.verticalPage)
            // The pages' indicator otherwise stays over a city's details
            .scrollIndicators(selection == nil ? .automatic : .hidden)
            .animation(.smooth, value: adjustedDate)
            // Verbatim, as collections are named on the iPhone
            .navigationTitle(Text(verbatim: title ?? ""))
            .toolbar {
                // While adjusting time, a reset button takes the analog clock
                // button's place, as it takes the back button's on a city's
                // details.
                ToolbarItem(placement: .topBarLeading) {
                    if adjustedDate != nil {
                        Button("Current Time", systemImage: "xmark") {
                            currentTimeTaps += 1
                            showCurrentTime()
                        }
                    } else {
                        Button("Analog Clock", systemImage: "clock", action: onAnalogClockTap)
                    }
                }
                // Only on every city's page; on a collection's, the time and
                // the collection's name move over into its place
                if title == nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Settings", systemImage: "gear") {
                            showsSettings = true
                        }
                    }
                }
            }
        }
        .toolbarForegroundStyle(.primary, for: .navigationBar)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: currentTimeTaps)
        .sheet(isPresented: $showsSettings) {
            SettingsView()
        }
    }

    /// Back to now on every clock.
    private func showCurrentTime() {
        withAnimation(.smooth) {
            adjustedDate = nil
        }
    }
}

private struct CityRow: View {
    let city: ClockCity
    let date: Date
    let now: Date
    let dateStyle: String

    @AppStorage(AdditionalTime.storageKey) private var additionalTime: AdditionalTime = .timeShift

    var body: some View {
        let dateLabel = date.formattedDate(style: dateStyle, timeZone: city.timeZone, relativeTo: now)

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text(city.name)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Spacer(minLength: 4)
                
                Text(dateLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(.smooth, value: dateLabel)
                    .layoutPriority(1)
            }

            HStack(alignment: .lastTextBaseline) {
                ClockTimeText(date: date, timeZone: city.timeZone, size: .list, alignsLeadingInk: true)

                Spacer(minLength: 4)

                Group {
                    // In place of Local's time shift, which is always empty
                    if city.isLocal && additionalTime == .timeShift {
                        Image(systemName: "location.fill")
                            .accessibilityHidden(true)
                    } else {
                        Text(additionalTime.text(for: city.timeZone, at: date))
                            .lineLimit(1)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .blendMode(.plusLighter)
                .layoutPriority(1)
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
