//
//  AppIconEmblem.swift
//  touchtime
//
//  Created on 25/10/2026.
//

import SwiftUI

/// Liquid Glass plate in the app icon's shape: the rounded square (same
/// 100 pt / 26 pt-corner metrics as the app icon in `AboutView`) with the
/// icon's circle subtracted from it (~77% of the side: the 0.8125 circle
/// layer at 0.95 scale in `TouchTimeApp.icon`), so the background shows
/// through the cut-out.
struct AppIconEmblem: View {
    /// The plate's shape, for effects that follow its outline, like the
    /// store's chromatic entrance.
    static var plate: some Shape {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .subtracting(Circle().scale(0.8125 * 0.95))
    }

    var body: some View {
        Self.plate
            .fill(Color.white.opacity(0.05))
            .glassEffect(.clear, in: Self.plate)
            .frame(width: 100, height: 100)
    }
}
