import SwiftUI
import SwiftData

/// "推荐菜单": loading skeletons, an error page, or the generated plans.
struct ResultsView: View {
    @Binding var selectedTab: AppTab

    @Environment(MenuStore.self) private var menuStore
    @Environment(AISettings.self) private var settings
    @Query private var items: [FoodItem]

    var body: some View {
        Group {
            switch menuStore.phase {
            case .loading:
                MenuLoadingView(request: menuStore.request)
            case .failed(let error):
                MenuErrorView(error: error, onRetry: retry) { selectedTab = .settings }
            case .idle:
                if let result = menuStore.result {
                    plans(result)
                } else {
                    MenuErrorView(error: .badResponse, onRetry: retry) { selectedTab = .settings }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cream.ignoresSafeArea())
        .handwrittenInlineTitle("results.title")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: retry) {
                    Image(.iconRetry).resizable().frame(width: 22, height: 22)
                }
                .disabled(menuStore.phase == .loading || !settings.isConfigured)
                .accessibilityLabel(Text("results.regenerate"))
            }
        }
    }

    private func plans(_ result: MenuResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("results.summary \(String(localized: result.cuisine.displayName)) \(result.servings) \(result.plans.count)")
                        .font(.subheadline.weight(.semibold))
                    Text("results.summary.caption")
                        .font(.footnote)
                        .foregroundStyle(Color.cocoa)
                }
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 2)

                ForEach(Array(result.plans.enumerated()), id: \.element.id) { index, plan in
                    NavigationLink(value: CookRoute.plan(plan.id)) {
                        PlanCard(plan: plan, index: index)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
    }

    private func retry() {
        menuStore.retry(items: items, settings: settings)
    }
}

extension MenuPlan {
    /// "方案 A" / "Plan A".
    static func label(at index: Int) -> LocalizedStringResource {
        let letter = String(UnicodeScalar(UInt8(65 + min(index, 25))))
        return "results.plan \(letter)"
    }
}

/// One plan on the results page. The first (best) plan gets a honey label and a hard shadow.
private struct PlanCard: View {
    let plan: MenuPlan
    let index: Int

    var body: some View {
        let isTop = index == 0
        let soonCount = plan.soonItemCount
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(MenuPlan.label(at: index))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isTop ? Color.onPastel : Color.ink)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 24)
                    .background(isTop ? Color.honey : Color.paper, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.ink, lineWidth: 1.5))
                if let minutes = plan.minutes {
                    Text("results.minutes \(minutes)")
                        .font(.footnote)
                        .foregroundStyle(Color.cocoa)
                }
                Spacer()
                Image(.iconForward)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Color.cocoa)
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(plan.dishes) { dish in
                    Text(dish.name).font(.handwritten(21))
                }
            }

            FlowLayout {
                ForEach(plan.totalIngredients, id: \.itemID) { IngredientChip(ingredient: $0) }
            }

            DashedDivider()

            Group {
                if let note = plan.note {
                    Text(note)
                } else if soonCount > 0 {
                    Text("results.usesSoon \(soonCount)")
                } else {
                    Text("results.usesNoSoon")
                }
            }
            .font(.footnote.weight(plan.note != nil || soonCount > 0 ? .semibold : .regular))
            .foregroundStyle(plan.note != nil || soonCount > 0 ? Color.ink : Color.cocoa)
        }
        .foregroundStyle(Color.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 16)
        .background(
            RoundedRectangle(cornerRadius: Metrics.cardRadius)
                .fill(Color.ink)
                .offset(x: isTop ? Metrics.hardShadow : 0, y: isTop ? Metrics.hardShadow : 0)
        )
        .accessibilityElement(children: .combine)
    }
}

/// "西红柿 1 颗" chip; use-soon ingredients are apricot with a clock.
struct IngredientChip: View {
    let ingredient: DishIngredient

