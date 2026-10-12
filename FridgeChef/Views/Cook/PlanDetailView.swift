import SwiftUI
import SwiftData

/// One plan in full: each dish's fridge ingredients, extras and steps, then "做完了".
struct PlanDetailView: View {
    let result: MenuResult
    let index: Int
    /// Called after the deduction is confirmed, so the cook tab can return to the fridge.
    let onFinished: (Deduction.Summary) -> Void

    @State private var deducting = false

    private var plan: MenuPlan { result.plans[index] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                ForEach(Array(plan.dishes.enumerated()), id: \.element.id) { number, dish in
                    DishCard(dish: dish, number: number + 1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .background(Color.cream.ignoresSafeArea())
        .handwrittenInlineTitle(MenuPlan.label(at: index))
        .safeAreaInset(edge: .bottom) {
            Button { deducting = true } label: {
                HStack(spacing: 8) {
                    Image(.iconCheck).resizable().frame(width: 18, height: 18)
                    Text("plan.done")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 10)
            .background(
                LinearGradient(stops: [.init(color: Color.cream.opacity(0), location: 0), .init(color: Color.cream, location: 0.3)],
                               startPoint: .top, endPoint: .bottom)
            )
        }
        .sheet(isPresented: $deducting) {
            DeductSheet(plan: plan, planLabel: MenuPlan.label(at: index)) { summary in
                deducting = false
                onFinished(summary)
            }
        }
        #if DEBUG
        // For simulator screenshots: `-debugCookPath deduct|confirm` opens the sheet.
        .onAppear {
            if ["deduct", "confirm"].contains(UserDefaults.standard.string(forKey: "debugCookPath")) { deducting = true }
        }
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: plan.dishes.map(\.name).joined(separator: "\n"))
                .font(.handwritten(26))
                .lineSpacing(4)
            Text(verbatim: metaText)
                .font(.subheadline)
                .foregroundStyle(Color.cocoa)
            if let note = plan.note {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(.iconFrozen).resizable().frame(width: 14, height: 14)
                    Text(verbatim: note)
                }
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.frozen, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(Color.onPastel)
                .padding(.top, 4)
            }
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 2)
    }

    /// "中餐 · 2 人份 · 约 25 分钟 · 用掉 2 样快过期食材"
    private var metaText: String {
        var parts = [String(localized: result.cuisine.displayName), String(localized: "results.servings \(result.servings)")]
        if let minutes = plan.minutes { parts.append(String(localized: "results.minutes \(minutes)")) }
        let soon = plan.soonItemCount
        if soon > 0 { parts.append(String(localized: "results.usesSoon \(soon)")) }
        return parts.joined(separator: " · ")
    }
}

/// One dish: numbered title, fridge ingredients with amounts, extras to prepare, steps.
private struct DishCard: View {
    let dish: Dish
    let number: Int

    @ScaledMetric private var numberSize: CGFloat = 30
    @ScaledMetric(relativeTo: .subheadline) private var stepSize: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text(verbatim: "\(number)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.onPastel)
                    .frame(width: numberSize, height: numberSize)
                    .background(Color.honey, in: Circle())
                    .overlay(Circle().strokeBorder(Color.ink, lineWidth: 1.5))
                Text(dish.name).font(.handwritten(21))
            }

            if !dish.ingredients.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    caption("plan.fromFridge")
                    ForEach(dish.ingredients, id: \.itemID) { ingredient in
                        HStack(spacing: 8) {
                            Text(verbatim: ingredient.name)
                            if ingredient.wasSoon {
                                Text("plan.soonTag")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.onPastel)
                                    .padding(.horizontal, 8)
                                    .frame(minHeight: 22)
                                    .background(Color.soon, in: Capsule())
                                    .overlay(Capsule().strokeBorder(Color.ink, lineWidth: 1.5))
                            }
                            DottedLeader()
                            Text(verbatim: ingredient.amountText).fontWeight(.semibold)
                        }
                        .frame(minHeight: 30)
                    }
                }
            }

            if !dish.extras.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    caption("plan.extras")
                    FlowLayout {
                        ForEach(dish.extras, id: \.self) { extra in
                            Text(verbatim: extra)
                                .font(.footnote)
                                .foregroundStyle(Color.inkSoft)
                                .padding(.horizontal, 10)
                                .frame(minHeight: 26)
                                .overlay(Capsule().strokeBorder(Color.weakStroke, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])))
                        }
                    }
                }
            }

            if !dish.steps.isEmpty {
                DashedDivider()
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(dish.steps.enumerated()), id: \.offset) { offset, step in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(verbatim: "\(offset + 1)")
                                .font(.caption.weight(.bold))
                                .frame(width: stepSize, height: stepSize)
                                .overlay(Circle().strokeBorder(Color.ink, lineWidth: 1.5))
                                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                            Text(verbatim: step)
                                .font(.subheadline)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .foregroundStyle(Color.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 16)
    }

    private func caption(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.cocoa)
    }
}

/// Dotted line filling the space between an ingredient and its amount.
private struct DottedLeader: View {
    var body: some View {
        Rectangle()
            .fill(.clear)
            .frame(height: 1.5)
            .overlay(
                GeometryReader { proxy in
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0.75))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: 0.75))
                    }
                    .stroke(Color.hairline, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [0.1, 4]))
                }
            )
            .padding(.horizontal, 4)
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    let container = PreviewData.container()
    let store = PreviewData.menuStore(for: container)
    return NavigationStack {
        PlanDetailView(result: store.result!, index: 0) { _ in }
    }
    .modelContainer(container)
}
#endif
