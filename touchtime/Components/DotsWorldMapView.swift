//
//  DotsWorldMapView.swift
//  touchtime
//
//  Created on 24/07/2026.
//

import SwiftUI

/// Land/ocean grid sampled once from the "WorldMap" asset.
private struct DotsWorldMapGrid {
    /// Geographic bounds of the "WorldMap" artwork, measured by fitting real
    /// coastlines (Australia, South America, Africa) to the drawn pixels.
    /// The asset is NOT a full -180...180 / 90...-90 render: it splits at the
    /// Bering Strait (so Russia stays intact) and clips latitudes beyond ±80°.
    private static let longitudeMin: Double = -169.5
    private static let longitudeSpan: Double = 360
    private static let latitudeMax: Double = 80
    private static let latitudeSpan: Double = 160

    let columns: Int
    let rows: Int
    private let land: [Bool]

    init?(imageName: String, columns: Int) {
        guard let cgImage = UIImage(named: imageName)?.cgImage, cgImage.width > 0 else { return nil }

        let rows = max(Int((Double(columns) * Double(cgImage.height) / Double(cgImage.width)).rounded()), 1)

        // Downsample the map's alpha channel straight into a columns x rows
        // bitmap; high interpolation quality area-averages the pixels.
        guard let context = CGContext(
            data: nil,
            width: columns,
            height: rows,
            bitsPerComponent: 8,
            bytesPerRow: columns,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: columns, height: rows))
        guard let buffer = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }

        self.columns = columns
        self.rows = rows
        // A cell counts as land when enough of its area is covered.
        self.land = (0..<(columns * rows)).map { buffer[$0] > 80 }
    }

    func isLand(column: Int, row: Int) -> Bool {
        guard column >= 0, column < columns, row >= 0, row < rows else { return false }
        return land[row * columns + column]
    }

    func cell(latitude: Double, longitude: Double) -> (column: Int, row: Int) {
        // Wrap into the artwork's longitude window (e.g. Samoa at -171°
        // belongs on the right edge, past the Bering Strait split).
        var longitude = longitude
        while longitude < Self.longitudeMin { longitude += 360 }
        while longitude >= Self.longitudeMin + 360 { longitude -= 360 }

        let x = (longitude - Self.longitudeMin) / Self.longitudeSpan * Double(columns)
        let y = (Self.latitudeMax - latitude) / Self.latitudeSpan * Double(rows)
        return (
            column: min(max(Int(x), 0), columns - 1),
            row: min(max(Int(y), 0), rows - 1)
        )
    }
}

/// Dotted world map where the current city's dot is fully opaque
/// and every other land dot is dimmed.
struct DotsWorldMapView: View {
    let timeZoneIdentifier: String

    private static let grid = DotsWorldMapGrid(imageName: "WorldMap", columns: 72)

    var body: some View {
        if let grid = Self.grid {
            let cityCell = TimeZoneCoordinates.getCoordinate(for: timeZoneIdentifier).map {
                grid.cell(latitude: $0.latitude, longitude: $0.longitude)
            }

            Canvas { context, size in
                let spacing = size.width / CGFloat(grid.columns)
                let dotDiameter = spacing * 0.55

                for row in 0..<grid.rows {
                    for column in 0..<grid.columns {
                        let isCity = cityCell?.column == column && cityCell?.row == row
                        // Coastal cities can fall on an ocean cell; draw their dot anyway.
                        guard isCity || grid.isLand(column: column, row: row) else { continue }

                        let diameter = isCity ? dotDiameter * 2 : dotDiameter
                        let rect = CGRect(
                            x: (CGFloat(column) + 0.5) * spacing - diameter / 2,
                            y: (CGFloat(row) + 0.5) * spacing - diameter / 2,
                            width: diameter,
                            height: diameter
                        )
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(.white.opacity(isCity ? 1.0 : 0.25))
                        )
                    }
                }
            }
            .aspectRatio(CGFloat(grid.columns) / CGFloat(grid.rows), contentMode: .fit)
        }
    }
}
