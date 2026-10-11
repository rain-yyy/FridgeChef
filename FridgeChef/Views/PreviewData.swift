import Foundation
import SwiftData

#if DEBUG
/// Sample inventory (matching the design mockups) for previews and the `-useSampleData` launch argument.
enum PreviewData {
    static func container(empty: Bool = false) -> ModelContainer {
        let container = try! ModelContainer(
            for: FoodItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        if !empty {
            for item in sampleItems() { container.mainContext.insert(item) }
        }
        return container
    }

    static func sampleItems(now: Date = .now) -> [FoodItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today)! }

        // (name, category, storage, unit, quantity, days left (nil = frozen), added days ago)
        let rows: [(String, FoodCategory, StorageLocation, QuantityUnit, Double, Int?, Int)] = [
            ("牛奶", .eggDairy, .fridge, .box, 1, -1, 8),
            ("西红柿", .vegetable, .fridge, .head, 2, 1, 4),
            ("鸡胸肉", .meat, .fridge, .piece, 1, 2, 1),
            ("豆腐", .semiPrepared, .fridge, .box, 1, 3, 2),
            ("胡萝卜", .vegetable, .fridge, .item, 2, 3, 2),
            ("菠菜", .vegetable, .fridge, .bunch, 1, 4, 1),
            ("鸡蛋", .eggDairy, .fridge, .item, 6, 5, 2),
            ("五花肉", .meat, .freezer, .piece, 1, nil, 10),
            ("速冻饺子", .semiPrepared, .freezer, .bag, 1, nil, 14),
        ]
        return rows.map { name, category, storage, unit, quantity, daysLeft, addedAgo in
            FoodItem(
                name: name, category: category, storage: storage, unit: unit, quantity: quantity,
                addedDate: day(-addedAgo), expiryDate: daysLeft.map(day))
        }
    }
}
#endif
