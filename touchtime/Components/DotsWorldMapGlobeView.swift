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
