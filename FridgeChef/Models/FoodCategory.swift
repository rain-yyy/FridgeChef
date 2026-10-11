import Foundation

enum FoodCategory: String, Codable, CaseIterable, Identifiable {
    case meat
    case semiPrepared
    case vegetable
    case eggDairy

    var id: Self { self }

    var displayName: LocalizedStringResource {
        switch self {
        case .meat: "category.meat"
        case .semiPrepared: "category.semiPrepared"
        case .vegetable: "category.vegetable"
        case .eggDairy: "category.eggDairy"
        }
    }
}
