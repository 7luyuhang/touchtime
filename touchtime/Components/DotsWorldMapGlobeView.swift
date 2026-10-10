//
//  DotsWorldMapGlobeView.swift
//  touchtime
//
//  Created on 09/10/2026.
//

import SwiftUI
import UIKit

/// The dotted world map that turns into a dotted 3D globe centred on the
/// spot double tapped, for the Search tab's map pane beside the list on
/// iPhone Duo in landscape. The globe looks like the map, terminator
/// included, with ocean islands that have a time zone dotted too; it spins
/// slowly and follows a drag, a tap on an added city's dot names its cities
/// as on the map, and a double tap turns it back into the map, blurring
/// through the middle of each change. With Reduce Motion the map and the
/// globe cross-fade instead, and the globe holds still.
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
    /// Which way the globe turns to face as it wraps up: the spot double
    /// tapped on the map, or nil to turn back the way it faced, when it's
    /// double tapped on its way back to the map.
    @State private var globeFacing: GlobeOrientation?

    private static let morphAnimation = Animation.smooth(duration: 1.2)
    private static let fadeAnimation = Animation.easeInOut(duration: 0.3)

    var body: some View {
        ZStack {
            DotsWorldMapView(
                timeZoneIdentifiers: timeZoneIdentifiers,
                date: date,
                onDoubleTap: { latitude, longitude in
                    showGlobe(facing: GlobeOrientation(yaw: longitude, pitch: latitude))
                }
            )
            .opacity(showsGlobeCanvas ? 0 : 1)
            .allowsHitTesting(!showsGlobeCanvas)

            DotsGlobePane(
                timeZoneIdentifiers: timeZoneIdentifiers,
                date: date,
                isGlobe: isGlobe,
                facing: globeFacing,
                onDoubleTap: { isGlobe ? showMap() : showGlobe(facing: nil) }
            )
            .opacity(showsGlobeCanvas ? 1 : 0)
            .allowsHitTesting(showsGlobeCanvas)
        }
        .modifier(SwitchBlur(morph: isGlobe ? 1 : 0, fade: showsGlobeCanvas ? 1 : 0))
    }

    private func showGlobe(facing: GlobeOrientation?) {
        globeFacing = facing
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
/// carries on with the drag's momentum; a tap on an added city's dot lists
/// its cities in a popover, like the map; and a double tap goes back to the
/// map (or, on the way there, back to the globe).
private struct DotsGlobePane: View {
    let timeZoneIdentifiers: [String]
    let date: Date
    let isGlobe: Bool
    /// Which way the globe turns to face as it wraps up; nil to face the way
    /// it did before it began turning back into the map.
    let facing: GlobeOrientation?
    let onDoubleTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @State private var motion = GlobeMotion(orientation: .mapCenter)
    /// Where the globe faced when the current drag began; nil between drags.
    @State private var dragStartOrientation: GlobeOrientation?
    @State private var canvasSize: CGSize = .zero
    @State private var selection: GlobeCitySelection?

    /// No spin of its own with Reduce Motion, and no momentum after a drag.
    private var spinSpeed: Double {
        reduceMotion ? 0 : GlobeMotion.spinSpeed
    }

    private var globeRadius: CGFloat {
        DotsGlobeCanvas.globeRadius(in: canvasSize)
    }

    var body: some View {
        // Ticks only while the globe turns on its own: not while it's
        // dragged, nor while a city's popover holds it still
        TimelineView(.animation(paused: !isGlobe || !motion.isSpinning || reduceMotion)) { context in
            DotsGlobeCanvas(
                timeZoneIdentifiers: timeZoneIdentifiers,
                date: date,
                morph: isGlobe ? 1 : 0,
                orientation: motion.orientation(at: context.date, spinSpeed: spinSpeed)
            )
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            canvasSize = size
        }
        .contentShape(Rectangle())
        .gesture(drag)
        // Ahead of the single tap, so a double tap isn't also taken as one
        .onTapGesture(count: 2, perform: onDoubleTap)
        .onTapGesture { location in
            selectCity(at: location)
        }
        .popover(item: $selection, attachmentAnchor: .rect(.rect(selection?.anchor ?? .zero))) { selected in
            DotsWorldMapCitiesPopover(identifiers: selected.identifiers)
        }
        .onChange(of: selection == nil) { _, isDismissed in
            if isDismissed, isGlobe {
                motion = GlobeMotion(orientation: motion.orientation, isSpinning: true)
            }
        }
        .onChange(of: isGlobe) { _, isGlobe in
            dragStartOrientation = nil
            if isGlobe {
                // The canvas wraps the map up facing its centre, then turns
                // to face this
                motion = GlobeMotion(orientation: facing ?? motion.orientation, isSpinning: true)
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

    /// Opens the popover for the added city's dot nearest a tap, among those
    /// facing the viewer, and holds the globe still so the dot stays under
    /// the popover's arrow.
    private func selectCity(at location: CGPoint) {
        guard isGlobe, canvasSize.width > 0, let lattice = DotsGlobeLattice.shared else { return }
        let orientation = motion.orientation(at: .now, spinSpeed: spinSpeed)
        let globe = GlobeProjection(
            orientation: orientation,
            center: CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2),
            radius: globeRadius
        )

        var nearest: (cityDot: DotsGlobeLattice.CityDot, point: CGPoint, distance: CGFloat)?
        for cityDot in lattice.cityDots(for: timeZoneIdentifiers) {
            let projected = globe.project(cityDot.dot.point.vector)
            // At least half shown, the rim fading dots out
            guard projected.depth > SurfaceMorph.edgeFade / 2 else { continue }
            let point = CGPoint(
                x: globe.center.x + globe.radius * projected.x,
                y: globe.center.y + globe.radius * projected.y
            )
            let distance = hypot(point.x - location.x, point.y - location.y)
            if distance <= DotsWorldMapView.tapTolerance, distance < (nearest?.distance ?? .infinity) {
                nearest = (cityDot, point, distance)
            }
        }
        guard let nearest else { return }

        if hapticEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        motion = GlobeMotion(orientation: orientation)
        let dotSize = globeRadius * CGFloat(DotsGlobeCanvas.cityDotDiameter)
        selection = GlobeCitySelection(
            id: nearest.cityDot.dot.id,
            identifiers: nearest.cityDot.identifiers,
            anchor: CGRect(
                x: nearest.point.x - dotSize / 2,
                y: nearest.point.y - dotSize / 2,
                width: dotSize,
                height: dotSize
            )
        )
    }
}

/// An added city's dot tapped on the globe: its cities, and where it is on
/// screen for the popover's arrow.
private struct GlobeCitySelection: Identifiable {
    /// The dot's index in the lattice.
    let id: Int
    let identifiers: [String]
    let anchor: CGRect
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

    /// Half the gap between neighbouring lattice dots, in radians.
    static let dotDiameter = DotsGlobeLattice.spacing * .pi / 180 * 0.5
    /// Twice the plain dots, like the map's city dots.
    static let cityDotDiameter = dotDiameter * 2

    var body: some View {
        if let grid = DotsWorldMapCanvas.grid, let lattice = DotsGlobeLattice.shared {
            // The same table the map draws its city dots from
            let citiesByCell = DotsWorldMapCanvas.citiesByCell(for: timeZoneIdentifiers, grid: grid)
            let cityDots = lattice.cityDots(for: timeZoneIdentifiers)

            Canvas { context, size in
                draw(in: context, size: size, grid: grid, lattice: lattice, citiesByCell: citiesByCell, cityDots: cityDots)
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
        cityDots: [DotsGlobeLattice.CityDot]
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
        let subsolar = SurfacePoint(latitude: subsolarPoint.latitude, longitude: subsolarPoint.longitude)
        let sun = subsolar.vector

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
            // A city's dot hides the dot under it, which would otherwise
            // brighten its middle wherever the city's dot is dimmed
            let cityDotIDs = Set(cityDots.map(\.dot.id))
            for dot in lattice.dots where !cityDotIDs.contains(dot.id) {
                guard let placement = surface.placement(
                    ofGlobeDot: dot.point,
                    at: flatMap.point(unitX: dot.mapUnitX, unitY: dot.mapUnitY),
                    diameter: Self.dotDiameter
                ) else { continue }
                // 0.1 in night to 0.25 in daylight like the map's land dots,
                // with a short twilight between
                let daylight = smoothstep(-0.08, 0.08, (dot.point.vector * sun).sum())
                dots.add(opacity: (0.1 + 0.15 * daylight) * placement.visibility * latticeOpacity, transform: placement.transform)
            }
            for cityDot in cityDots {
                let dot = cityDot.dot
                guard let placement = surface.placement(
                    ofGlobeDot: dot.point,
                    at: flatMap.point(unitX: dot.mapUnitX, unitY: dot.mapUnitY),
                    diameter: Self.cityDotDiameter
                ) else { continue }
                dots.add(opacity: placement.visibility * latticeOpacity, transform: placement.transform)
            }
        }

        dots.fill(in: context)

        // Over the dots, as on the map. The map's terminator is gone before
        // the map has moved much, and the globe's shows up only once the map
        // has wrapped up
        let mapTerminatorOpacity = 1 - smoothstep(0, 0.15, morph)
        if mapTerminatorOpacity > 0 {
            var terminatorContext = context
            terminatorContext.opacity = mapTerminatorOpacity
            terminatorContext.translateBy(x: flatMap.origin.x, y: flatMap.origin.y)
            DotsWorldMapCanvas.drawTerminator(
                in: terminatorContext,
                size: flatMap.size,
                subsolar: subsolarPoint,
                grid: grid,
                layout: flatMap.layout
            )
        }
        let globeTerminatorOpacity = smoothstep(0.7, 1, morph)
        if globeTerminatorOpacity > 0 {
            var terminatorContext = context
            terminatorContext.opacity = globeTerminatorOpacity
            drawGlobeTerminator(in: terminatorContext, globe: globe, subsolar: subsolar)
        }
    }

    /// The great circle where the sun is on the horizon, a quarter turn
    /// round the globe from the subsolar point, stroked like the map's
    /// terminator over the globe's side facing the viewer.
    private func drawGlobeTerminator(in context: GraphicsContext, globe: GlobeProjection, subsolar: SurfacePoint) {
        // The visible half, from rim to rim, centred on the circle's point
        // nearest the viewer
        let nearestAngle = atan2(globe.project(subsolar.north).depth, globe.project(subsolar.east).depth)
        // Half a degree apart, close enough to read as a smooth curve
        let segments = 360
        var curve = Path()
        for index in 0...segments {
            let angle = nearestAngle + .pi * (Double(index) / Double(segments) - 0.5)
            let projected = globe.project(subsolar.east * cos(angle) + subsolar.north * sin(angle))
            let point = CGPoint(
                x: Double(globe.center.x) + Double(globe.radius) * projected.x,
                y: Double(globe.center.y) + Double(globe.radius) * projected.y
            )
            if index == 0 {
                curve.move(to: point)
            } else {
                curve.addLine(to: point)
            }
        }

        var curveContext = context
        curveContext.blendMode = .plusLighter
        curveContext.clipToLayer { mask in
            let globeRect = CGRect(
                x: globe.center.x - globe.radius,
                y: globe.center.y - globe.radius,
                width: globe.radius * 2,
                height: globe.radius * 2
            )
            mask.fill(
                Path(ellipseIn: globeRect),
                with: .radialGradient(Self.terminatorRimFade, center: globe.center, startRadius: 0, endRadius: globe.radius)
            )
        }
        curveContext.stroke(
            curve,
            with: .color(.white.opacity(0.25)),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
        )
    }

    /// How much of the globe's terminator shows from the globe's centre
    /// (location 0) out to its rim (1): as much as a dot would there.
    private static let terminatorRimFade: Gradient = {
        let stopCount = 24
        return Gradient(stops: (0...stopCount).map { index in
            // Even steps of depth, which bunch up toward the rim, where the
            // fade is
            let depth = 1 - Double(index) / Double(stopCount)
            return Gradient.Stop(
                color: .white.opacity(smoothstep(0, SurfaceMorph.edgeFade, depth) * SurfaceMorph.shading(depth: depth)),
                location: (1 - depth * depth).squareRoot()
            )
        })
    }()
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
    static let edgeFade: Double = 0.12

    /// Dimmer toward the globe's rim, like a lit sphere: 1 face on, 0.45 at
    /// the rim, for a depth as GlobeProjection.project gives it.
    static func shading(depth: Double) -> Double {
        0.45 + 0.55 * max(depth, 0)
    }

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
        let shading = Self.shading(depth: onGlobe.depth)
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
        /// The dot's index in the lattice, counting row by row.
        let id: Int
        let point: SurfacePoint
        /// Where the dot sits on the flat map, in its artwork's unit space.
        let mapUnitX: Double
        let mapUnitY: Double
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
                let index = rowStartIndices[row] + column
                let longitude = Self.longitude(ofColumn: column, dotCount: rowDotCounts[row])
                guard timeZoneIndices.contains(index) || Self.isLand(latitude: latitude, longitude: longitude, in: landGrid) else { continue }
                dots.append(Self.dot(id: index, row: row, column: column, rowDotCounts: rowDotCounts, mapGrid: mapGrid))
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

    /// A lattice dot holding the time zones of one or more of the cities.
    struct CityDot {
        let dot: Dot
        var identifiers: [String]
    }

    /// The lattice dots holding the cities' time zones, each listing its
    /// cities in the order given.
    func cityDots(for identifiers: [String]) -> [CityDot] {
        var cityDots: [CityDot] = []
        var positionsByLatticeIndex: [Int: Int] = [:]
        for identifier in identifiers {
            guard let coordinate = TimeZoneCoordinates.getCoordinate(for: identifier) else { continue }
            let point = Self.latticePoint(latitude: coordinate.latitude, longitude: coordinate.longitude, rowDotCounts: rowDotCounts)
            let latticeIndex = rowStartIndices[point.row] + point.column
            if let position = positionsByLatticeIndex[latticeIndex] {
                cityDots[position].identifiers.append(identifier)
            } else {
                positionsByLatticeIndex[latticeIndex] = cityDots.count
                cityDots.append(CityDot(
                    dot: Self.dot(id: latticeIndex, row: point.row, column: point.column, rowDotCounts: rowDotCounts, mapGrid: mapGrid),
                    identifiers: [identifier]
                ))
            }
        }
        return cityDots
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

    private static func dot(id: Int, row: Int, column: Int, rowDotCounts: [Int], mapGrid: DotsWorldMapGrid) -> Dot {
        let latitude = latitude(ofRow: row)
        let longitude = longitude(ofColumn: column, dotCount: rowDotCounts[row])
        return Dot(
            id: id,
            point: SurfacePoint(latitude: latitude, longitude: longitude),
            mapUnitX: mapGrid.unitX(longitude: longitude),
            mapUnitY: mapGrid.unitY(latitude: latitude)
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
