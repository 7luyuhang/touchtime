//
//  CountdownCoverEmojis.swift
//  touchtime
//
//  The pool random countdown covers come from. Every countdown has a
//  cover, so a countdown without one draws its default from here: new
//  ones in the editor, and ones saved before covers were mandatory when
//  the store loads them. The cover picker's shuffle button picks from
//  here too.
//

import Foundation

enum CountdownCoverEmojis {
    /// Common event emojis.
    static let randomPool: [String] = [
        "🎂", "🎉", "🎈", "🎁", "🍰", "🥂", "🎊", "🪩",
        "🥳", "🍾", "🧁", "🍻", "🪅", "🎟️", "🎪", "🎇",
        "❤️", "💍", "💒", "👶", "🌹", "💌", "💘", "🫶",
        "🎓", "📚", "✏️", "💼", "🏆", "🥇", "🎯", "🧳",
        "✈️", "🏝️", "🗺️", "🚗", "⛺️", "🎡", "🛳️", "🚀",
        "🛫", "🚄", "🏖️", "🏔️", "🗽", "🗼", "⛩️", "🏰",
        "🎄", "🎃", "🧧", "🏮", "🐰", "🦃", "🌕", "🎆",
        "🪔", "🕎", "☘️", "🎍", "🌅", "🕯️", "🎗️", "🛍️",
        "☀️", "🌸", "🍂", "❄️", "⭐️", "🌈", "🔥", "💧",
        "⚽️", "🏀", "🎾", "🏃", "🧘", "🎮", "🎵", "🎬",
        "🏊", "🚴", "⛷️", "🏂", "⛳️", "🏓", "🥊", "🛹",
        "🎤", "🎸", "🎹", "🎻", "🎭", "🎨", "🎧", "🎫",
        "🍽️", "☕️", "🍕", "🍜", "🍣", "🍦", "🍷", "🧋",
        "📦", "🤝", "📝", "💻", "🩺", "🐶", "🐱", "🧸",
        "🏠", "🔑", "💰", "💎", "📅", "⏰", "🔔", "📌",
        "⏳", "🚩", "📷", "🗳️", "💵", "🪴", "🌙", "🌊"
    ]

    /// A random cover for a countdown that has none.
    static var random: String {
        randomPool.randomElement() ?? "🎉"
    }
}
