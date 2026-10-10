//
//  DotsWorldMapGlobeView.swift
//  touchtime
//
//  Created on 09/10/2026.
//

import SwiftUI
import UIKit

/// The dotted world map that turns into a dotted 3D globe when double
/// tapped, for the Search tab's map pane beside the list on iPhone Duo in
/// landscape. The globe has a dot for every supported time zone, the added
/// cities' dots largest and brightest; it spins slowly and follows a drag,
/// and a double tap turns it back into the map, blurring through the middle
/// of each change. With Reduce Motion the map and the globe cross-fade
/// instead, and the globe holds still.
struct DotsWorldMapGlobeView: View {
    let timeZoneIdentifiers: [String]
    let date: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    /// Whether the map has turned, or is turning, into the globe.
    @State private var isGlobe = false
    /// Whether the globe canvas stands in for the map: from the tap that
    /// starts the morph until the morph back has settled. At rest the canvas
    /// draws exactly the map, so neither swap shows; with Reduce Motion the
    /// swap is the change, a cross-fade.
    @State private var showsGlobeCanvas = false
    /// Counts the morphs, so a morph back to the map that was overtaken by
    /// another morph doesn't hand over to the map when it ends.
    @State private var morphCount = 0

    private static let morphAnimation = Animation.smooth(duration: 1.2)
    private static let fadeAnimation = Animation.easeInOut(duration: 0.3)

    var body: some View {
        ZStack {
            DotsWorldMapView(
                timeZoneIdentifiers: timeZoneIdentifiers,
                date: date,
                onDoubleTap: showGlobe
            )
            .opacity(showsGlobeCanvas ? 0 : 1)
            .allowsHitTesting(!showsGlobeCanvas)

            DotsGlobePane(
                timeZoneIdentifiers: timeZoneIdentifiers,
                date: date,
                isGlobe: isGlobe,
                onDoubleTap: { isGlobe ? showMap() : showGlobe() }
            )
            .opacity(showsGlobeCanvas ? 1 : 0)
            .allowsHitTesting(showsGlobeCanvas)
        }
        .modifier(SwitchBlur(morph: isGlobe ? 1 : 0, fade: showsGlobeCanvas ? 1 : 0))
    }

    private func showGlobe() {
        playHaptic()
        morphCount += 1
        if reduceMotion {
            isGlobe = true
            withAnimation(Self.fadeAnimation) {
                showsGlobeCanvas = true
            }
        } else {
            // The swap itself must not animate, only the morph
            showsGlobeCanvas = true
            withAnimation(Self.morphAnimation) {
                isGlobe = true
            }
        }
    }

    private func showMap() {
        playHaptic()
        morphCount += 1
        let morph = morphCount
        if reduceMotion {
            withAnimation(Self.fadeAnimation, completionCriteria: .removed) {
                showsGlobeCanvas = false
            } completion: {
                if morph == morphCount {
                    isGlobe = false
                }
            }
        } else {
            withAnimation(Self.morphAnimation, completionCriteria: .removed) {
                isGlobe = false
            } completion: {
                if morph == morphCount {
                    showsGlobeCanvas = false
                }
            }
        }
    }

    private func playHaptic() {
        guard hapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
}

/// Blurs the map and the globe while one turns into the other, most in the
/// middle of the change: `morph` follows the morph, and `fade` the
/// cross-fade standing in for it with Reduce Motion. Each only moves while
/// its own change animates.
private struct SwitchBlur: ViewModifier, Animatable {
    var morph: Double
    var fade: Double

    /// Past this the faint land dots fade away instead of blurring.
    private static let maximumRadius: CGFloat = 2.5

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(morph, fade) }
        set { (morph, fade) = (newValue.first, newValue.second) }
    }

    func body(content: Content) -> some View {
        content.blur(radius: Self.maximumRadius * max(sin(.pi * morph), sin(.pi * fade), 0))
    }
}

