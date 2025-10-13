//
//  SkyDotView.swift
//  touchtime
//
//  Created on 25/09/2025.
//

import SwiftUI

struct SkyDotView: View {
    let date: Date
    let timeZoneIdentifier: String
    
    // Create sky color gradient instance
    private var skyColorGradient: SkyColorGradient {
        SkyColorGradient(date: date, timeZoneIdentifier: timeZoneIdentifier)
    }
    
    var body: some View {
        Capsule(style: .continuous)
            .fill(skyColorGradient.linearGradient())
            .frame(width: 24, height: 16)
            .glassEffect(.regular)
            .animation(.spring(), value: skyColorGradient.animationValue)
    }
}
