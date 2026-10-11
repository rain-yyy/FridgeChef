//
//  RootView.swift
//  FridgeChef
//

import SwiftUI
import SwiftData

/// App root. Step 1 turns this into the fridge / cook / settings TabView.
struct RootView: View {
    var body: some View {
        Text(verbatim: "FridgeChef")
    }
}

#Preview {
    RootView()
        .modelContainer(for: FoodItem.self, inMemory: true)
}