/// The globe canvas with its gestures: a drag turns the globe, which then
/// carries on with the drag's momentum, and a double tap goes back to the
/// map (or, on the way there, back to the globe).
private struct DotsGlobePane: View {
    let timeZoneIdentifiers: [String]
    let date: Date
    let isGlobe: Bool
    let onDoubleTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var motion = GlobeMotion(orientation: .mapCenter)
    /// Where the globe faced when the current drag began; nil between drags.
    @State private var dragStartOrientation: GlobeOrientation?
    @State private var globeRadius: CGFloat = 1

    /// No spin of its own with Reduce Motion, and no momentum after a drag.
    private var spinSpeed: Double {
        reduceMotion ? 0 : GlobeMotion.spinSpeed
    }

    var body: some View {
        TimelineView(.animation(paused: !isGlobe || dragStartOrientation != nil || reduceMotion)) { context in
            DotsGlobeCanvas(
                timeZoneIdentifiers: timeZoneIdentifiers,
                date: date,
                morph: isGlobe ? 1 : 0,
                orientation: motion.orientation(at: context.date, spinSpeed: spinSpeed)
            )
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            DotsGlobeCanvas.globeRadius(in: proxy.size)
        } action: { radius in
            globeRadius = radius
        }
        .contentShape(Rectangle())
        .gesture(drag)
        .onTapGesture(count: 2, perform: onDoubleTap)
        .onChange(of: isGlobe) { _, isGlobe in
            dragStartOrientation = nil
            if isGlobe {
                // The canvas wraps the map up facing its centre, then turns
                // to face the local time zone
                motion = GlobeMotion(orientation: .local, isSpinning: true)
            } else {
                // Held where it is while the canvas turns it back to the
                // map's centre, the short way round
                let orientation = motion.orientation(at: .now, spinSpeed: spinSpeed)
                motion = GlobeMotion(orientation: orientation.nearMapCenter)
            }
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard isGlobe else { return }
                let start = dragStartOrientation ?? motion.orientation(at: .now, spinSpeed: spinSpeed)
                dragStartOrientation = start
                motion = GlobeMotion(orientation: start.dragged(by: value.translation, globeRadius: globeRadius))
            }
            .onEnded { value in
                guard let start = dragStartOrientation else { return }
                dragStartOrientation = nil
                motion = GlobeMotion(
                    orientation: start.dragged(by: value.translation, globeRadius: globeRadius),
                    flingVelocity: reduceMotion
                        ? (yaw: 0, pitch: 0)
                        : GlobeOrientation.flingVelocity(for: value.velocity, globeRadius: globeRadius),
                    isSpinning: isGlobe
                )
            }
    }
}

/// Which way the globe faces: the longitude (yaw) and latitude (pitch) at
/// its centre, in degrees.
private struct GlobeOrientation {
    let yaw: Double
    let pitch: Double

    /// Kept short of the poles, which the map's artwork doesn't reach.
    private static let maximumPitch: Double = 70
    /// Fastest a fling can start turning the globe, in degrees per second.
    private static let maximumFlingSpeed: Double = 720

    init(yaw: Double, pitch: Double) {
        self.yaw = yaw
        self.pitch = min(max(pitch, -Self.maximumPitch), Self.maximumPitch)
    }

    /// Facing the middle of the flat map, where the globe wraps up from and
    /// unwraps to: the map's seam is then right behind the globe.
    static var mapCenter: GlobeOrientation {
        GlobeOrientation(yaw: DotsWorldMapCanvas.grid?.longitude(atUnitX: 0.5) ?? 0, pitch: 0)
    }

    /// Facing the local time zone, tipped toward its hemisphere by half its
    /// latitude.
    static var local: GlobeOrientation {
        let coordinate = TimeZoneCoordinates.getCoordinate(for: TimeZone.current.identifier)
        return GlobeOrientation(
            yaw: coordinate?.longitude ?? 0,
            pitch: (coordinate?.latitude ?? 0) / 2
        ).nearMapCenter
    }

