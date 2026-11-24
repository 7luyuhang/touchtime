//
//  TouchTimeWatchWidgetBundle.swift
//  touchtimeWatchWidgetExtension
//

import SwiftUI
import WidgetKit

@main
struct TouchTimeWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        CityCardWidget()
        CountdownCardWidget()
    }
}
