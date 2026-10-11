import Foundation

struct ShelfLifePreset {
    /// Where a fridge shelf life comes from; the item editor explains it to the user.
    enum Source: Equatable {
        case name(days: Int)
        case category(days: Int)

        var days: Int {
            switch self {
            case .name(let days), .category(let days): days
            }
        }
    }

    /// Days in the fridge, looked up by lowercased ingredient name.
    private static let byName: [String: Int] = [
        "西红柿": 7, "tomato": 7,
        "菠菜": 3, "spinach": 3,
        "鸡蛋": 21, "egg": 21,
        "牛奶": 7, "milk": 7,
    ]

    static func defaultDays(category: FoodCategory) -> Int {
        switch category {
        case .meat: 3
        case .semiPrepared: 5
        case .vegetable: 5
        case .eggDairy: 7
        }
    }

    /// Fridge shelf life: a name preset if one matches, otherwise the category default.
    static func source(name: String, category: FoodCategory) -> Source {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let days = byName[key] { return .name(days: days) }
        return .category(days: defaultDays(category: category))
    }

    /// Returns the expiry date counted from `startDate`, or nil for frozen food.
    static func expiryDate(
        name: String,
        category: FoodCategory,
        storage: StorageLocation,
        startDate: Date
    ) -> Date? {
        guard storage == .fridge else { return nil }
        let days = source(name: name, category: category).days
        return Calendar.current.date(byAdding: .day, value: days, to: startDate)
    }
}