    /// The same way round, with the yaw within half a turn of the map's
    /// centre, so turning between the two never goes the long way round.
    var nearMapCenter: GlobeOrientation {
        let center = Self.mapCenter.yaw
        var offset = (yaw - center).truncatingRemainder(dividingBy: 360)
        if offset >= 180 { offset -= 360 }
        if offset < -180 { offset += 360 }
        return GlobeOrientation(yaw: center + offset, pitch: pitch)
    }

    func interpolated(to other: GlobeOrientation, by fraction: Double) -> GlobeOrientation {
        GlobeOrientation(
            yaw: yaw + (other.yaw - yaw) * fraction,
            pitch: pitch + (other.pitch - pitch) * fraction
        )
    }

    /// Turned by a drag so the surface under the finger keeps up with it.
    func dragged(by translation: CGSize, globeRadius: CGFloat) -> GlobeOrientation {
        let degreesPerPoint = Self.degreesPerPoint(globeRadius: globeRadius)
        return GlobeOrientation(
            yaw: yaw - translation.width * degreesPerPoint,
            pitch: pitch + translation.height * degreesPerPoint
        )
    }

    /// Yaw and pitch speeds, in degrees per second, for a drag released at
    /// `velocity`.
    static func flingVelocity(for velocity: CGSize, globeRadius: CGFloat) -> (yaw: Double, pitch: Double) {
        let degreesPerPoint = degreesPerPoint(globeRadius: globeRadius)
        func clamped(_ speed: Double) -> Double {
            min(max(speed, -maximumFlingSpeed), maximumFlingSpeed)
        }
        return (
            yaw: clamped(-velocity.width * degreesPerPoint),
            pitch: clamped(velocity.height * degreesPerPoint)
        )
    }

    private static func degreesPerPoint(globeRadius: CGFloat) -> Double {
        180 / (.pi * max(globeRadius, 1))
    }
}

/// Where the globe faces over time: an orientation at a reference date,
/// carried on by the slow spin and what's left of a fling while the globe
/// turns on its own.
private struct GlobeMotion {
    var orientation: GlobeOrientation
    var referenceDate: Date = .now
    /// Yaw and pitch speeds at `referenceDate`, in degrees per second.
    var flingVelocity: (yaw: Double, pitch: Double) = (0, 0)
    /// Not while the globe is held, or turning back into the map.
    var isSpinning = false

    /// Degrees per second, west to east like the Earth.
    static let spinSpeed: Double = 5
    /// The spin eases in, rather than starting at full speed when a drag
    /// lets go or the globe has just wrapped up.
    private static let spinEaseIn: TimeInterval = 1.5
    /// How long a fling takes to lose about two thirds of its speed.
    private static let flingDecay: TimeInterval = 0.5

    func orientation(at date: Date, spinSpeed: Double) -> GlobeOrientation {
        guard isSpinning else { return orientation }
        let elapsed = max(date.timeIntervalSince(referenceDate), 0)
        let spin = spinSpeed * (elapsed - Self.spinEaseIn * (1 - exp(-elapsed / Self.spinEaseIn)))
        let fling = Self.flingDecay * (1 - exp(-elapsed / Self.flingDecay))
        return GlobeOrientation(
            yaw: orientation.yaw - spin + flingVelocity.yaw * fling,
            pitch: orientation.pitch + flingVelocity.pitch * fling
        )
    }
}

/// Draws the flat map (`morph` 0), the globe facing `orientation` (`morph`
/// 1), and the morph between them: each dot travels from its place on the
/// map to its place on the sphere. The map wraps up facing its centre,
/// turning to `orientation` only as it closes, and turns back before it
/// unwraps, so the map's seam stays behind the globe while the map is open.
private struct DotsGlobeCanvas: View, Animatable {
    let timeZoneIdentifiers: [String]
    let orientation: GlobeOrientation
    var morph: Double

    private let subsolarPoint: DotsWorldMapCanvas.SubsolarPoint

