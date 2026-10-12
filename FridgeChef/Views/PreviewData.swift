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

    /// A menu like the design mockups, built from `items` (as returned by `sampleItems`).
    static func sampleMenu(items: [FoodItem]) -> MenuResult {
        func use(_ name: String, _ amount: Double) -> DishIngredient {
            let item = items.first { $0.name == name }!
            return DishIngredient(
                itemID: item.id, name: name, unit: item.unit, amount: amount, wasSoon: item.expiryStatus.isSoon)
        }
        let plans = [
            MenuPlan(minutes: 25, dishes: [
                Dish(name: "鸡胸肉炒胡萝卜", ingredients: [use("鸡胸肉", 1), use("胡萝卜", 1)],
                     extras: ["油", "盐", "生抽", "蒜", "淀粉"],
                     steps: ["鸡胸肉切薄片，加生抽和一小勺淀粉抓匀，腌 10 分钟。", "胡萝卜切片，蒜切末。",
                             "热锅下油，鸡肉炒到变白就盛出。", "用底油炒软胡萝卜，倒回鸡肉，加盐翻匀出锅。"]),
                Dish(name: "番茄蛋花汤", ingredients: [use("西红柿", 1), use("鸡蛋", 1)],
                     extras: ["油", "盐", "葱花", "香油"],
                     steps: ["西红柿切块，鸡蛋打散。", "少许油把西红柿炒出汁，加两碗水煮开。",
                             "转小火，慢慢淋入蛋液，等蛋花浮起。", "加盐、葱花，滴几滴香油即可。"]),
            ]),
            MenuPlan(minutes: 15, dishes: [
                Dish(name: "番茄炒蛋", ingredients: [use("西红柿", 1), use("鸡蛋", 3)],
                     extras: ["油", "盐", "糖"], steps: ["西红柿切块，鸡蛋打散。", "先炒蛋盛出，再炒西红柿出汁。", "倒回鸡蛋，加盐和少许糖翻匀。"]),
                Dish(name: "清炒菠菜", ingredients: [use("菠菜", 1)],
                     extras: ["油", "盐", "蒜"], steps: ["菠菜洗净切段。", "蒜末爆香，下菠菜大火快炒。", "加盐出锅。"]),
            ]),
            MenuPlan(minutes: 30, note: "五花肉在冷冻，记得提前解冻", dishes: [
                Dish(name: "家常豆腐", ingredients: [use("豆腐", 1), use("五花肉", 0.5)],
                     extras: ["油", "生抽", "豆瓣酱"], steps: ["豆腐切块煎到两面金黄。", "五花肉切片炒出油。", "加豆瓣酱、生抽和豆腐烧 5 分钟。"]),
                Dish(name: "蒜蓉菠菜", ingredients: [use("菠菜", 1)],
                     extras: ["油", "盐", "蒜"], steps: ["菠菜焯水 30 秒。", "蒜蓉炒香，淋在菠菜上，加盐拌匀。"]),
            ]),
        ]
        return MenuResult(cuisine: .chinese, servings: 2, createdAt: .now, plans: plans)
    }

    /// An in-memory menu store holding `sampleMenu` for the items in `container`.
    static func menuStore(for container: ModelContainer) -> MenuStore {
        let items = (try? container.mainContext.fetch(FetchDescriptor<FoodItem>())) ?? []
        return MenuStore(fileURL: nil, result: items.isEmpty ? nil : sampleMenu(items: items))
    }
}
#endif
