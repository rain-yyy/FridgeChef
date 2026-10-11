//
//  ContentView.swift
//  FridgeChef
//
//  Created by Rainyyy-day on 10/10/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var items: [FoodItem]

    var body: some View {
        List(items) { item in
            HStack {
                Text(item.name)
                Spacer()
                Text("\(item.quantity.formatted()) \(String(localized: item.unit.displayName))")
                    .foregroundStyle(.secondary)
                Text(daysLeftText(item.daysLeft))
                    .monospacedDigit()
                    .frame(minWidth: 60, alignment: .trailing)
            }
        }
    }

    private func daysLeftText(_ days: Int?) -> String {
        guard let days else { return "—" }
        return "\(days)d"
    }
}

#Preview {
    let container = try! ModelContainer(
        for: FoodItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let samples: [(String, FoodCategory, StorageLocation, QuantityUnit, Double)] = [
        ("牛肉", .meat, .freezer, .piece, 2),
        ("西红柿", .vegetable, .fridge, .item, 3),
        ("鸡蛋", .eggDairy, .fridge, .box, 0.5),
        ("菠菜", .vegetable, .fridge, .bunch, 1),
    ]
    for (name, category, storage, unit, quantity) in samples {
        container.mainContext.insert(FoodItem(
            name: name, category: category, storage: storage, unit: unit, quantity: quantity,
            expiryDate: ShelfLifePreset.expiryDate(
                name: name, category: category, storage: storage, addedDate: .now)
        ))
    }
    return ContentView().modelContainer(container)
}