    init(timeZoneIdentifiers: [String], date: Date, morph: Double, orientation: GlobeOrientation) {
        self.timeZoneIdentifiers = timeZoneIdentifiers
        self.orientation = orientation
        self.morph = morph
        let subsolar = SolarCalculator.subsolarPoint(date: date)
        subsolarPoint = DotsWorldMapCanvas.SubsolarPoint(latitude: subsolar.latitude, longitude: subsolar.longitude)
    }

    var animatableData: Double {
        get { morph }
        set { morph = newValue }
    }

    static func globeRadius(in size: CGSize) -> CGFloat {
        min(size.width, size.height) / 2 * 0.9
    }

    var body: some View {
        if let grid = DotsWorldMapCanvas.grid, let lattice = DotsGlobeLattice.shared {
            // The same table the map draws its city dots from
            let citiesByCell = DotsWorldMapCanvas.citiesByCell(for: timeZoneIdentifiers, grid: grid)
            let addedCityDots = lattice.dots(nearest: timeZoneIdentifiers)

            Canvas { context, size in
                draw(in: context, size: size, grid: grid, lattice: lattice, citiesByCell: citiesByCell, addedCityDots: addedCityDots)
            }
            // Composites like the map, additively over what's behind it
            .blendMode(.plusLighter)
        }
    }

    private func draw(
        in context: GraphicsContext,
        size: CGSize,
        grid: DotsWorldMapGrid,
        lattice: DotsGlobeLattice,
        citiesByCell: [Int: [String]],
        addedCityDots: [DotsGlobeLattice.Dot]
    ) {
        guard size.width > 0, size.height > 0 else { return }
        let morph = min(max(self.morph, 0), 1)
        let flatMap = FlatMapFrame(grid: grid, in: size)
        let radius = Self.globeRadius(in: size)
        let globe = GlobeProjection(
            orientation: GlobeOrientation.mapCenter.interpolated(to: orientation, by: smoothstep(0.4, 1, morph)),
            center: CGPoint(x: size.width / 2, y: size.height / 2),
            radius: radius
        )
        let surface = SurfaceMorph(flatMap: flatMap, globe: globe, wrap: smoothstep(0, 0.7, morph))
        let sun = SurfacePoint(latitude: subsolarPoint.latitude, longitude: subsolarPoint.longitude).vector

        // The terminator stays on the map, gone before the map has moved much
        let terminatorOpacity = 1 - smoothstep(0, 0.15, morph)
        if terminatorOpacity > 0 {
            var terminatorContext = context
            terminatorContext.opacity = terminatorOpacity
            terminatorContext.translateBy(x: flatMap.origin.x, y: flatMap.origin.y)
            DotsWorldMapCanvas.drawTerminator(
                in: terminatorContext,
                size: flatMap.size,
                subsolar: subsolarPoint,
                grid: grid,
                layout: flatMap.layout
            )
        }

        var dots = DotBatch()
        // The map's own dots wrap up with it, handing over to the globe's
        // even lattice before they bunch up toward the poles, and quickly,
        // as the two grids don't line up
        let latticeOpacity = smoothstep(0.3, 0.55, morph)

        if latticeOpacity < 1 {
            for row in 0..<grid.rows {
                for column in 0..<grid.columns {
                    let cellIndex = row * grid.columns + column
                    let isCity = citiesByCell[cellIndex] != nil
                    guard isCity || grid.isLand(column: column, row: row) else { continue }
                    let point = lattice.mapCells[cellIndex]
                    let style = DotsWorldMapCanvas.dotStyle(
                        isCity: isCity,
                        isDay: (point.vector * sun).sum() > 0,
                        dotDiameter: flatMap.layout.dotDiameter
                    )
                    guard let placement = surface.placement(
                        ofMapDot: point,
                        at: flatMap.cellCenter(column: column, row: row),
                        diameter: style.diameter
                    ) else { continue }
                    dots.add(opacity: style.opacity * placement.visibility * (1 - latticeOpacity), transform: placement.transform)
                }
            }
        }

        if latticeOpacity > 0 {
            // Half the gap between neighbouring dots, in radians
            let dotDiameter = DotsGlobeLattice.spacing * .pi / 180 * 0.5
            for dot in lattice.dots {
                guard let placement = surface.placement(
                    ofGlobeDot: dot.point,
                    at: flatMap.point(unitX: dot.mapUnitX, unitY: dot.mapUnitY),
                    diameter: dot.isTimeZone ? dotDiameter * 1.15 : dotDiameter
                ) else { continue }
                // Dimmer in night, with a short twilight between
                let daylight = smoothstep(-0.08, 0.08, (dot.point.vector * sun).sum())
                let opacity = dot.isTimeZone ? 0.45 + 0.35 * daylight : 0.1 + 0.15 * daylight
                dots.add(opacity: opacity * placement.visibility * latticeOpacity, transform: placement.transform)
            }
            // Over their time zone's dot, sized like the map's city dots
            for dot in addedCityDots {
                guard let placement = surface.placement(
                    ofGlobeDot: dot.point,
                    at: flatMap.point(unitX: dot.mapUnitX, unitY: dot.mapUnitY),
                    diameter: dotDiameter * 2
                ) else { continue }
                dots.add(opacity: placement.visibility * latticeOpacity, transform: placement.transform)
            }
        }

        dots.fill(in: context)
    }
}

