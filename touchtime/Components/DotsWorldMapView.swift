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

/// One tapped city cell on the map; `id` is the row-major cell index.
private struct DotsWorldMapSelection: Identifiable, Equatable {
    let id: Int
}

/// Dotted world map where each highlighted city's dot is fully opaque and
/// every other land dot is dimmed. A smooth Bézier curve traces the solar
/// terminator (the sunrise/sunset line) for `date`, and dots on the night
/// side of it are rendered darker than dots in daylight. Tapping a city dot
/// opens a popover listing the city (or cities) sharing that dot.
struct DotsWorldMapView: View {
    let timeZoneIdentifiers: [String]
    let date: Date

    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @State private var canvasSize: CGSize = .zero
    @State private var selection: DotsWorldMapSelection?

    private static let grid = DotsWorldMapGrid(imageName: "WorldMap", columns: 72)
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
        if let grid = Self.grid {
            // Timezone identifiers grouped by the row-major index of their map
            // cell, so drawing and tap hit-testing share one lookup table.
            let citiesByCell = Self.citiesByCell(for: timeZoneIdentifiers, grid: grid)

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
                        let isCity = citiesByCell[row * grid.columns + column] != nil
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
            // View-level blend so the whole canvas layer composites
            // additively with the views behind it (e.g. the sky gradient in
            // DetailsSheet). GraphicsContext.blendMode can't do this: it only
            // blends draws against the canvas's own transparent layer.
            .blendMode(.plusLighter)
            .aspectRatio(CGFloat(grid.columns) / CGFloat(grid.rows), contentMode: .fit)
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

    /// Timezone identifiers grouped by the row-major index of their map cell.
    private static func citiesByCell(for identifiers: [String], grid: DotsWorldMapGrid) -> [Int: [String]] {
        var cities: [Int: [String]] = [:]
        for identifier in identifiers {
            guard let coordinate = TimeZoneCoordinates.getCoordinate(for: identifier) else { continue }
            let cell = grid.cell(latitude: coordinate.latitude, longitude: coordinate.longitude)
            cities[cell.row * grid.columns + cell.column, default: []].append(identifier)
        }
        return cities
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
        let spacing = canvasSize.width / CGFloat(grid.columns)
        var nearest: (index: Int, distance: CGFloat)?
        for index in cells {
            let center = CGPoint(
                x: (CGFloat(index % grid.columns) + 0.5) * spacing,
                y: (CGFloat(index / grid.columns) + 0.5) * spacing
            )
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
        let spacing = canvasSize.width / CGFloat(grid.columns)
        return CGRect(
            x: CGFloat(selection.id % grid.columns) * spacing,
            y: CGFloat(selection.id / grid.columns) * spacing,
            width: spacing,
            height: spacing
        )
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
