//
//  CountdownCoverEmojis.swift
//  touchtime
//
//  The emojis offered as countdown covers. Every countdown has a cover, so
//  this is also the pool a countdown without one draws its default from:
//  new ones in the editor, and ones saved before covers were mandatory
//  when the store loads them.
//

import Foundation

enum CountdownCoverEmojis {
    /// The cover picker's grid, in display order.
    static let all: [String] = [
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
        all.randomElement() ?? "🎉"
    }
}