/// The aspect-fit rect the flat map draws in (see DotsWorldMapCanvas.Sizing),
/// so the canvas puts each dot exactly where the map does.
private struct FlatMapFrame {
    let origin: CGPoint
    let size: CGSize
    let layout: DotsWorldMapLayout
    /// Points per radian of longitude (x) and of latitude (y).
    let scale: (x: Double, y: Double)

    init(grid: DotsWorldMapGrid, in bounds: CGSize) {
        let aspectRatio = grid.canvasAspectRatio
        size = bounds.width / bounds.height > aspectRatio
            ? CGSize(width: bounds.height * aspectRatio, height: bounds.height)
            : CGSize(width: bounds.width, height: bounds.width / aspectRatio)
        origin = CGPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        layout = DotsWorldMapLayout(grid: grid, size: size)
        let longitudeSpan = (grid.longitude(atUnitX: 1) - grid.longitude(atUnitX: 0)) * .pi / 180
        let latitudeSpan = (grid.latitude(atUnitY: 0) - grid.latitude(atUnitY: 1)) * .pi / 180
        scale = (
            x: Double(layout.artworkFrame.width) / longitudeSpan,
            y: Double(layout.artworkFrame.height) / latitudeSpan
        )
    }

    func point(unitX: Double, unitY: Double) -> CGPoint {
        offset(layout.point(unitX: unitX, unitY: unitY))
    }

    func cellCenter(column: Int, row: Int) -> CGPoint {
        offset(layout.cellCenter(column: column, row: row))
    }

    private func offset(_ point: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + point.x, y: origin.y + point.y)
    }
}

/// An orthographic view of the unit sphere facing `orientation`.
private struct GlobeProjection {
    let center: CGPoint
    let radius: CGFloat
    /// The view's right, up and toward-the-viewer axes, in the lattice's
    /// Earth-fixed coordinates.
    private let east: SIMD3<Double>
    private let north: SIMD3<Double>
    private let forward: SIMD3<Double>

    init(orientation: GlobeOrientation, center: CGPoint, radius: CGFloat) {
        self.center = center
        self.radius = radius
        let yaw = orientation.yaw * .pi / 180
        let pitch = orientation.pitch * .pi / 180
        east = SIMD3(-sin(yaw), cos(yaw), 0)
        north = SIMD3(-sin(pitch) * cos(yaw), -sin(pitch) * sin(yaw), cos(pitch))
        forward = SIMD3(cos(pitch) * cos(yaw), cos(pitch) * sin(yaw), sin(pitch))
    }

    /// For a point on the unit sphere: its screen offset from the centre in
    /// radii (y pointing down), and its depth, 1 facing the viewer, 0 on the
    /// rim, negative on the far side. For a direction: its screen direction,
    /// and how much it points toward the viewer.
    func project(_ vector: SIMD3<Double>) -> (x: Double, y: Double, depth: Double) {
        ((vector * east).sum(), -(vector * north).sum(), (vector * forward).sum())
    }
}

