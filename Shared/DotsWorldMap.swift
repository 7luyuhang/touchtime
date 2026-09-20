//
//  DotsWorldMap.swift
//  touchtime
//
//  Created on 13/09/2026.
//
//  The dotted world map with the solar terminator, shared by the app
//  (DotsWorldMapView adds tap-to-inspect on top of it) and the widget
//  extension (TerminatorWidget). Each target ships its own copy of the
//  "WorldMap" asset the land grid is sampled from.
//

import SwiftUI

/// Land/ocean grid sampled once from the "WorldMap" asset.
struct DotsWorldMapGrid {
    /// Geographic bounds of the "WorldMap" artwork, measured by fitting real
    /// coastlines (Australia, South America, Africa) to the drawn pixels.
    /// The asset is NOT a full -180...180 / 90...-90 render: it splits at the
    /// Bering Strait (so Russia stays intact) and clips latitudes beyond ±80°.
    private static let longitudeMin: Double = -169.5
    private static let longitudeSpan: Double = 360
    private static let latitudeMax: Double = 80
    private static let latitudeSpan: Double = 160

    /// The canvas extends the artwork's ±80° band to the full ±90°, so the
    /// solar terminator (which reaches 90° − |declination|) always turns
    /// around inside the canvas rather than being cut at the artwork's edge.
    /// Its stroke fades out through these polar bands (see
    /// DotsWorldMapCanvas.terminatorLatitudeMask), which hides the runs along
    /// the poles it degenerates into around the equinoxes.
    private static let canvasLatitudeMax: Double = 90

    let columns: Int
    let rows: Int
    private let land: [Bool]

    /// Height of the empty polar band above (and below) the artwork, in
    /// artwork cells: 10° of latitude at the artwork's vertical scale.
    private var polarPaddingRows: Double {
        (Self.canvasLatitudeMax - Self.latitudeMax) / Self.latitudeSpan * Double(rows)
    }

    /// Height of the whole canvas in artwork cells: the artwork's rows plus
    /// both polar bands.
    var canvasRows: Double {
        Double(rows) + 2 * polarPaddingRows
    }

