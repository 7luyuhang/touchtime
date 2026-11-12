//
//  AboutSheet.swift
//  touchtimeWatch
//

import SwiftUI

/// The app's icon, flown up from the end of Settings to the middle of the
/// screen, big and in glass, with the app's name and who made it turning
/// clockwise around it.
struct AboutSheet: View {
    /// The icon at the end of Settings, in global coordinates, which the big
    /// icon grows out of and shrinks back into.
    let sourceFrame: CGRect
    /// Called once the icon is back in Settings.
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The icon big in the middle, rather than small in Settings.
    @State private var isExpanded = false
    /// The time the ring's turns count from: when About opened.
    @State private var ringStart = Date.now

    /// One turn of the ring, in seconds.
    private static let turnDuration: TimeInterval = 20

    private var designedBy: String {
        String(localized: "Designed & built by yuhang in London")
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()
                .opacity(isExpanded ? 1 : 0)

            // Just for the close button, where a sheet's is
            NavigationStack {
                Color.clear
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close", systemImage: "xmark", action: close)
                        }
                    }
            }
            .opacity(isExpanded ? 1 : 0)

            GeometryReader { proxy in
                emblem(in: proxy.frame(in: .global))
            }
        }
        .accessibilityAddTraits(.isModal)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
                isExpanded = true
            }
        }
    }

    /// The icon in its glass and the ring around it, in the middle of
    /// `bounds`, the safe area in global coordinates, so below the time and the
    /// close button rather than in the middle of the screen.
    @ViewBuilder
    private func emblem(in bounds: CGRect) -> some View {
        let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let glassDiameter = bounds.width / 2
        // The glass shows only around the icon, which covers what's behind it.
        let glassInset = glassDiameter * 0.08
        let fontSize = bounds.width / 16
        // Through the middle of the ring's letters, just clear of the glass.
        let ringRadius = glassDiameter / 2 + bounds.width * 0.04 + fontSize * 0.6

        TimelineView(.animation(paused: reduceMotion)) { context in
            let turns = context.date.timeIntervalSince(ringStart) / Self.turnDuration
            RingText(
                text: "Touch Time · \(designedBy) · ".localizedUppercase,
                radius: ringRadius,
                font: .system(size: fontSize, weight: .semibold, design: .rounded)
            )
            .rotationEffect(.degrees(turns.truncatingRemainder(dividingBy: 1) * 360))
        }
        .frame(width: (ringRadius + fontSize) * 2, height: (ringRadius + fontSize) * 2)
        // Spreads out from the icon as it lands, and is gone before it's back.
        .opacity(isExpanded ? 1 : 0)
        .scaleEffect(isExpanded ? 1 : 0.6)
        .blur(radius: isExpanded ? 0 : 8)
        .animation(isExpanded ? .smooth(duration: 0.8).delay(0.1) : .smooth(duration: 0.25), value: isExpanded)
        .position(center)
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: "Touch Time, \(designedBy)"))

        Image("TouchTimeAppIcon")
            .resizable()
            .scaledToFit()
            .padding(isExpanded ? glassInset : 0)
            .glassEffect(isExpanded ? .clear.interactive() : .identity, in: Circle())
            .frame(
                width: isExpanded ? glassDiameter : sourceFrame.width,
                height: isExpanded ? glassDiameter : sourceFrame.height
            )
            .position(isExpanded ? center : CGPoint(x: sourceFrame.midX - bounds.minX, y: sourceFrame.midY - bounds.minY))
            .accessibilityHidden(true)
    }

    private func close() {
        withAnimation(.smooth(duration: 0.4)) {
            isExpanded = false
        } completion: {
            onDismiss()
        }
    }
}

/// A line of text all the way around a circle about the middle of its frame,
/// reading clockwise from the top with its letters' tops outward, spaced out
/// evenly so its end meets its start.
private struct RingText: View {
    let text: String
    /// Through the middle of the letters.
    let radius: CGFloat
    let font: Font

    var body: some View {
        Canvas { context, size in
            let characters = text.map { character in
                context.resolve(
                    Text(verbatim: String(character))
                        .font(font)
                        .foregroundStyle(.primary)
                )
            }
            let widths = characters.map { $0.measure(in: size).width }
            let length = widths.reduce(0, +)
            let circumference = 2 * .pi * radius
            // Shrinks only a text too long to go around once.
            let scale = min(1, circumference / length)
            let spacing = (circumference - length * scale) / CGFloat(characters.count)

            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            // Along the circle, clockwise from the top, to the character's start.
            var distance: CGFloat = 0
            for (character, width) in zip(characters, widths) {
                let angle = (distance + width * scale / 2) / radius
                distance += width * scale + spacing
                var glyph = context
                glyph.translateBy(x: center.x + radius * sin(angle), y: center.y - radius * cos(angle))
                glyph.rotate(by: .radians(angle))
                glyph.scaleBy(x: scale, y: scale)
                glyph.draw(character, at: .zero)
            }
        }
    }
}
