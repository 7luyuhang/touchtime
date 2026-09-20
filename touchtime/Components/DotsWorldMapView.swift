//
//  DotsWorldMapView.swift
//  touchtime
//
//  Created on 24/07/2026.
//

import SwiftUI

/// One tapped city cell on the map; `id` is the row-major cell index.
private struct DotsWorldMapSelection: Identifiable, Equatable {
    let id: Int
}

/// The shared dotted world map (DotsWorldMapCanvas in Shared/: highlighted
/// city dots, dimmed night side and the solar terminator curve for `date`)
/// with the app's interaction on top: tapping a city dot opens a popover
/// listing the city (or cities) sharing that dot.
struct DotsWorldMapView: View {
    let timeZoneIdentifiers: [String]
    let date: Date

    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @State private var canvasSize: CGSize = .zero
    @State private var selection: DotsWorldMapSelection?

    /// How far (in points) a tap may land from a city dot and still count.
    private static let tapTolerance: CGFloat = 24

    init(timeZoneIdentifier: String, date: Date) {
        self.init(timeZoneIdentifiers: [timeZoneIdentifier], date: date)
    }

    init(timeZoneIdentifiers: [String], date: Date) {
        self.timeZoneIdentifiers = timeZoneIdentifiers
        self.date = date
    }

    var body: some View {
        if let grid = DotsWorldMapCanvas.grid {
            // The same lookup table the canvas draws its city dots from, so
            // tap hit-testing and the popover agree with what's on screen.
            let citiesByCell = DotsWorldMapCanvas.citiesByCell(for: timeZoneIdentifiers, grid: grid)

            DotsWorldMapCanvas(timeZoneIdentifiers: timeZoneIdentifiers, date: date)
                .contentShape(Rectangle())
                .onGeometryChange(for: CGSize.self) { proxy in
                    proxy.size
                } action: { size in
                    canvasSize = size
                }
                .onTapGesture { location in
                    guard let cellIndex = nearestCityCell(to: location, in: citiesByCell.keys, grid: grid) else { return }
                    if hapticEnabled {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    selection = DotsWorldMapSelection(id: cellIndex)
                }
                .popover(
                    item: $selection,
                    attachmentAnchor: .rect(.rect(anchorRect(for: selection, grid: grid)))
                ) { selected in
                    let selectedCities = citiesByCell[selected.id] ?? []

                    VStack(alignment: .center, spacing: 10) {
                        ForEach(Array(selectedCities.enumerated()), id: \.offset) { index, identifier in
                            Text(Self.cityDisplayName(for: identifier))
                                .font(.subheadline.weight(.medium))

                            if index < selectedCities.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .presentationCompactAdaptation(.popover)
                }
        }
    }

    /// City name for the popover, localized the same way as the city list.
    private static func cityDisplayName(for identifier: String) -> String {
        let cityName = identifier.split(separator: "/").last
            .map { $0.replacingOccurrences(of: "_", with: " ") } ?? identifier
        return String(localized: String.LocalizationValue(cityName))
    }

    /// The city cell nearest to a tap, or nil when none is within tolerance.
    private func nearestCityCell(to location: CGPoint, in cells: some Sequence<Int>, grid: DotsWorldMapGrid) -> Int? {
        guard canvasSize.width > 0 else { return nil }
        let layout = DotsWorldMapLayout(grid: grid, size: canvasSize)
        var nearest: (index: Int, distance: CGFloat)?
        for index in cells {
            let center = layout.cellCenter(column: index % grid.columns, row: index / grid.columns)
            let distance = hypot(center.x - location.x, center.y - location.y)
            if distance <= Self.tapTolerance, distance < (nearest?.distance ?? .infinity) {
                nearest = (index, distance)
            }
        }
        return nearest?.index
    }

    /// Cell rect in canvas coordinates, used to anchor the popover arrow.
    private func anchorRect(for selection: DotsWorldMapSelection?, grid: DotsWorldMapGrid) -> CGRect {
        guard let selection, canvasSize.width > 0 else { return .zero }
        return DotsWorldMapLayout(grid: grid, size: canvasSize)
            .cellRect(column: selection.id % grid.columns, row: selection.id / grid.columns)
    }
}
