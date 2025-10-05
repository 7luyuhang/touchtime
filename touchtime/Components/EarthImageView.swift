//
//  EarthImageView.swift
//  touchtime
//
//  Created by yuhang on 05/10/2025.
//

import SwiftUI

struct EarthImageView: View {
    @State private var scrollOffset: CGFloat = -128
    
    let imageWidth: CGFloat = 128
    let circleSize: CGFloat = 64
    
    var body: some View {
        ZStack {
            Circle()
                .foregroundStyle(.tertiary)
            
            ZStack {
                HStack(spacing: 0) {
                    Image("WorldMap")
                        .resizable()
                        .scaledToFill()
                        .frame(width: imageWidth)
                        .colorMultiply(Color(.systemBackground))
                    
                    Image("WorldMap")
                        .resizable()
                        .scaledToFill()
                        .frame(width: imageWidth)
                        .colorMultiply(Color(.systemBackground))
                    
                    Image("WorldMap")
                        .resizable()
                        .scaledToFill()
                        .frame(width: imageWidth)
                        .colorMultiply(Color(.systemBackground))
                }
                .offset(x: scrollOffset)
            }
            .frame(width: circleSize, height: circleSize)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(.tertiary, lineWidth: 0.5)
            )
            
            
        }
        .frame(width: 64, height: 64)
        .onAppear {
            withAnimation(
                Animation.linear(duration: 15)
                    .repeatForever(autoreverses: false)
            ) {
                scrollOffset = 0
            }
        }
    }
}


#Preview {
    EarthImageView()
}
