import Foundation

/// Storage filter on the fridge page.
enum StorageFilter: CaseIterable, Identifiable {
    case all, fridge, freezer

    var id: Self { self }

    var label: LocalizedStringResource {
        switch self {
        case .all: "filter.all"
        case .fridge: StorageLocation.fridge.displayName
        case .freezer: StorageLocation.freezer.displayName
        }
    }

    func includes(_ storage: StorageLocation) -> Bool {
        switch self {
        case .all: true
        case .fridge: storage == .fridge
        case .freezer: storage == .freezer
        }
    }
}

/// One group on the fridge page: "use soon" first, then one per category.
struct FridgeSection: Identifiable {
    enum Kind: Hashable {
        case urgent
        case category(FoodCategory)
    }

    let kind: Kind
    let items: [FoodItem]

    var id: Kind { kind }

    var title: LocalizedStringResource {
        switch kind {
        case .urgent: "fridge.section.urgent"
        case .category(let category): category.displayName
        }
    }
}

enum FridgeSections {
    /// Filters by storage and name, then groups: fridge items expiring within 2 days (or expired)
    /// go to "use soon"; the rest go to their category. Each group is sorted by days left, frozen last.
    static func build(_ items: [FoodItem], filter: StorageFilter, query: String) -> [FridgeSection] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let visible = items.filter {
            filter.includes($0.storage) && (query.isEmpty || $0.name.localizedStandardContains(query))
        }

        var sections: [FridgeSection] = []
        let urgent = visible.filter { $0.expiryStatus.isUrgent }.sorted { inDisplayOrder($0, $1) }
        if !urgent.isEmpty {
            sections.append(FridgeSection(kind: .urgent, items: urgent))
        }
        for category in FoodCategory.allCases {
            let group = visible
                .filter { $0.category == category && !$0.expiryStatus.isUrgent }
                .sorted { inDisplayOrder($0, $1) }
            if !group.isEmpty {
                sections.append(FridgeSection(kind: .category(category), items: group))
            }
        }
        return sections
    }

    static func inDisplayOrder(_ a: FoodItem, _ b: FoodItem) -> Bool {
        let keyA = sortKey(a), keyB = sortKey(b)
        if keyA != keyB { return keyA < keyB }
        return a.name.localizedStandardCompare(b.name) == .orderedAscending
    }

    /// Days left for fridge items; frozen (or undated) items sort last.
    private static func sortKey(_ item: FoodItem) -> Int {
        item.storage == .fridge ? (item.daysLeft ?? .max) : .max
    }
}
