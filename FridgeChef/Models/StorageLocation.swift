import Foundation

enum StorageLocation: String, Codable, CaseIterable, Identifiable {
    case fridge
    case freezer

    var id: Self { self }

    var displayName: LocalizedStringResource {
        switch self {
        case .fridge: "storage.fridge"
        case .freezer: "storage.freezer"
        }
    }
}
