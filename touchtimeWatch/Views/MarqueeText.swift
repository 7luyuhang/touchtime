//
//  MarqueeText.swift
//  touchtimeWatch
//

import SwiftUI

/// One line of text, centered when it fits. When it's too long, it fades out
/// at the trailing edge and, a moment after it appears, scrolls through once
/// until it comes back around to its start, like a long navigation title.
struct MarqueeText: View {
    let content: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    @State private var width: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var travelled: CGFloat = 0

    private static let gap: CGFloat = 16
    private static let fadeWidth: CGFloat = 15
    /// In points a second.
    private static let speed: CGFloat = 30
    private static let delay: Duration = .seconds(1)

    init(_ content: String) {
        self.content = content
    }

    /// From the text's start to where it comes around again, or zero when
    /// the text fits.
    private var distance: CGFloat {
        // Not for an overflow that's only rounding.
        textWidth > width + 0.5 ? textWidth + Self.gap : 0
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
                .modifier(MarqueeScroll(travelled: travelled, distance: distance, fadeWidth: Self.fadeWidth))
            }
            .task(id: reduceMotion || isLuminanceReduced ? 0 : distance) {
                travelled = 0
                guard distance > 0, !reduceMotion, !isLuminanceReduced else { return }
                try? await Task.sleep(for: Self.delay)
                guard !Task.isCancelled else { return }
                let duration = distance / Self.speed
                withAnimation(.linear(duration: duration)) {
                    travelled = distance
                }
                try? await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled else { return }
                // The second copy now sits where the first began.
                travelled = 0
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(content))
    }
}

/// The line moved `travelled` points toward its leading edge. While it
/// overflows, its trailing edge fades, and so does its leading edge once the
/// text has moved off it.
private struct MarqueeScroll: ViewModifier, Animatable {
    var travelled: CGFloat
    let distance: CGFloat
    let fadeWidth: CGFloat

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
            .frame(minWidth: 0, maxWidth: .infinity, alignment: overflows ? .leading : .center)
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
