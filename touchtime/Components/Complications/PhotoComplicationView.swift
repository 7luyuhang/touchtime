//
//  PhotoComplicationView.swift
//  touchtime
//
//  Created on 24/03/2026.
//

import SwiftUI
import UIKit

struct PhotoComplicationView: View {
    let size: CGFloat
    let useMaterialBackground: Bool

    @AppStorage private var photoComplicationImageData: Data?

    init(size: CGFloat = 100, useMaterialBackground: Bool = false, photoStorageKey: String = "default") {
        self.size = size
        self.useMaterialBackground = useMaterialBackground
        self._photoComplicationImageData = AppStorage(Self.userDefaultsKey(for: photoStorageKey), store: .standard)
    }

    static func userDefaultsKey(for photoStorageKey: String) -> String {
        "photoComplicationImageData.\(photoStorageKey)"
    }

    private var image: UIImage? {
        guard let photoComplicationImageData, !photoComplicationImageData.isEmpty else { return nil }
        return UIImage(data: photoComplicationImageData)
    }

    var body: some View {
        ZStack {
            if useMaterialBackground {
                Circle()
                    .fill(.black.opacity(0.05))
                    .blendMode(.plusDarker)
            } else {
                Circle()
                    .fill(.clear)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.10))
                            .glassEffect(.clear)
                    )
            }

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .glassEffect(.clear, in: Circle())
            } else {
                Path { path in
                    let center = size / 2
                    let halfLength = size * 0.175
                    // Vertical line
                    path.move(to: CGPoint(x: center, y: center - halfLength))
                    path.addLine(to: CGPoint(x: center, y: center + halfLength))
                    // Horizontal line
                    path.move(to: CGPoint(x: center - halfLength, y: center))
                    path.addLine(to: CGPoint(x: center + halfLength, y: center))
                }
                .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .blendMode(.plusLighter)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        PhotoComplicationView(size: 64)
    }
}
