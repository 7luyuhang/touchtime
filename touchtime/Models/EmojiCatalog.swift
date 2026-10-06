//
//  EmojiCatalog.swift
//  touchtime
//
//  Every emoji, grouped and ordered like the emoji keyboard, for the cover
//  picker. The lists come from Unicode's emoji-test.txt, generated into
//  EmojiCatalog+Data.swift by scripts/generate_emoji_catalog.py; emojis
//  newer than the ones iOS 26.0 draws show up once the running system
//  draws them.
//

import CoreText
import UIKit

enum EmojiCatalog {
    /// The emoji keyboard's categories, in its order.
    enum Category: CaseIterable {
        case smileysAndPeople
        case animalsAndNature
        case foodAndDrink
        case activity
        case travelAndPlaces
        case objects
        case symbols
        case flags

        var title: String {
            switch self {
            case .smileysAndPeople: String(localized: "Smileys & People")
            case .animalsAndNature: String(localized: "Animals & Nature")
            case .foodAndDrink: String(localized: "Food & Drink")
            case .activity: String(localized: "Activity")
            case .travelAndPlaces: String(localized: "Travel & Places")
            case .objects: String(localized: "Objects")
            case .symbols: String(localized: "Symbols")
            case .flags: String(localized: "Flags")
            }
        }

        /// The category's emojis the running system draws, in keyboard
        /// order and their default skin tone.
        var emojis: [String] {
            EmojiCatalog.drawableEmojis[self] ?? []
        }
    }

    /// An emoji's skin tones for its long-press menu, in rows: all of them
    /// in one row for a single person; for two, a row per tone of the first
    /// person holding every tone of the second, starting with both people
    /// in the row's tone. Empty for emojis without skin tones.
    static func skinToneRows(of emoji: String) -> [[String]] {
        drawableSkinToneRows[emoji] ?? []
    }

    private static let drawableEmojis: [Category: [String]] = Dictionary(
        uniqueKeysWithValues: Category.allCases.map { category in
            (category, category.allEmojis.filter { systemDraws($0) })
        }
    )

    private static let drawableSkinToneRows: [String: [[String]]] = skinToneVariants
        .mapValues { variants in variants.filter { systemDraws($0) } }
        .filter { !$0.value.isEmpty }
        .mapValues { variants in rows(of: variants) }

    private static let skinTones: ClosedRange<Unicode.Scalar> = "\u{1F3FB}"..."\u{1F3FF}"

    /// Lays sorted skin tone variants out in rows: one row for a single
    /// person; for two people, a new row wherever the first person's tone
    /// changes.
    private static func rows(of variants: [String]) -> [[String]] {
        let isTwoPeople = variants.contains { variant in
            variant.unicodeScalars.filter { skinTones.contains($0) }.count > 1
        }
        guard isTwoPeople else { return [variants] }

        var rows: [[String]] = []
        var rowTone: Unicode.Scalar?
        for variant in variants {
            let tone = variant.unicodeScalars.first { skinTones.contains($0) }
            if tone == rowTone, !rows.isEmpty {
                rows[rows.count - 1].append(variant)
            } else {
                rows.append([variant])
                rowTone = tone
            }
        }
        return rows
    }

    /// Whether the running system draws the emoji. Everything up to Emoji
    /// 16.0 ships with iOS 26.0; a newer one has to come out of the emoji
    /// font as a single emoji-wide image. One the font doesn't know falls
    /// back to another font's placeholder, or apart into several images.
    private static func systemDraws(_ emoji: String) -> Bool {
        guard recentEmojis.contains(emoji) else { return true }
        let line = emojiLine(emoji)
        let runs = CTLineGetGlyphRuns(line) as? [CTRun] ?? []
        let isAllEmojiFont = runs.allSatisfy { run in
            let attributes = CTRunGetAttributes(run) as? [NSAttributedString.Key: Any]
            return (attributes?[.font] as? UIFont)?.fontName == emojiFont.fontName
        }
        return isAllEmojiFont && width(of: line) < width(of: emojiLine("😀")) * 1.5
    }

    private static let emojiFont = UIFont(name: "AppleColorEmoji", size: 20) ?? .systemFont(ofSize: 20)

    private static func emojiLine(_ string: String) -> CTLine {
        CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: [.font: emojiFont]))
    }

    private static func width(of line: CTLine) -> Double {
        CTLineGetTypographicBounds(line, nil, nil, nil)
    }
}
