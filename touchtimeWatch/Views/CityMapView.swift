//
//  CityMapView.swift
//  touchtimeWatch
//

import SwiftUI

/// The iPhone app's dotted world map with the day/night line, every clock's
/// city dotted on it and the shown city's dot in the accent color.
struct CityMapView: View {
    let date: Date
    let timeZoneIdentifiers: [String]
    let highlightedTimeZoneIdentifier: String

    /// Wider than the map's own 16:9, squashing latitude a little like the
    /// medium widget does, so the map can span the screen and still leave
    /// room for the clock below it.
    private static let aspectRatio: CGFloat = 2.3

    var body: some View {
        if let grid = DotsWorldMapCanvas.grid {
            DotsWorldMapCanvas(timeZoneIdentifiers: timeZoneIdentifiers, date: date, sizing: .stretch)
                .overlay {
                    GeometryReader { proxy in
                        if let coordinate = TimeZoneCoordinates.getCoordinate(for: highlightedTimeZoneIdentifier) {
                            let layout = DotsWorldMapLayout(grid: grid, size: proxy.size)
                            let cell = grid.cell(latitude: coordinate.latitude, longitude: coordinate.longitude)
                            let diameter = layout.dotDiameter * 3
                            Circle()
                                .fill(.tint)
                                .frame(width: diameter, height: diameter)
                                .position(layout.cellCenter(column: cell.column, row: cell.row))
                        }
                    }
                }
                .aspectRatio(Self.aspectRatio, contentMode: .fit)
                .accessibilityHidden(true)
        }
    }
}
