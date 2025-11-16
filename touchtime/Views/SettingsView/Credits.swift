//
//  CreditsView.swift
//  touchtime
//
//  Created on 20/10/2025.
//

import SwiftUI

struct CreditsView: View {
    var body: some View {
        List {
            Section {
                Link(destination: URL(string: "https://github.com/SunKit-Swift/SunKit")!) {
                   Text("SunKit")
                        .tint(.primary)
                }
                
                Link(destination: URL(string: "https://github.com/davideilmito/MoonKit")!) {
                   Text("MoonKit")
                        .tint(.primary)
                }
                
                Link(destination: URL(string: "https://github.com/markiv/SwiftUI-Shimmer")!) {
                   Text("SwiftUI-Shimmer")
                        .tint(.primary)
                }
                
                Link(destination: URL(string: "https://developer.apple.com/documentation/weatherkit/")!) {
                   Text("WeatherKit")
                        .tint(.primary)
                }
            } header: {
                Text("Open Source Library", comment: "Credits section header")
            } footer: {
                Text("Thanks for these kind human beings.", comment: "Credits section footer")
            }
        }
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }
}
