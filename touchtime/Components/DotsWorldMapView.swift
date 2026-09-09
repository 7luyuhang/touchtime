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

    /// The canvas extends the artwork's ±80° band to the full ±90°, so the
    /// solar terminator (which reaches 90° − |declination|) is drawn in full
    /// wherever it is shown. Canvas clips to its bounds, but the curve is
    /// faded out before it gets within 2° of the poles (see
    /// DotsWorldMapView.terminatorOpacity), so its stroke never touches them.
    private static let canvasLatitudeMax: Double = 90

    let columns: Int
    let rows: Int
    private let land: [Bool]

    /// Height of the empty polar band above (and below) the artwork, in
    /// artwork cells: 10° of latitude at the artwork's vertical scale.
    private var polarPaddingRows: Double {
        (Self.canvasLatitudeMax - Self.latitudeMax) / Self.latitudeSpan * Double(rows)
    }

    /// Width : height of the whole canvas, artwork plus both polar bands.
    var canvasAspectRatio: CGFloat {
        CGFloat(columns) / CGFloat(Double(rows) + 2 * polarPaddingRows)
    }

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

    // Continuous projection helpers in the artwork's unit space (0...1 spans
    // its 360° x 160° bounds) for overlays like the solar terminator curve.
    // Latitudes beyond ±80° map outside 0...1; DotsWorldMapLayout turns
    // those into points in the polar bands of the canvas.
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

/// Point geometry of the dot grid inside a canvas of a given size. Cells are
/// `spacing` squares; the artwork's ±80° band is centred vertically, leaving
/// the polar bands above and below it for the terminator to turn around in.
private struct DotsWorldMapLayout {
    let spacing: CGFloat
    let artworkFrame: CGRect

    init(grid: DotsWorldMapGrid, size: CGSize) {
        spacing = size.width / CGFloat(grid.columns)
        let artworkHeight = spacing * CGFloat(grid.rows)
        artworkFrame = CGRect(
            x: 0,
            y: (size.height - artworkHeight) / 2,
            width: size.width,
            height: artworkHeight
        )
    }

    func cellRect(column: Int, row: Int) -> CGRect {
        CGRect(
            x: CGFloat(column) * spacing,
            y: artworkFrame.minY + CGFloat(row) * spacing,
            width: spacing,
            height: spacing
        )
    }

    func cellCenter(column: Int, row: Int) -> CGPoint {
        let rect = cellRect(column: column, row: row)
        return CGPoint(x: rect.midX, y: rect.midY)
    }

    /// Canvas point for a position in the artwork's unit space.
    func point(unitX: Double, unitY: Double) -> CGPoint {
        CGPoint(
            x: artworkFrame.minX + CGFloat(unitX) * artworkFrame.width,
            y: artworkFrame.minY + CGFloat(unitY) * artworkFrame.height
        )
    }
}

/// One tapped city cell on the map; `id` is the row-major cell index.
private struct DotsWorldMapSelection: Identifiable, Equatable {
    let id: Int
}

/// Dotted world map where each highlighted city's dot is fully opaque and
/// every other land dot is dimmed. A smooth Bézier curve traces the solar
/// terminator (the sunrise/sunset line) for `date`, and dots on the night
/// side of it are rendered darker than dots in daylight. The canvas spans
/// the full ±90° of latitude (the artwork only covers ±80°) so the curve is
/// never cut off where it turns around near the poles; around the equinoxes,
/// when it would degenerate into a box hugging both poles, it fades out
/// instead. Tapping a city dot opens a popover listing the city (or cities)
/// sharing that dot.
struct DotsWorldMapView: View {
    let timeZoneIdentifiers: [String]
    let date: Date

    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @State private var canvasSize: CGSize = .zero
    @State private var selection: DotsWorldMapSelection?

    private static let grid = DotsWorldMapGrid(imageName: "WorldMap", columns: 72)
    /// How far (in points) a tap may land from a city dot and still count.
    private static let tapTolerance: CGFloat = 24

