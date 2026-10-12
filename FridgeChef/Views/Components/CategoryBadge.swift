import SwiftUI


// 食材类别拓展，加入颜色和图标
extension FoodCategory {
    var tint: Color {
        switch self {
        case .meat: .catMeat
        case .semiPrepared: .catSemi
        case .vegetable: .catVeg
        case .eggDairy: .catDairy
        }
    }

    var icon: ImageResource {
        switch self {
        case .meat: .iconMeat
        case .semiPrepared: .iconReady
        case .vegetable: .iconVeggie
        case .eggDairy: .iconDairy
        }
    }
}

/// Pastel circle with the category's hand-drawn icon.
struct CategoryBadge: View {
    let category: FoodCategory
    var size: CGFloat = 40

    var body: some View {
        Image(category.icon)
            .resizable()
            .frame(width: size * 0.55, height: size * 0.55)
            .foregroundStyle(Color.onPastel)
            .frame(width: size, height: size)
            .background(category.tint, in: Circle())
            .overlay(Circle().strokeBorder(Color.ink, lineWidth: 1.5))
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    HStack {
        ForEach(FoodCategory.allCases) { CategoryBadge(category: $0) }
    }
    .padding()
    .background(Color.cream)
}
#endif
