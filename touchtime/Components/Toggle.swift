//
//  TouchTimeToggle.swift
//  touchtime
//
//  Created on 03/04/2026.
//

import SwiftUI

struct TouchTimeToggle<Label: View>: View {
    private static var defaultTintColor: Color { .blue }

    private let isOn: Binding<Bool>
    private let tintColor: Color
    private let label: () -> Label

    init(
        isOn: Binding<Bool>,
        tintColor: Color = Self.defaultTintColor,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.isOn = isOn
        self.tintColor = tintColor
        self.label = label
    }

    var body: some View {
        Toggle(isOn: isOn) {
            label()
        }
        .tint(tintColor)
    }
}
