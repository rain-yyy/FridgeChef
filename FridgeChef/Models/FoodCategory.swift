import Foundation

enum FoodCategory: String, Codable, CaseIterable {
    case meat
    case semiPrepared
    case vegetable
    case eggDairy

    var displayName: LocalizedStringResource {
        switch self {
        case .meat: "Meat"
        case .semiPrepared: "Semi-prepared"
        case .vegetable: "Vegetable"
        case .eggDairy: "Eggs & Dairy"
        }
    }
}
