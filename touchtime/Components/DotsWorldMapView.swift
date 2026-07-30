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

    // Continuous projection helpers (unit space) for overlays like the
    // solar terminator curve, sharing the artwork's geographic bounds.
    func longitude(atUnitX x: Double) -> Double {
        Self.longitudeMin + x * Self.longitudeSpan
    }

    func latitude(atUnitY y: Double) -> Double {
        Self.latitudeMax - y * Self.latitudeSpan
    }

    func unitY(latitude: Double) -> Double {
        (Self.latitudeMax - latitude) / Self.latitudeSpan
    }
}

/// Dotted world map where the current city's dot is fully opaque and every
/// other land dot is dimmed. A smooth Bézier curve traces the solar
/// terminator (the sunrise/sunset line) for `date`, and dots on the night
/// side of it are rendered darker than dots in daylight.
struct DotsWorldMapView: View {
    let timeZoneIdentifier: String
    let date: Date

    private static let grid = DotsWorldMapGrid(imageName: "WorldMap", columns: 72)

    var body: some View {
        if let grid = Self.grid {
            let cityCell = TimeZoneCoordinates.getCoordinate(for: timeZoneIdentifier).map {
                grid.cell(latitude: $0.latitude, longitude: $0.longitude)
            }

            Canvas { context, size in
                let spacing = size.width / CGFloat(grid.columns)
                let dotDiameter = spacing * 0.55

                // Day/night factors shared by every dot: a point is lit when
                // sin(altitude) = sinLat*sinDecl + cosLat*cosDecl*cosH > 0,
                // the same equation whose zero set is the terminator curve.
                let subsolar = SolarCalculator.subsolarPoint(date: date)
                let declinationRad = subsolar.latitude * .pi / 180
                let sinDeclination = sin(declinationRad)
                let cosDeclination = cos(declinationRad)
                let cosHourAngleByColumn: [Double] = (0..<grid.columns).map { column in
                    let longitude = grid.longitude(atUnitX: (Double(column) + 0.5) / Double(grid.columns))
                    return cos((longitude - subsolar.longitude) * .pi / 180)
                }

                for row in 0..<grid.rows {
                    let latitudeRad = grid.latitude(atUnitY: (Double(row) + 0.5) / Double(grid.rows)) * .pi / 180
                    let sinLatFactor = sin(latitudeRad) * sinDeclination
                    let cosLatFactor = cos(latitudeRad) * cosDeclination

                    for column in 0..<grid.columns {
                        let isCity = cityCell?.column == column && cityCell?.row == row
                        // Coastal cities can fall on an ocean cell; draw their dot anyway.
                        guard isCity || grid.isLand(column: column, row: row) else { continue }

                        // Dots in night are dimmed instead of overlaying a dark
                        // fill, so the day/night edge stays soft and dotted.
                        let isDay = sinLatFactor + cosLatFactor * cosHourAngleByColumn[column] > 0
                        let opacity: Double = isCity ? 1.0 : (isDay ? 0.25 : 0.1)

                        let diameter = isCity ? dotDiameter * 2 : dotDiameter
                        let rect = CGRect(
                            x: (CGFloat(column) + 0.5) * spacing - diameter / 2,
                            y: (CGFloat(row) + 0.5) * spacing - diameter / 2,
                            width: diameter,
                            height: diameter
                        )
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(.white.opacity(opacity))
                        )
                    }
                }

                // Solar terminator on top of the dots. A scoped copy keeps the
                // clip local, so spline overshoot near the poles stays inside.
                var curveContext = context
                curveContext.clip(to: Path(CGRect(origin: .zero, size: size)))
                curveContext.blendMode = .plusLighter
                // Fade the curve out toward the left/right edges so it doesn't
                // end abruptly at the map bounds.
                curveContext.stroke(
                    Self.terminatorPath(subsolar: subsolar, grid: grid, size: size),
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: .white.opacity(0), location: 0),
                            .init(color: .white.opacity(0.25), location: 0.15),
                            .init(color: .white.opacity(0.25), location: 0.85),
                            .init(color: .white.opacity(0), location: 1)
                        ]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: 0)
                    ),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
            }
            .aspectRatio(CGFloat(grid.columns) / CGFloat(grid.rows), contentMode: .fit)
        }
    }

    /// The day/night terminator across the artwork's longitude window as a
    /// smooth Bézier path. For each longitude, the sun sits on the horizon
    /// at latitude atan(-cos(hourAngle) / tan(declination)).
    private static func terminatorPath(
        subsolar: (latitude: Double, longitude: Double),
        grid: DotsWorldMapGrid,
        size: CGSize
    ) -> Path {
        var tanDeclination = tan(subsolar.latitude * .pi / 180)
        // At the equinoxes the terminator is vertical; a tiny floor keeps the
        // division finite and the curve a steep (but drawable) S-shape.
        if abs(tanDeclination) < 1e-4 {
            tanDeclination = tanDeclination.sign == .minus ? -1e-4 : 1e-4
        }

        // One phantom sample beyond each edge: the curve repeats every 360°
        // of longitude, so they give the spline correct tangents at the seam.
        let segments = 96
        let points: [CGPoint] = (-1...(segments + 1)).map { index in
            let unitX = Double(index) / Double(segments)
            let hourAngle = (grid.longitude(atUnitX: unitX) - subsolar.longitude) * .pi / 180
            let latitude = atan(-cos(hourAngle) / tanDeclination) * 180 / .pi
            let unitY = min(max(grid.unitY(latitude: latitude), 0), 1)
            return CGPoint(x: unitX * size.width, y: unitY * size.height)
        }

        // Catmull-Rom through the samples, emitted as cubic Béziers (same
        // technique as SolarCurve) so the line stays smooth between samples.
        var curve = Path()
        curve.move(to: points[1])
        for index in 1...segments {
            let p0 = points[index - 1]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = points[index + 2]

            let control1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6,
                y: p1.y + (p2.y - p0.y) / 6
            )
            let control2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6,
                y: p2.y - (p3.y - p1.y) / 6
            )

            curve.addCurve(to: p2, control1: control1, control2: control2)
        }

        return curve
    }
}
