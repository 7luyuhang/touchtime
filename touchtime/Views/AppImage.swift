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
        Image(systemName: systemName)
            .font(.system(size: 16))
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(
                LinearGradient(
                    colors: [
                        topColor,
                        bottomColor
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
