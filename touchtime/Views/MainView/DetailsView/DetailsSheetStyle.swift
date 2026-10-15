//
//  DetailsSheetStyle.swift
//  touchtime
//
//  Created on 15/10/2026.
//

import SwiftUI

extension View {
    func detailsSheetCardChrome(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(.white.opacity(0.05))
            .blendMode(.plusLighter)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    func detailsSheetCard(innerPadding: CGFloat = 16, cornerRadius: CGFloat = 20) -> some View {
        self
            .padding(innerPadding)
            .detailsSheetCardChrome(cornerRadius: cornerRadius)
    }

    func detailsSheetCardRow(horizontalPadding: CGFloat = 16, innerPadding: CGFloat = 16, cornerRadius: CGFloat = 20) -> some View {
        self
            .detailsSheetCard(innerPadding: innerPadding, cornerRadius: cornerRadius)
            .padding(.horizontal, horizontalPadding)
    }
}