/// Bends the flat map onto the globe: each spot travels `wrap` of the way
/// from its place on the map to its place on the sphere, and a dot bends
/// with the patch of surface under it, stretching, turning and
/// foreshortening with it.
private struct SurfaceMorph {
    let flatMap: FlatMapFrame
    let globe: GlobeProjection
    let wrap: Double

    struct Placement {
        /// Maps the unit circle onto the dot.
        let transform: CGAffineTransform
        /// How much of the dot shows, 0 where the surface faces away.
        let visibility: Double
    }

    /// How far into the side facing the viewer dots fade in, in the
    /// surface's foreshortening (1 face on, 0 edge on).
    private static let edgeFade: Double = 0.12

    /// A dot `diameter` points across on the flat map, which stretches with
    /// the map as it wraps up.
    func placement(ofMapDot point: SurfacePoint, at flatPoint: CGPoint, diameter: CGFloat) -> Placement? {
        placement(of: point, at: flatPoint, halfSize: (
            longitude: Double(diameter) / 2 / flatMap.scale.x,
            latitude: Double(diameter) / 2 / flatMap.scale.y
        ))
    }

    /// A dot `diameter` radians across that's round on the globe, and on the
    /// flat map, not stretched toward the poles like the map.
    func placement(ofGlobeDot point: SurfacePoint, at flatPoint: CGPoint, diameter: Double) -> Placement? {
        placement(of: point, at: flatPoint, halfSize: (
            longitude: diameter / 2 / (1 - wrap + wrap * point.cosLatitude),
            latitude: diameter / 2
        ))
    }

    /// `halfSize` is in radians of longitude and of latitude.
    private func placement(of point: SurfacePoint, at flatPoint: CGPoint, halfSize: (longitude: Double, latitude: Double)) -> Placement? {
        let radius = Double(globe.radius)
        let flatScale = flatMap.scale
        let onGlobe = globe.project(point.vector)
        let east = globe.project(point.east)
        let north = globe.project(point.north)

        // Screen distance per radian of longitude and of latitude around the
        // dot, from the map's (east right, north up) to the globe's
        let perLongitude = (
            x: (1 - wrap) * flatScale.x + wrap * radius * point.cosLatitude * east.x,
            y: wrap * radius * point.cosLatitude * east.y
        )
        let perLatitude = (
            x: wrap * radius * north.x,
            y: -(1 - wrap) * flatScale.y + wrap * radius * north.y
        )
        // The surface's foreshortening: 1 on the map, the depth on the globe,
        // and negative where the far side has folded over to face away
        let unfolded = ((1 - wrap) * flatScale.x + wrap * radius * point.cosLatitude)
            * ((1 - wrap) * flatScale.y + wrap * radius)
        let facing = (perLatitude.x * perLongitude.y - perLongitude.x * perLatitude.y) / unfolded
        // Dimmer toward the globe's rim, like a lit sphere
        let shading = 0.45 + 0.55 * max(onGlobe.depth, 0)
        let visibility = smoothstep(0, Self.edgeFade, facing) * (1 + (shading - 1) * wrap)
        guard visibility > 0 else { return nil }

        let globePoint = CGPoint(
            x: Double(globe.center.x) + radius * onGlobe.x,
            y: Double(globe.center.y) + radius * onGlobe.y
        )
        let progress = CGFloat(wrap)
        return Placement(
            transform: CGAffineTransform(
                a: perLongitude.x * halfSize.longitude,
                b: perLongitude.y * halfSize.longitude,
                c: perLatitude.x * halfSize.latitude,
                d: perLatitude.y * halfSize.latitude,
                tx: flatPoint.x + (globePoint.x - flatPoint.x) * progress,
                ty: flatPoint.y + (globePoint.y - flatPoint.y) * progress
            ),
            visibility: visibility
        )
    }
}

