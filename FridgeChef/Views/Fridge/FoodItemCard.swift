import SwiftUI

extension FoodItem {
    /// "2 颗" / "0.5 box".
    var quantityText: String {
        "\(quantity.formatted()) \(String(localized: unit.displayName))"
    }

    /// "冷藏 · 2 颗" for fridge items, just the quantity for frozen ones (the tag already says frozen).
    var detailText: String {
        storage == .fridge
            ? "\(String(localized: storage.displayName)) · \(quantityText)"
            : quantityText
    }
}

/// One item on the fridge page: category badge, name + detail, expiry tag.
struct FoodItemCard: View {
    let item: FoodItem

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(category: item.category)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.ink)
                Text(item.detailText)
                    .font(.subheadline)
                    .foregroundStyle(Color.cocoa)
            }
            .lineLimit(1)
            Spacer(minLength: 8)
            ExpiryTag(status: item.expiryStatus)
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .cardStyle(padding: 12)
        .contentShape(RoundedRectangle(cornerRadius: Metrics.cardRadius))
    }
}
