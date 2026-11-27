//
//  MarqueeText.swift
//  touchtime
//
//  Shared between the iPhone and Apple Watch apps.
//

import SwiftUI

/// One line of text, at `alignment` when it fits. When it's too long, it
/// fades out at the trailing edge and, a moment after it appears, scrolls
/// through once until it comes back around to its start, like a long
/// navigation title.
struct MarqueeText: View {
    let content: String
    let alignment: HorizontalAlignment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    @State private var width: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var travelled: CGFloat = 0
    /// True until an enclosing scroll view reports the line out of view, so a
    /// line below the fold waits to scroll until it's actually seen.
    @State private var isVisible = true

    private static let gap: CGFloat = 16
    private static let fadeWidth: CGFloat = 15
    /// In points a second.
    private static let speed: CGFloat = 30
    private static let delay: Duration = .seconds(1)

    private struct ScrollKey: Equatable {
        let content: String
        let distance: CGFloat
    }

    init(_ content: String, alignment: HorizontalAlignment = .center) {
        self.content = content
        self.alignment = alignment
    }

    /// From the text's start to where it comes around again, or zero when
    /// the text fits.
    private var distance: CGFloat {
        // Not before layout, and not for an overflow that's only rounding.
        width > 0 && textWidth > width + 0.5 ? textWidth + Self.gap : 0
    }

    private var scrollKey: ScrollKey? {
        guard distance > 0, isVisible, !reduceMotion, !isLuminanceReduced else { return nil }
        return ScrollKey(content: content, distance: distance)
    }

    var body: some View {
        Text(content)
            .fixedSize()
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                textWidth = newWidth
            }
            .hidden()
            .frame(minWidth: 0, maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                width = newWidth
            }
            .overlay {
                HStack(spacing: Self.gap) {
                    Text(content)
                    if distance > 0 {
                        Text(content)
                    }
                }
                .fixedSize()
                .modifier(MarqueeScroll(travelled: travelled, distance: distance, fadeWidth: Self.fadeWidth, alignment: alignment))
            }
            .onScrollVisibilityChange { isVisible = $0 }
            .task(id: scrollKey) {
                resetTravelled()
                guard let scrollKey else { return }
                try? await Task.sleep(for: Self.delay)
                guard !Task.isCancelled else { return }
                let duration = scrollKey.distance / Self.speed
                withAnimation(.linear(duration: duration)) {
                    travelled = scrollKey.distance
                }
                try? await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled else { return }
                // The second copy now sits where the first began.
                resetTravelled()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(content))
    }

    private func resetTravelled() {
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) {
            travelled = 0
        }
    }
}

/// The line moved `travelled` points toward its leading edge. While it
/// overflows, its trailing edge fades, and so does its leading edge once the
/// text has moved off it. At `alignment` while it fits.
private struct MarqueeScroll: ViewModifier, Animatable {
    var travelled: CGFloat
    let distance: CGFloat
    let fadeWidth: CGFloat
    let alignment: HorizontalAlignment

    var animatableData: CGFloat {
        get { travelled }
        set { travelled = newValue }
    }

    func body(content: Content) -> some View {
        let overflows = distance > 0
        // Gone again by the time the second copy arrives, so the line comes
        // to rest as it began.
        let leadingFade = overflows ? max(0, min(1, travelled / fadeWidth, (distance - travelled) / fadeWidth)) : 0

        content
            .offset(x: -travelled)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: overflows ? .leading : Alignment(horizontal: alignment, vertical: .center))
            .mask {
                HStack(spacing: 0) {
                    LinearGradient(colors: [.black.opacity(1 - leadingFade), .black], startPoint: .leading, endPoint: .trailing)
                        .frame(width: fadeWidth)
                    Rectangle()
                    LinearGradient(colors: [.black, .black.opacity(overflows ? 0 : 1)], startPoint: .leading, endPoint: .trailing)
                        .frame(width: fadeWidth)
                }
            }
    }
}

#Preview {
    VStack(spacing: 12) {
        MarqueeText("Cloudy")
        MarqueeText("Scattered Thunderstorms")
    }
    .font(.subheadline)
    .frame(width: 90)
}