    /// Declination band (degrees) over which the terminator fades out toward
    /// the equinox. The curve turns around at 90° − |declination|, so below
    /// ~5° it is mostly two meridians joined by runs along the poles; it is
    /// fully hidden within 2° (about ±5 days of each equinox). The fade keeps
    /// the transition smooth while scrubbing time across an equinox.
    private static let terminatorHiddenBelowDeclination: Double = 2
    private static let terminatorFullyVisibleAboveDeclination: Double = 5

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
                let layout = DotsWorldMapLayout(grid: grid, size: size)
                let dotDiameter = layout.spacing * 0.55

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
                        let center = layout.cellCenter(column: column, row: row)
                        let rect = CGRect(
                            x: center.x - diameter / 2,
                            y: center.y - diameter / 2,
                            width: diameter,
                            height: diameter
                        )
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(.white.opacity(opacity))
                        )
                    }
                }

                // Solar terminator on top of the dots, drawn in full: the
                // canvas reaches ±90°, so the curve turns around inside the
                // polar bands instead of being cut at the artwork's edge.
                // Skipped entirely around the equinoxes (see terminatorOpacity).
                let curveOpacity = Self.terminatorOpacity(declination: subsolar.latitude)
                if curveOpacity > 0 {
                    // A scoped copy keeps blend mode and opacity local to the curve.
                    var curveContext = context
                    curveContext.blendMode = .plusLighter
                    curveContext.opacity = curveOpacity
                    // Fade the curve out toward the left/right edges so it
                    // doesn't end abruptly at the map bounds.
                    curveContext.stroke(
                        Self.terminatorPath(subsolar: subsolar, grid: grid, layout: layout),
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
            }
            // View-level blend so the whole canvas layer composites
            // additively with the views behind it (e.g. the sky gradient in
            // DetailsSheet). GraphicsContext.blendMode can't do this: it only
            // blends draws against the canvas's own transparent layer.
            .blendMode(.plusLighter)
            .aspectRatio(grid.canvasAspectRatio, contentMode: .fit)
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

    /// Opacity of the terminator for the sun's declination (degrees): 0 within
    /// `terminatorHiddenBelowDeclination` of the equinox, 1 beyond
    /// `terminatorFullyVisibleAboveDeclination`, linear in between.
    private static func terminatorOpacity(declination: Double) -> Double {
        let fadeSpan = terminatorFullyVisibleAboveDeclination - terminatorHiddenBelowDeclination
        let progress = (abs(declination) - terminatorHiddenBelowDeclination) / fadeSpan
        return min(max(progress, 0), 1)
    }

    /// The day/night terminator across the artwork's longitude window as a
    /// smooth Bézier path. For each longitude, the sun sits on the horizon
    /// at latitude atan(-cos(hourAngle) / tan(declination)).
    private static func terminatorPath(
        subsolar: (latitude: Double, longitude: Double),
        grid: DotsWorldMapGrid,
        layout: DotsWorldMapLayout
    ) -> Path {
        var tanDeclination = tan(subsolar.latitude * .pi / 180)
        // At the equinoxes the terminator is vertical. The curve isn't drawn
        // that close to an equinox (see terminatorOpacity), but keep the
        // division finite regardless so the path is always well-formed.
        if abs(tanDeclination) < 1e-4 {
            tanDeclination = tanDeclination.sign == .minus ? -1e-4 : 1e-4
        }

        // One phantom sample beyond each edge: the curve repeats every 360°
        // of longitude, so they give the spline correct tangents at the seam.
        // Latitudes are not clamped to the artwork's ±80°: the layout maps
        // them into the polar bands of the canvas, where the curve turns
        // around at 90° − |declination| exactly as it does on the globe.
        let segments = 96
        let points: [CGPoint] = (-1...(segments + 1)).map { index in
            let unitX = Double(index) / Double(segments)
            let hourAngle = (grid.longitude(atUnitX: unitX) - subsolar.longitude) * .pi / 180
            let latitude = atan(-cos(hourAngle) / tanDeclination) * 180 / .pi
            return layout.point(unitX: unitX, unitY: grid.unitY(latitude: latitude))
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
