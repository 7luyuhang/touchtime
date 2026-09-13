//
//  ColorEmojiText.swift
//  touchtimeWidgetExtension
//
//  A drop-in for a single-line `Text` that keeps emoji legible in the Clear
//  and Tinted Home Screen modes. There WidgetKit flattens text into a solid
//  silhouette, so a city named "🗼 Paris" shows a white blob; this view
//  hands the emoji over as images instead, which the system desaturates
//  with the rest of the widget but keeps shaded, and leaves the rest as
//  text. Font, line limit and truncation come from the environment exactly
//  as they would for `Text`; in full-colour mode it *is* a `Text`.
//

import SwiftUI
import WidgetKit
import CoreText

struct ColorEmojiText: View {
    let text: String

    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.font) private var font
    @Environment(\.fontResolutionContext) private var fontContext
    @Environment(\.displayScale) private var displayScale

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        let segments = Self.segments(of: text)
        if renderingMode == .accented, segments.contains(where: \.isEmoji) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                ForEach(segments) { segment in
                    if segment.isEmoji, let glyph = rasterise(segment.text) {
                        Image(uiImage: glyph.image)
                            .widgetAccentedRenderingMode(.desaturated)
                            .frame(width: glyph.box.width, height: glyph.box.height)
                            .alignmentGuide(.firstTextBaseline) { $0[.top] + glyph.baseline }
                            .alignmentGuide(.lastTextBaseline) { $0[.top] + glyph.baseline }
                    } else {
                        Text(segment.text)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
        } else {
            Text(text)
        }
    }

    // MARK: - Segments

    private struct Segment: Identifiable {
        let id: Int
        var text: String
        let isEmoji: Bool
    }

    /// The string cut into alternating runs of emoji and everything else.
    private static func segments(of text: String) -> [Segment] {
        var segments: [Segment] = []
        for character in text {
            let isEmoji = character.isColorEmoji
            if let last = segments.indices.last, segments[last].isEmoji == isEmoji {
                segments[last].text.append(character)
            } else {
                segments.append(Segment(id: segments.count, text: String(character), isEmoji: isEmoji))
            }
        }
        return segments
    }

    // MARK: - Rasterising

    private struct Glyph {
        /// The run drawn with a margin around `box` on every side.
        let image: UIImage
        /// The run's line box: the room it takes up in layout, the same a
        /// `Text` of it would. The image is centred on it and pokes out.
        let box: CGSize
        /// Distance from the top of `box` to the text baseline, for lining
        /// the emoji up with the neighbouring `Text`.
        let baseline: CGFloat
    }

    /// The emoji run drawn with the very font the surrounding `Text`
    /// resolves to, at the screen's scale so it stays crisp.
    private func rasterise(_ run: String) -> Glyph? {
        let ctFont = (font ?? .body).resolve(in: fontContext).ctFont
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: run, attributes: [.font: ctFont])
        )
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
        let box = CGSize(width: ceil(width), height: ceil(ascent + descent))
        guard box.width > 0, box.height > 0 else { return nil }

        // Emoji ink pokes out of the font's line box by a point or so (the
        // top of a keycap, the frame around 🏙️), so the bitmap gets a margin
        // around the box and the ink overflows the layout frame, just as it
        // would in a `Text`.
        let margin = ceil(box.height / 4)
        let bitmap = CGSize(width: box.width + 2 * margin, height: box.height + 2 * margin)

        let format = UIGraphicsImageRendererFormat()
        format.scale = displayScale
        let image = UIGraphicsImageRenderer(size: bitmap, format: format).image { context in
            let cgContext = context.cgContext
            // Core Text draws with y pointing up; flip the UIKit context and
            // put the baseline `descent` above the bottom edge of the box.
            cgContext.textMatrix = .identity
            cgContext.translateBy(x: 0, y: bitmap.height)
            cgContext.scaleBy(x: 1, y: -1)
            cgContext.textPosition = CGPoint(x: margin, y: margin + descent)
            CTLineDraw(line, cgContext)
        }
        return Glyph(image: image, box: box, baseline: box.height - descent)
    }
}

private extension Character {
    /// Whether the system draws this character from the colour emoji font:
    /// default-emoji scalars (😀, 🗼, the regional indicators of 🇫🇷, skin
    /// tones, the parts of ZWJ sequences) or a text-style symbol switched to
    /// emoji style with U+FE0F (☀️, 🏙️, 1️⃣). Digits, #, *, © and ™ carry the
    /// Emoji property too but render as text, so they are left alone.
    var isColorEmoji: Bool {
        let scalars = unicodeScalars
        if scalars.contains(where: { $0.properties.isEmojiPresentation }) {
            return true
        }
        return scalars.contains { $0.value == 0xFE0F } && scalars.contains { $0.properties.isEmoji }
    }
}
