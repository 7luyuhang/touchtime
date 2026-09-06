//
//  StarParticle.swift
//  touchtime
//
//  Single star dot for night skies. Lives in Shared/ so both the app
//  (sky backgrounds, Daylight sheet timeline) and the widget's Daylight
//  ring render identical stars.
//

import SwiftUI

struct StarParticle: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(
                // Add slight color variation for more realistic stars
                size > 1.5 ?
                Color(white: 1.0) :  // Bright stars are pure white
                Color(white: 0.95, opacity: 1.0)  // Smaller stars slightly dimmer
            )
            .frame(width: size, height: size)
            .blur(radius: size > 1.5 ? 0.3 : 0)
            .shadow(color: Color(white: 0.9).opacity(0.9), radius: size > 1.2 ? 3 : 1)
    }
}