/// Dots gathered into one path per opacity step, so thousands of them fill
/// in a few dozen draws. The map's opacities (0.1, 0.25, 1) are exact steps.
private struct DotBatch {
    private static let opacitySteps = 40
    private static let unitCircle = CGRect(x: -1, y: -1, width: 2, height: 2)
    private var paths = [Path](repeating: Path(), count: opacitySteps + 1)

    mutating func add(opacity: Double, transform: CGAffineTransform) {
        let step = min(Int((opacity * Double(Self.opacitySteps)).rounded()), Self.opacitySteps)
        guard step > 0 else { return }
        paths[step].addEllipse(in: Self.unitCircle, transform: transform)
    }

    func fill(in context: GraphicsContext) {
        for step in 1...Self.opacitySteps where !paths[step].isEmpty {
            context.fill(paths[step], with: .color(.white.opacity(Double(step) / Double(Self.opacitySteps))))
        }
    }
}

/// A spot on the unit sphere, with the directions along the surface there.
private struct SurfacePoint {
    /// Earth-fixed: x toward 0°N 0°E, y toward 0°N 90°E, z toward the North
    /// Pole.
    let vector: SIMD3<Double>
    /// Unit vectors pointing east and north along the surface.
    let east: SIMD3<Double>
    let north: SIMD3<Double>
    let cosLatitude: Double

    init(latitude: Double, longitude: Double) {
        let latitude = latitude * .pi / 180
        let longitude = longitude * .pi / 180
        cosLatitude = cos(latitude)
        vector = SIMD3(cos(latitude) * cos(longitude), cos(latitude) * sin(longitude), sin(latitude))
        east = SIMD3(-sin(longitude), cos(longitude), 0)
        north = SIMD3(-sin(latitude) * cos(longitude), -sin(latitude) * sin(longitude), cos(latitude))
    }
}

/// The globe's dots, worked out once: an even lattice over the sphere, one
/// row every `spacing` degrees of latitude with as many dots as fit around
/// it, keeping the dots on land and every dot holding a supported time zone
/// (ocean islands included).
private struct DotsGlobeLattice {
    struct Dot {
        let point: SurfacePoint
        /// Where the dot sits on the flat map, in its artwork's unit space.
        let mapUnitX: Double
        let mapUnitY: Double
        let isTimeZone: Bool
    }

    /// Degrees between neighbouring dots.
    static let spacing: Double = 2

    /// Nil when the "WorldMap" asset is missing, like the map's grid.
    static let shared = DotsGlobeLattice()

    let dots: [Dot]
    /// The flat map's cell centres on the sphere, row-major, to carry its
    /// dots onto the globe.
    let mapCells: [SurfacePoint]
    private let mapGrid: DotsWorldMapGrid
    private let rowDotCounts: [Int]
    private let rowStartIndices: [Int]

