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
            } header: {
                Text("Open Source Library")
            } footer: {
                Text("Thanks for these kind human beings.")
            }
        }
        .navigationTitle("Credits")
        .navigationBarTitleDisplayMode(.inline)
    }
}
