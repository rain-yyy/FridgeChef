import SwiftUI

extension FoodItem {
    /// "2 颗" / "0.5 box".
    var quantityText: String {
        unit.amountText(quantity)
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(category: item.category)
            if dynamicTypeSize.isAccessibilitySize {
                // Very large text: stack the tag under the name instead of squeezing both into one row.
                VStack(alignment: .leading, spacing: 6) {
                    labels
                    ExpiryTag(status: item.expiryStatus)
                }
                Spacer(minLength: 0)
            } else {
                labels.lineLimit(1)
                Spacer(minLength: 8)
                ExpiryTag(status: item.expiryStatus)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .cardStyle(padding: 12)
        .contentShape(RoundedRectangle(cornerRadius: Metrics.cardRadius))
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(item.name)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.ink)
            Text(item.detailText)
                .font(.subheadline)
                .foregroundStyle(Color.cocoa)
        }
    }
}
