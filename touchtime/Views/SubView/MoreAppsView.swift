//
//  MoreAppsView.swift
//  touchtime
//
//  Created on 11/07/2026.
//

import SwiftUI

struct MoreAppsView: View {
    var body: some View {
        List {
        }
        .scrollIndicators(.hidden)
        .navigationTitle("More Apps")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        MoreAppsView()
    }
}