    private init?() {
        // Land sampled about as finely as the lattice
        guard let mapGrid = DotsWorldMapCanvas.grid,
              let landGrid = DotsWorldMapGrid(imageName: "WorldMap", columns: Int(360 / Self.spacing)) else { return nil }

        let rowDotCounts = (0..<Int(180 / Self.spacing)).map { row in
            max(Int((360 * cos(Self.latitude(ofRow: row) * .pi / 180) / Self.spacing).rounded()), 1)
        }
        let rowStartIndices = rowDotCounts.reduce(into: [0]) { starts, count in
            starts.append(starts[starts.count - 1] + count)
        }
        self.mapGrid = mapGrid
        self.rowDotCounts = rowDotCounts
        self.rowStartIndices = rowStartIndices

        var timeZoneIndices = Set<Int>()
        for identifier in TimeZone.knownTimeZoneIdentifiers {
            guard let coordinate = TimeZoneCoordinates.getCoordinate(for: identifier) else { continue }
            let point = Self.latticePoint(latitude: coordinate.latitude, longitude: coordinate.longitude, rowDotCounts: rowDotCounts)
            timeZoneIndices.insert(rowStartIndices[point.row] + point.column)
        }

        var dots: [Dot] = []
        for row in rowDotCounts.indices {
            let latitude = Self.latitude(ofRow: row)
            for column in 0..<rowDotCounts[row] {
                let isTimeZone = timeZoneIndices.contains(rowStartIndices[row] + column)
                let longitude = Self.longitude(ofColumn: column, dotCount: rowDotCounts[row])
                guard isTimeZone || Self.isLand(latitude: latitude, longitude: longitude, in: landGrid) else { continue }
                dots.append(Self.dot(row: row, column: column, isTimeZone: isTimeZone, rowDotCounts: rowDotCounts, mapGrid: mapGrid))
            }
        }
        self.dots = dots

        mapCells = (0..<(mapGrid.rows * mapGrid.columns)).map { cellIndex in
            SurfacePoint(
                latitude: mapGrid.latitude(atUnitY: (Double(cellIndex / mapGrid.columns) + 0.5) / Double(mapGrid.rows)),
                longitude: mapGrid.longitude(atUnitX: (Double(cellIndex % mapGrid.columns) + 0.5) / Double(mapGrid.columns))
            )
        }
    }

    /// The lattice dots holding each identifier's time zone, one per dot.
    func dots(nearest identifiers: [String]) -> [Dot] {
        var latticeIndices = Set<Int>()
        return identifiers.compactMap { identifier in
            guard let coordinate = TimeZoneCoordinates.getCoordinate(for: identifier) else { return nil }
            let point = Self.latticePoint(latitude: coordinate.latitude, longitude: coordinate.longitude, rowDotCounts: rowDotCounts)
            guard latticeIndices.insert(rowStartIndices[point.row] + point.column).inserted else { return nil }
            return Self.dot(row: point.row, column: point.column, isTimeZone: true, rowDotCounts: rowDotCounts, mapGrid: mapGrid)
        }
    }

    private static func latitude(ofRow row: Int) -> Double {
        90 - (Double(row) + 0.5) * spacing
    }

    private static func longitude(ofColumn column: Int, dotCount: Int) -> Double {
        -180 + (Double(column) + 0.5) * 360 / Double(dotCount)
    }

    /// The lattice dot whose patch of the sphere holds a coordinate.
    private static func latticePoint(latitude: Double, longitude: Double, rowDotCounts: [Int]) -> (row: Int, column: Int) {
        let row = min(max(Int((90 - latitude) / spacing), 0), rowDotCounts.count - 1)
        var offset = (longitude + 180).truncatingRemainder(dividingBy: 360)
        if offset < 0 { offset += 360 }
        let dotCount = rowDotCounts[row]
        return (row, min(Int(offset / 360 * Double(dotCount)), dotCount - 1))
    }

    private static func dot(row: Int, column: Int, isTimeZone: Bool, rowDotCounts: [Int], mapGrid: DotsWorldMapGrid) -> Dot {
        let latitude = latitude(ofRow: row)
        let longitude = longitude(ofColumn: column, dotCount: rowDotCounts[row])
        return Dot(
            point: SurfacePoint(latitude: latitude, longitude: longitude),
            mapUnitX: mapGrid.unitX(longitude: longitude),
            mapUnitY: mapGrid.unitY(latitude: latitude),
            isTimeZone: isTimeZone
        )
    }

    /// Beyond the artwork's latitudes the Antarctic interior is land and the
    /// Arctic Ocean isn't.
    private static func isLand(latitude: Double, longitude: Double, in grid: DotsWorldMapGrid) -> Bool {
        if latitude > grid.latitude(atUnitY: 0) { return false }
        if latitude < grid.latitude(atUnitY: 1) { return true }
        let cell = grid.cell(latitude: latitude, longitude: longitude)
        return grid.isLand(column: cell.column, row: cell.row)
    }
}

/// 0 up to `edge0`, 1 from `edge1`, easing in and out in between.
private func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
    let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
    return t * t * (3 - 2 * t)
}