    var body: some View {
        let soon = ingredient.wasSoon
        HStack(spacing: 3) {
            if soon {
                Image(.iconSoon).resizable().frame(width: 14, height: 14)
            }
            Text(verbatim: "\(ingredient.name) \(ingredient.amountText)")
        }
        .font(.footnote.weight(soon ? .semibold : .regular))
        .foregroundStyle(soon ? Color.onPastel : Color.ink)
        .padding(.leading, soon ? 7 : 10)
        .padding(.trailing, 10)
        .frame(minHeight: 28)
        .background(soon ? Color.soon : Color.paper, in: Capsule())
        .overlay(Capsule().strokeBorder(soon ? Color.ink : Color.weakStroke, lineWidth: 1.5))
    }
}

/// Pot doodle, "thinking" text and three pulsing skeleton cards.
private struct MenuLoadingView: View {
    let request: MenuStore.Request?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 10) {
                    Image(.illusCooking)
                        .resizable()
                        .frame(width: 76, height: 76)
                        .accessibilityHidden(true)
                    Text("results.loading.title")
                        .font(.handwritten(22))
                        .foregroundStyle(Color.ink)
                    if let request {
                        Text("results.loading.caption \(String(localized: request.cuisine.displayName)) \(request.servings)")
                            .font(.subheadline)
                            .foregroundStyle(Color.cocoa)
                    }
                }
                .padding(.top, 18)
                .padding(.bottom, 10)
                .accessibilityElement(children: .combine)

                SkeletonCard(titleWidth: 0.58, chips: [72, 60, 80], footerWidth: 0.4, delay: 0)
                SkeletonCard(titleWidth: 0.66, chips: [64, 84], footerWidth: 0.34, delay: 0.2)
                SkeletonCard(titleWidth: 0.5, chips: [76, 58], footerWidth: nil, delay: 0.4)
            }
            .padding(.horizontal, 20)
        }
        .scrollDisabled(true)
    }
}

private struct SkeletonCard: View {
    let titleWidth: CGFloat
    let chips: [CGFloat]
    let footerWidth: CGFloat?
    let delay: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            bar(height: 20, radius: 8, fraction: titleWidth)
            HStack(spacing: 8) {
                ForEach(chips.indices, id: \.self) { i in
                    Capsule().fill(Color.controlFill).frame(width: chips[i], height: 26)
                }
            }
            if let footerWidth {
                bar(height: 14, radius: 6, fraction: footerWidth)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.paper, in: RoundedRectangle(cornerRadius: Metrics.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius).strokeBorder(Color.hairline, lineWidth: 2))
        .opacity(dimmed ? 0.5 : 1)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever().delay(delay)) { dimmed = true }
        }
    }

    private func bar(height: CGFloat, radius: CGFloat, fraction: CGFloat) -> some View {
        Color.clear
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: radius)
                        .fill(Color.controlFill)
                        .frame(width: proxy.size.width * fraction)
                }
            }
    }
}

/// Network or AI failure, with retry (and "change model" for AI failures).
private struct MenuErrorView: View {
    let error: AIError
    let onRetry: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(error.isNetwork ? .illusNetworkError : .illusAIError)
                .resizable()
                .frame(width: 120, height: 120)
                .accessibilityHidden(true)
            Text(error.isNetwork ? "results.error.network.title" : "results.error.ai.title")
                .font(.handwritten(26))
                .foregroundStyle(Color.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.cocoa)
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                Button(action: onRetry) {
                    HStack(spacing: 8) {
                        Image(.iconRetry).resizable().frame(width: 20, height: 20)
                        Text("results.retry")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
                if !error.isNetwork {
                    Button(error.isAccountProblem ? "results.error.openSettings" : "results.error.changeModel",
                           action: onOpenSettings)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ink)
                        .frame(minHeight: 44)
                }
            }
            .frame(width: 220)
            .padding(.top, 10)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 80)
    }

    /// A specific reason (bad key, unknown model…) when there is one, else the design's generic text.
    private var message: LocalizedStringResource {
        if error.isNetwork { return "results.error.network.message" }
        return error.detail ?? "results.error.ai.message"
    }
}

#Preview("Results") {
    let container = PreviewData.container()
    let store = PreviewData.menuStore(for: container)
    return NavigationStack { ResultsView(selectedTab: .constant(.cook)) }
        .modelContainer(container)
        .environment(AISettings())
        .environment(store)
}
