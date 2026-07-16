//
//  TouchTimeWidgetBundle.swift
//  touchtimeWidgetExtension
//

import WidgetKit
import SwiftUI

@main
struct TouchTimeWidgetBundle: WidgetBundle {
    var body: some Widget {
        CityComplicationWidget()
        WorldCitiesWidget()
    }
}