    /// Width : height of the whole canvas, artwork plus both polar bands.
    var canvasAspectRatio: CGFloat {
        CGFloat(columns) / CGFloat(canvasRows)
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

/// Point geometry of the dot grid inside a canvas of a given size. The
/// columns share the width and the canvas rows (artwork plus polar bands)
/// the height, so the artwork's ±80° band is centred vertically, leaving
/// the polar bands above and below it for the terminator to turn around in.
/// Cells are square when the canvas has its own aspect ratio
/// (DotsWorldMapCanvas.Sizing.fit); a stretched canvas gets wider-than-tall
/// cells, scaling latitude independently of longitude.
struct DotsWorldMapLayout {
    let cellSize: CGSize
    let artworkFrame: CGRect

    init(grid: DotsWorldMapGrid, size: CGSize) {
        cellSize = CGSize(
            width: size.width / CGFloat(grid.columns),
            height: size.height / CGFloat(grid.canvasRows)
        )
        let artworkHeight = cellSize.height * CGFloat(grid.rows)
        artworkFrame = CGRect(
            x: 0,
            y: (size.height - artworkHeight) / 2,
            width: size.width,
            height: artworkHeight
        )
    }

    /// Diameter of a plain land dot: 55% of the cell's shorter side, so dots
    /// stay round and never touch when the cells aren't square.
    var dotDiameter: CGFloat {
        min(cellSize.width, cellSize.height) * 0.55
    }

    func cellRect(column: Int, row: Int) -> CGRect {
        CGRect(
            x: CGFloat(column) * cellSize.width,
            y: artworkFrame.minY + CGFloat(row) * cellSize.height,
            width: cellSize.width,
            height: cellSize.height
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

/// Dotted world map where each highlighted city's dot is fully opaque and
/// every other land dot is dimmed. A smooth curve traces the solar
/// terminator (the sunrise/sunset line) for `date`, and dots on the night
/// side of it are rendered darker than dots in daylight. The canvas spans
/// the full ±90° of latitude (the artwork only covers ±80°) so the curve is
/// never cut off where it turns around near the poles. It is drawn all year
/// round, dissolving toward the poles beyond the artwork: around the
/// equinoxes, when it is nearly two meridians joined by runs along the
/// poles, only the meridians show, fading out at the top and bottom of the
/// map instead of boxing it in.
///
/// Drawing only, no interaction, so it renders the same in the app and in
/// WidgetKit. The view composites additively (plus lighter) over whatever
/// is behind it, e.g. a sky gradient.
struct DotsWorldMapCanvas: View {
    /// How the canvas (the artwork's ±80° plus both polar bands, 16:9)
    /// relates to the size it is offered.
    enum Sizing {
        /// Keeps the canvas's aspect ratio, letterboxed inside the offer.
        case fit
        /// Takes the offered size exactly, scaling latitude and longitude
        /// independently. The whole ±90° canvas, terminator turnarounds
        /// included, then fits any aspect ratio at the cost of squashing
        /// the map in one direction; the medium widget (about 2.3:1)
        /// compresses it vertically by about a fifth.
        case stretch
    }

    let timeZoneIdentifiers: [String]
    let date: Date
    var sizing: Sizing = .fit

    /// The land grid, sampled once per process from this target's copy of
    /// the "WorldMap" asset. Nil when the asset is missing, in which case
    /// the map renders nothing.
    static let grid = DotsWorldMapGrid(imageName: "WorldMap", columns: 72)

    /// Latitude (degrees) at which the terminator has fully faded out
    /// toward either pole. The fade starts at the artwork's edge (±80°), so
    /// the curve looks the same as ever while it turns around on the map
    /// itself (|declination| ≥ 10°); nearer the equinoxes it turns around in
    /// the polar bands and dissolves there instead of running along the poles.
    private static let terminatorFadeEndLatitude: Double = 86

    var body: some View {
        if let grid = Self.grid {
            // Timezone identifiers grouped by the row-major index of their map
            // cell; the same table DotsWorldMapView uses for tap hit-testing.
            let citiesByCell = Self.citiesByCell(for: timeZoneIdentifiers, grid: grid)

            let canvas = Canvas { context, size in
                let layout = DotsWorldMapLayout(grid: grid, size: size)
                let dotDiameter = layout.dotDiameter

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

                // Solar terminator on top of the dots. The canvas reaches
                // ±90°, so the curve turns around inside the polar bands
                // instead of being cut at the artwork's edge; a soft mask
                // fades it out there so it never reaches the poles.
                // A scoped copy keeps blend mode and mask local to the curve.
                var curveContext = context
                curveContext.blendMode = .plusLighter
                curveContext.clipToLayer { mask in
                    mask.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: Self.terminatorLatitudeMask(grid: grid, layout: layout)
                    )
                }
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
            // View-level blend so the whole canvas layer composites
            // additively with the views behind it (e.g. the sky gradient in
            // DetailsSheet). GraphicsContext.blendMode can't do this: it only
            // blends draws against the canvas's own transparent layer.
            .blendMode(.plusLighter)

            switch sizing {
            case .fit:
                canvas.aspectRatio(grid.canvasAspectRatio, contentMode: .fit)
            case .stretch:
                canvas
            }
        }
    }

    /// Timezone identifiers grouped by the row-major index of their map cell.
    static func citiesByCell(for identifiers: [String], grid: DotsWorldMapGrid) -> [Int: [String]] {
        var cities: [Int: [String]] = [:]
        for identifier in identifiers {
            guard let coordinate = TimeZoneCoordinates.getCoordinate(for: identifier) else { continue }
            let cell = grid.cell(latitude: coordinate.latitude, longitude: coordinate.longitude)
            cities[cell.row * grid.columns + cell.column, default: []].append(identifier)
        }
        return cities
    }

    /// Soft mask for the terminator stroke: opaque across the artwork's
    /// latitude band, fading to clear toward each pole so the curve dissolves
    /// in the polar bands (fully gone by `terminatorFadeEndLatitude`).
    private static func terminatorLatitudeMask(
        grid: DotsWorldMapGrid,
        layout: DotsWorldMapLayout
    ) -> GraphicsContext.Shading {
        let northPole = layout.point(unitX: 0, unitY: grid.unitY(latitude: 90))
        let southPole = layout.point(unitX: 0, unitY: grid.unitY(latitude: -90))
        // Gradient location of a latitude: 0 at the north pole, 1 at the south.
        func location(latitude: Double) -> CGFloat {
            let y = layout.point(unitX: 0, unitY: grid.unitY(latitude: latitude)).y
            return (y - northPole.y) / (southPole.y - northPole.y)
        }
        // The artwork's top edge (80°): opaque from here down to its mirror.
        let fadeStartLatitude = grid.latitude(atUnitY: 0)
        let fadeEndLatitude = terminatorFadeEndLatitude

        return .linearGradient(
            Gradient(stops: [
                .init(color: .white.opacity(0), location: location(latitude: fadeEndLatitude)),
                .init(color: .white, location: location(latitude: fadeStartLatitude)),
                .init(color: .white, location: location(latitude: -fadeStartLatitude)),
                .init(color: .white.opacity(0), location: location(latitude: -fadeEndLatitude))
            ]),
            startPoint: northPole,
            endPoint: southPole
        )
    }

    /// The day/night terminator across the artwork's longitude window. For
    /// each longitude, the sun sits on the horizon at latitude
    /// atan(-cos(hourAngle) / tan(declination)).
    private static func terminatorPath(
        subsolar: (latitude: Double, longitude: Double),
        grid: DotsWorldMapGrid,
        layout: DotsWorldMapLayout
    ) -> Path {
        var tanDeclination = tan(subsolar.latitude * .pi / 180)
        // At the equinoxes the terminator is vertical; keep the division
        // finite so the path is always well-formed.
        if abs(tanDeclination) < 1e-4 {
            tanDeclination = tanDeclination.sign == .minus ? -1e-4 : 1e-4
        }

        // Sampled every half degree of longitude and joined with straight
        // segments: under a point apart on any map size, so the polyline
        // reads as a smooth curve, and unlike a spline it cannot overshoot
        // into bumps where the curve bends sharply around the equinoxes.
        // Latitudes are not clamped to the artwork's ±80°: the layout maps
        // them into the polar bands of the canvas, where the curve turns
        // around at 90° − |declination| exactly as it does on the globe.
        let segments = 720
        var curve = Path()
        for index in 0...segments {
            let unitX = Double(index) / Double(segments)
            let hourAngle = (grid.longitude(atUnitX: unitX) - subsolar.longitude) * .pi / 180
            let latitude = atan(-cos(hourAngle) / tanDeclination) * 180 / .pi
            let point = layout.point(unitX: unitX, unitY: grid.unitY(latitude: latitude))
            if index == 0 {
                curve.move(to: point)
            } else {
                curve.addLine(to: point)
            }
        }
        return curve
    }
}
