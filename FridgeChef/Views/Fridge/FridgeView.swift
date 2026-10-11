import SwiftUI
import SwiftData

/// The fridge tab: everything in the fridge and freezer, grouped, filterable and searchable.
struct FridgeView: View {
    /// Which item the editor sheet is open for.
    private enum EditorTarget: Identifiable {
        case add
        case edit(FoodItem)

        var id: String {
            switch self {
            case .add: "add"
            case .edit(let item): item.id.uuidString
            }
        }

        var item: FoodItem? {
            if case .edit(let item) = self { return item }
            return nil
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Query private var items: [FoodItem]
    @State private var filter: StorageFilter = .all
    @State private var query = ""
    @State private var editorTarget: EditorTarget?

    var body: some View {
        VStack(spacing: 0) {
            header
            if items.isEmpty {
                FridgeEmptyView { editorTarget = .add }
            } else {
                list(FridgeSections.build(items, filter: filter, query: query))
            }
        }
        .background(Color.cream.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $editorTarget) { target in
            ItemEditorSheet(item: target.item)
        }
        #if DEBUG
        // For simulator screenshots: launch with `-debugOpenEditor add` or `-debugOpenEditor <item name>`.
        .onAppear {
            switch UserDefaults.standard.string(forKey: "debugOpenEditor") {
            case nil: break
            case "add": editorTarget = .add
            case let name?: editorTarget = items.first(where: { $0.name == name }).map { .edit($0) }
            }
        }
        #endif
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                Button { editorTarget = .add } label: {
                    Image(.iconAdd)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(Color.onPastel)
                        .frame(width: 40, height: 40)
                        .background(Color.honey, in: Circle())
                        .overlay(Circle().strokeBorder(Color.ink, lineWidth: 2))
                        .background(Circle().fill(Color.ink).offset(x: 2, y: 2))
                }
                .accessibilityLabel(Text("fridge.add"))
            }
            .frame(height: 44)

            PageHeader(
                title: "fridge.title", icon: .iconFridge,
                caption: items.isEmpty ? nil : Text("fridge.total \(items.count)"))

            if !items.isEmpty {
                searchField
                Picker("filter.label", selection: $filter) {
                    ForEach(StorageFilter.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(.iconSearch)
                .resizable()
                .frame(width: 18, height: 18)
                .foregroundStyle(Color.cocoa)
            TextField("fridge.search", text: $query)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.cocoa)
                }
                .accessibilityLabel(Text("fridge.search.clear"))
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 38)
        .background(Color.controlFill, in: RoundedRectangle(cornerRadius: 10))
    }

    private func list(_ sections: [FridgeSection]) -> some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.items) { item in
                        row(item)
                    }
                } header: {
                    sectionHeader(section)
                }
            }
            if sections.isEmpty {
                Text("fridge.noResults")
                    .font(.subheadline)
                    .foregroundStyle(Color.cocoa)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
    }

    private func row(_ item: FoodItem) -> some View {
        Button { editorTarget = .edit(item) } label: {
            FoodItemCard(item: item)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("fridge.row.hint"))
        .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions {
            Button(role: .destructive) {
                modelContext.delete(item)
            } label: {
                Label("common.delete", systemImage: "trash")
            }
        }
    }

    private func sectionHeader(_ section: FridgeSection) -> some View {
        HStack(spacing: 6) {
            if section.kind == .urgent {
                Image(.iconSoon)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.ink)
            }
            Text(section.title)
                .font(.handwritten(20))
                .foregroundStyle(Color.ink)
            Text("fridge.count \(section.items.count)")
                .font(.footnote)
                .foregroundStyle(Color.cocoa)
            Spacer()
        }
        .padding(.horizontal, 2)
        .padding(.top, 10)
        .padding(.bottom, 2)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
        .background(Color.cream)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview("With items") {
    NavigationStack { FridgeView() }
        .modelContainer(PreviewData.container())
}

#Preview("Empty") {
    NavigationStack { FridgeView() }
        .modelContainer(PreviewData.container(empty: true))
}
