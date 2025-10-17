//
//  AppImage.swift
//  touchtime
//
//  Created on 27/09/2025.
//

import SwiftUI

struct SystemIconImage: View {
    let systemName: String
    let topColor: Color
    let bottomColor: Color
    
    var body: some View {
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
                .foregroundStyle(.white)
        }
    }
}
