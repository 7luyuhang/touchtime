//
//  CityCard.swift
//  touchtimeWatch
//

import SwiftUI

/// A city's name and date over its time and how far it is from here, as the
/// city list's rows and the City Time widget show them.
struct CityCard: View {
    let city: ClockCity
    let date: Date
    let now: Date
    let dateStyle: String
    /// Between the name and the time.
    var spacing: CGFloat = 16
    var timeSize: ClockTimeText.Size = .list

    @AppStorage(AdditionalTime.storageKey) private var additionalTime: AdditionalTime = .timeShift

    var body: some View {
        let dateLabel = date.formattedDate(style: dateStyle, timeZone: city.timeZone, relativeTo: now)

        VStack(alignment: .leading, spacing: spacing) {
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
                ClockTimeText(date: date, timeZone: city.timeZone, size: timeSize, alignsLeadingInk: true)

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
        .accessibilityElement(children: .combine)
    }
}
