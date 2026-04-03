//
//  AppImage.swift
//  touchtime
//
//  Created on 27/09/2025.
//

import SwiftUI

struct SystemIconImage: View {
    enum Style {
        case gradientSquare
        case plain
    }

    let systemName: String
    let topColor: Color
    let bottomColor: Color
    let foregroundColor: Color
    let style: Style

    init(
        systemName: String,
        topColor: Color,
        bottomColor: Color,
        foregroundColor: Color = .white,
        style: Style = .gradientSquare
    ) {
        self.systemName = systemName
        self.topColor = topColor
        self.bottomColor = bottomColor
        self.foregroundColor = foregroundColor
        self.style = style
    }
    
    var body: some View {
        switch style {
        case .gradientSquare:
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                topColor,
                                bottomColor
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 28, height: 28)
                    .glassEffect(.regular, in:
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                Image(systemName: systemName)
                    .font(.system(size: 15))
                    .fontWeight(.medium)
                    .foregroundStyle(foregroundColor)
            }
            // Icon Plain Mode
        case .plain:
            Image(systemName: systemName)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 22))
                .fontWeight(.semibold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            topColor,
                            bottomColor
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .shadow(.inner(color: .white.opacity(0.50), radius: 0.5, x: 0, y: 0.25))
                )
                .frame(width: 28, height: 28)
        }
    }
}
