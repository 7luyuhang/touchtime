//
//  CityMapView.swift
//  touchtimeWatch
//

import SwiftUI

/// The iPhone app's dotted world map with the day/night line, every clock's
/// city dotted on it and the shown city's dot in the accent color, centered
/// above `footer`. A tap wraps the map up into the Search tab's dotted globe,
/// facing the spot tapped, and `footer` blurs away to make room for it. The
/// globe spins slowly and follows a drag, and a tap turns it back into the
/// map. With Reduce Motion the map and the globe cross-fade instead, and the
/// globe holds still.
struct CityMapView<Footer: View>: View {
    let date: Date
    let timeZoneIdentifiers: [String]
    let highlightedTimeZoneIdentifier: String
    /// Whether the map has turned, or is turning, into the globe.
    @Binding var isGlobe: Bool
    @ViewBuilder let footer: Footer

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Whether the globe canvas stands in for the map: from the tap that
    /// starts the morph until the morph back has settled. At rest the canvas
    /// draws exactly the map, so neither swap shows; with Reduce Motion the
    /// swap is the change, a cross-fade.
    @State private var showsGlobeCanvas = false
    /// Counts the morphs, so a morph back to the map that was overtaken by
    /// another morph doesn't hand over to the map when it ends.
    @State private var morphCount = 0
    /// Which way the globe turns to face as it wraps up: the spot tapped on
    /// the map, or nil to turn back the way it faced, when it's tapped on its
    /// way back to the map.
    @State private var globeFacing: GlobeOrientation?
    /// The map's frame in the globe's room, where the globe wraps up from.
    @State private var mapFrame: CGRect = .zero
    /// The navigation bar's height, above the map.
    @State private var navigationBarHeight: CGFloat = 0

    /// Wider than the map's own 16:9, squashing latitude a little like the
    /// medium widget does, so the map can span the screen and still leave
    /// room for the clock below it.
    private static var aspectRatio: CGFloat { 2.3 }
    private static var morphAnimation: Animation { .smooth(duration: 1.2) }
    private static var fadeAnimation: Animation { .easeInOut(duration: 0.3) }
    private static var globeRoom: NamedCoordinateSpace { .named("CityMapView.globeRoom") }

    /// How far the globe reaches up into the navigation bar: through the
    /// line under the watch's time, which World Clock leaves without a
    /// title, and short of the time, which takes about the bar's top half.
    private var globeRise: CGFloat {
        navigationBarHeight * 0.45
    }

    var body: some View {
        ZStack(alignment: .top) {
            CityGlobePane(
                timeZoneIdentifiers: timeZoneIdentifiers,
                highlightedTimeZoneIdentifier: highlightedTimeZoneIdentifier,
                date: date,
                isGlobe: isGlobe,
                facing: globeFacing,
                mapFrame: mapFrame.offsetBy(dx: 0, dy: globeRise),
                onTap: { isGlobe ? showMap() : showGlobe(facing: nil) }
            )
            .padding(.top, -globeRise)
            .opacity(showsGlobeCanvas ? 1 : 0)
            .allowsHitTesting(showsGlobeCanvas)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                map
                    .opacity(showsGlobeCanvas ? 0 : 1)
                    .allowsHitTesting(!showsGlobeCanvas)
                    .accessibilityHidden(true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Holds its room while the globe shows, so the map, centered
                // above it, stays put
                ZStack(alignment: .leading) {
                    footer
                        .hidden()
                        .accessibilityHidden(true)
                    if !isGlobe {
                        footer
                            .transition(.blurReplace)
                    }
                }
            }
        }
        .coordinateSpace(Self.globeRoom)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.safeAreaInsets.top
        } action: { height in
            navigationBarHeight = height
        }
    }

    @ViewBuilder
    private var map: some View {
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
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: Self.globeRoom)
                } action: { frame in
                    mapFrame = frame
                }
                .contentShape(Rectangle())
                .onTapGesture { location in
                    showGlobe(facing: orientation(at: location, grid: grid))
                }
        }
    }

    /// Facing the latitude and longitude under a point on the map.
    private func orientation(at location: CGPoint, grid: DotsWorldMapGrid) -> GlobeOrientation? {
        guard mapFrame.width > 0 else { return nil }
        let artworkFrame = DotsWorldMapLayout(grid: grid, size: mapFrame.size).artworkFrame
        return GlobeOrientation(
            yaw: grid.longitude(atUnitX: (location.x - artworkFrame.minX) / artworkFrame.width),
            pitch: grid.latitude(atUnitY: (location.y - artworkFrame.minY) / artworkFrame.height)
        )
    }

    private func showGlobe(facing: GlobeOrientation?) {
        globeFacing = facing
        morphCount += 1
        if reduceMotion {
            withAnimation(Self.fadeAnimation) {
                isGlobe = true
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
        morphCount += 1
        let morph = morphCount
        if reduceMotion {
            withAnimation(Self.fadeAnimation) {
                isGlobe = false
                showsGlobeCanvas = false
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
}

/// The globe canvas with its gestures: a drag turns the globe, which then
/// carries on with the drag's momentum, and a tap goes back to the map (or,
/// on the way there, back to the globe).
private struct CityGlobePane: View {
    let timeZoneIdentifiers: [String]
    let highlightedTimeZoneIdentifier: String
    let date: Date
    let isGlobe: Bool
    /// Which way the globe turns to face as it wraps up; nil to face the way
    /// it did before it began turning back into the map.
    let facing: GlobeOrientation?
    /// The map's frame in the pane, where the globe wraps up from.
    let mapFrame: CGRect
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @State private var motion = GlobeMotion(orientation: .mapCenter)
    /// Where the globe faced when the current drag began; nil between drags.
    @State private var dragStartOrientation: GlobeOrientation?
    @State private var canvasSize: CGSize = .zero

    /// More opaque than the map's, as the daytime sky washes out the globe's
    /// dots, which also dim toward its rim.
    private static let landDotOpacityScale: Double = 1.8

    /// No spin of its own with Reduce Motion, and no momentum after a drag.
    private var spinSpeed: Double {
        reduceMotion ? 0 : GlobeMotion.spinSpeed
    }

    private var globeRadius: CGFloat {
        DotsGlobeCanvas.globeRadius(in: canvasSize)
    }

    var body: some View {
        // Ticks only while the globe turns on its own, and not while the
        // screen dims with the wrist down
        TimelineView(.animation(paused: !isGlobe || !motion.isSpinning || reduceMotion || isLuminanceReduced)) { context in
            DotsGlobeCanvas(
                timeZoneIdentifiers: timeZoneIdentifiers,
                date: date,
                // With Reduce Motion it only shows as the globe, which
                // cross-fades with the map
                morph: isGlobe || reduceMotion ? 1 : 0,
                orientation: motion.orientation(at: context.date, spinSpeed: spinSpeed),
                mapFrame: mapFrame,
                highlightedTimeZoneIdentifier: highlightedTimeZoneIdentifier,
                landDotOpacityScale: Self.landDotOpacityScale
            )
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            canvasSize = size
        }
        // On and just around the globe
        .contentShape(Circle())
        .gesture(drag)
        .onTapGesture(perform: onTap)
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
}
