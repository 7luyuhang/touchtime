//
//  EarthImageView.swift
//  touchtime
//
//  Created by yuhang on 05/10/2025.
//

import SwiftUI

struct EarthImageView: View {
    let imageWidth: CGFloat = 128
    let circleSize: CGFloat = 64
    let period: TimeInterval = 15
    
    var body: some View {
        ZStack {
            Circle()
                .foregroundStyle(.tertiary)
            
            // Offset is derived from the wall clock, so the rotation is stateless:
            // it survives List cell recycling and backgrounding without any
            // onAppear/scenePhase re-arming, and always resumes at the right phase.
            // The WorldMap is tiled 3x at imageWidth, so -imageWidth and 0 render
            // identically, making the loop seamless.
            TimelineView(.animation) { context in
                let progress = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: period) / period
                
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        Image("WorldMap")
                            .resizable()
                            .scaledToFill()
                            .frame(width: imageWidth)
                            .colorMultiply(Color(.systemBackground))
                    }
                }
                .offset(x: -imageWidth + imageWidth * progress)
                .drawingGroup()
            }
            .frame(width: circleSize, height: circleSize)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(.tertiary, lineWidth: 0.5)
            )
        }
        .frame(width: 64, height: 64)
    }
}


#Preview {
    EarthImageView()
}
