//
//  DetailSheet.swift
//  touchtimeWatch
//

import SwiftUI

/// A sheet page of rows that fills the screen, scrolling only when larger
/// text sizes push the rows past the bottom.
struct DetailSheetPage<Rows: View>: View {
    @ViewBuilder let rows: Rows

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    rows
                }
                .scenePadding(.navigationBar, edges: .horizontal)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

/// A dimmed title with its value at the trailing edge.
struct DetailSheetRow<Value: View>: View {
    let title: LocalizedStringKey
    let value: Value

    init(_ title: LocalizedStringKey, @ViewBuilder value: () -> Value) {
        self.title = title
        self.value = value()
    }

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
                .blendMode(.plusLighter)

            Spacer(minLength: 8)

            value
                .monospacedDigit()
        }
        .font(.body)
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        // As tall as a moon phase row, whose symbol outgrows the text.
        .frame(minHeight: 24)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

/// The digits alone, as on the watch's clocks, or a dash without a time.
/// VoiceOver still reads AM or PM.
struct DetailSheetTime: View {
    let date: Date?
    let timeZone: TimeZone

    @AppStorage(WatchTimeFormat.use24HourFormatKey) private var use24HourFormat = WatchTimeFormat.systemUses24HourFormat

    var body: some View {
        if let date {
            let formattedTime = WatchTimeFormat.time(date, in: timeZone, use24HourFormat: use24HourFormat)
            Text(formattedTime.digits)
                .accessibilityLabel([formattedTime.digits, formattedTime.period].compactMap { $0 }.joined(separator: " "))
        } else {
            Text(verbatim: "-")
        }
    }
}
