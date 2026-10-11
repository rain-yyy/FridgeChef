import Foundation

struct ShelfLifePreset {
    /// Days in the fridge, looked up by lowercased ingredient name.
    private static let byName: [String: Int] = [
        "西红柿": 7, "tomato": 7,
        "菠菜": 3, "spinach": 3,
        "鸡蛋": 21, "egg": 21,
        "牛奶": 7, "milk": 7,
    ]

    private static func defaultDays(category: FoodCategory, storage: StorageLocation) -> Int {
        switch category {
        case .vegetable: 5
        case .meat: 2
        case .semiPrepared: 3
        case .eggDairy: 7
        }
    }

    /// Returns the expiry date, or nil for frozen food.
    static func expiryDate(
        name: String,
        category: FoodCategory,
        storage: StorageLocation,
        addedDate: Date
    ) -> Date? {
        guard storage == .fridge else { return nil }
        let key = name.trimmingCharacters(in: .whitespaces).lowercased()
        let days = byName[key] ?? defaultDays(category: category, storage: storage)
        return Calendar.current.date(byAdding: .day, value: days, to: addedDate)
    }
}
