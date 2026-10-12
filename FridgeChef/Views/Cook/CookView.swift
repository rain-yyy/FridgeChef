import SwiftUI
import SwiftData

enum CookRoute: Hashable {
    case results
    case plan(UUID)
}

/// The cook tab: pick cuisine and servings, see what should be used soon, generate a menu.
struct CookView: View {
    @Binding var selectedTab: AppTab

    @Environment(AISettings.self) private var settings
    @Environment(MenuStore.self) private var menuStore
    @Environment(\.showToast) private var showToast
    @Query private var items: [FoodItem]
    @AppStorage("cook.cuisine") private var cuisine: Cuisine = .chinese
    @AppStorage("cook.servings") private var servings = 2
    @State private var path: [CookRoute] = []

    private var usableCount: Int { items.filter { !$0.expiryStatus.isExpired }.count }

    private var soonItems: [FoodItem] {
        items.filter { $0.expiryStatus.isSoon }.sorted { FridgeSections.inDisplayOrder($0, $1) }
    }

    private var expiredItems: [FoodItem] {
        items.filter { $0.expiryStatus.isExpired }.sorted { FridgeSections.inDisplayOrder($0, $1) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 4) {
                        PageHeader(title: "cook.title", icon: .iconCook)
                        Text(usableCount > 0 ? "cook.subtitle \(usableCount)" : "cook.subtitle.empty")
                            .font(.subheadline)
                            .foregroundStyle(Color.cocoa)
                    }
                    if !settings.isConfigured { noKeyCard }
                    mealSection
                    soonSection
                    if menuStore.result != nil, menuStore.phase != .loading { lastResultLink }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color.cream.ignoresSafeArea())
            .navigationTitle("cook.title")  // hidden here, but used as the back button label
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { generateBar }
            .navigationDestination(for: CookRoute.self) { route in
                switch route {
                case .results:
                    ResultsView(selectedTab: $selectedTab)
                case .plan(let id):
                    if let result = menuStore.result, let index = result.plans.firstIndex(where: { $0.id == id }) {
                        PlanDetailView(result: result, index: index, onFinished: finishCooking)
                    }
                }
            }
        }
        #if DEBUG
        // For simulator screenshots: `-debugGenerate YES` starts a generation on launch;
        // `-debugCookPath results|plan|deduct` opens the saved result, its first plan, or the deduction sheet.
        .onAppear {
            guard path.isEmpty else { return }
            if UserDefaults.standard.bool(forKey: "debugGenerate"), settings.isConfigured {
                generate()
            } else if let route = UserDefaults.standard.string(forKey: "debugCookPath"), let result = menuStore.result {
                path = route == "results" ? [.results] : [.results, .plan(result.plans[0].id)]
            }
        }
        #endif
    }

    // MARK: - Sections

    private var noKeyCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(.illusKey)
                .resizable()
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("cook.noKey.title")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.ink)
                Text("cook.noKey.message")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSoft)
                Button("cook.noKey.action") { selectedTab = .settings }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(Color.paper, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.ink, lineWidth: 1.5))
                    .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.honeySoft, in: RoundedRectangle(cornerRadius: Metrics.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius).strokeBorder(Color.ink, lineWidth: Metrics.cardStroke))
    }

    private var mealSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("cook.section.meal")
            VStack(spacing: 14) {
                HStack {
                    Text("cook.cuisine")
                    Spacer(minLength: 12)
                    Picker("cook.cuisine", selection: $cuisine) {
                        ForEach(Cuisine.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 180)
                }
                DashedDivider()
                Stepper(value: $servings, in: 1...10) {
                    Text("cook.servings \(servings)")
                }
            }
            .foregroundStyle(Color.ink)
            .cardStyle(padding: 16)
        }
    }

    private var soonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(.iconSoon)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.ink)
                sectionTitle("cook.section.soon")
                Text("cook.section.soon.caption")
                    .font(.footnote)
                    .foregroundStyle(Color.cocoa)
            }
            if soonItems.isEmpty {
                Text("cook.soon.none")
                    .font(.subheadline)
                    .foregroundStyle(Color.cocoa)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle(padding: 14)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(soonItems) { SoonItemCard(item: $0) }
                }
            }
            if !expiredItems.isEmpty {
                HStack(spacing: 6) {
                    Text("cook.expired.note \(expiredItems.count) \(expiredItems.map(\.name).formatted(.list(type: .and)))")
                    Button("cook.expired.action") { selectedTab = .fridge }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.ink)
                }
                .font(.footnote)
                .foregroundStyle(Color.cocoa)
                .padding(.horizontal, 2)
            }
        }
    }

    private var lastResultLink: some View {
        Button { path = [.results] } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("cook.lastResult").font(.callout.weight(.semibold))
                    if let result = menuStore.result {
                        Text(verbatim: "\(String(localized: result.cuisine.displayName)) · \(String(localized: "results.servings \(result.servings)")) · \(result.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.footnote)
                            .foregroundStyle(Color.cocoa)
                    }
                }
                Spacer()
                Image(.iconForward).resizable().frame(width: 16, height: 16)
            }
            .foregroundStyle(Color.ink)
            .cardStyle(padding: 14)
        }
        .buttonStyle(.plain)
    }

    private var generateBar: some View {
        let canGenerate = settings.isConfigured && usableCount > 0
        return VStack(spacing: 8) {
            Button(action: generate) {
                HStack(spacing: 8) {
                    Image(.iconSparkle).resizable().frame(width: 20, height: 20)
                    if canGenerate {
                        Text("cook.generate.summary \(String(localized: cuisine.displayName)) \(servings)")
                    } else {
                        Text("cook.generate")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary)
            .disabled(!canGenerate)
            if !settings.isConfigured {
                Text("cook.generate.needsKey").font(.footnote).foregroundStyle(Color.cocoa)
            } else if usableCount == 0 {
                Text("cook.generate.needsFood").font(.footnote).foregroundStyle(Color.cocoa)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .background(
            LinearGradient(stops: [.init(color: Color.cream.opacity(0), location: 0), .init(color: Color.cream, location: 0.3)],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.handwritten(20))
            .foregroundStyle(Color.ink)
            .accessibilityAddTraits(.isHeader)
    }

    /// After "做完了" → confirm: back to the cook root, switch to the fridge, and say what changed.
    private func finishCooking(_ summary: Deduction.Summary) {
        path = []
        selectedTab = .fridge
        showToast(summary.removed > 0
            ? String(localized: "deduct.toast.removed \(summary.deducted) \(summary.removed)")
            : String(localized: "deduct.toast \(summary.deducted)"))
    }

    private func generate() {
        menuStore.generate(.init(cuisine: cuisine, servings: servings), items: items, settings: settings)
        path = [.results]
    }
}

/// A use-soon item on the cook page: small badge, name, amount, expiry tag.
private struct SoonItemCard: View {
    let item: FoodItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                CategoryBadge(category: item.category, size: 32)
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.name).font(.callout.weight(.semibold)).lineLimit(1)
                    Text(item.quantityText).font(.footnote).foregroundStyle(Color.cocoa)
                }
            }
            ExpiryTag(status: item.expiryStatus)
        }
        .foregroundStyle(Color.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14)
    }
}

/// The dashed hairline used inside cards.
struct DashedDivider: View {
    var body: some View {
        Line()
            .stroke(Color.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            .frame(height: 1.5)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { $0.move(to: CGPoint(x: 0, y: rect.midY)); $0.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) }
        }
    }
}

#if DEBUG
#Preview {
    CookView(selectedTab: .constant(.cook))
        .modelContainer(PreviewData.container())
        .environment(AISettings())
        .environment(MenuStore(fileURL: nil))
}
#endif
