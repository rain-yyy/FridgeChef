import SwiftUI
import SwiftData

/// Add / edit sheet for one food item. `item == nil` means adding.
struct ItemEditorSheet: View {
    let item: FoodItem?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ItemDraft
    @State private var confirmingDelete = false
    /// Name of the last item saved with "save and add another", shown as feedback.
    @State private var lastSavedName: String?
    @FocusState private var nameFocused: Bool

    init(item: FoodItem?) {
        self.item = item
        _draft = State(initialValue: item.map { ItemDraft(editing: $0) } ?? ItemDraft())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("editor.name") {
                    TextField("editor.name.placeholder", text: binding(draft.name) { draft.setName($0) })
                        .focused($nameFocused)
                        .submitLabel(.done)
                }
                .listRowBackground(Color.paper)

                Section("editor.category") {
                    Picker("editor.category", selection: binding(draft.category) { draft.setCategory($0) }) {
                        ForEach(FoodCategory.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .listRowBackground(Color.paper)

                Section("editor.storage") {
                    Picker("editor.storage", selection: binding(draft.storage) { draft.setStorage($0) }) {
                        ForEach(StorageLocation.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .listRowBackground(Color.paper)

                Section("editor.section.quantity") {
                    Stepper(value: $draft.quantity, in: 0.5...999, step: 0.5) {
                        Text("editor.quantity \(draft.quantity.formatted())")
                    }
                    Picker("editor.unit", selection: $draft.unit) {
                        ForEach(QuantityUnit.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                .listRowBackground(Color.paper)

                Section {
                    DatePicker(
                        "editor.addedDate",
                        selection: binding(draft.addedDate) { draft.setAddedDate($0) },
                        in: ...Date.now, displayedComponents: .date)
                    if draft.storage == .fridge, let expiry = draft.expiryDate {
                        DatePicker(
                            "editor.expiryDate",
                            selection: binding(expiry) { draft.setExpiryDate($0) },
                            displayedComponents: .date)
                    }
                } header: {
                    Text("editor.dates")
                } footer: {
                    expiryFooter
                }
                .listRowBackground(Color.paper)

                if item != nil {
                    Section {
                        Button(role: .destructive) { confirmingDelete = true } label: {
                            Text("editor.delete").frame(maxWidth: .infinity)
                        }
                    }
                    .listRowBackground(Color.paper)
                } else {
                    Section {
                        Button(action: saveAndAddAnother) {
                            Text("editor.saveAndAddAnother").frame(maxWidth: .infinity)
                        }
                        .disabled(!draft.canSave)
                    } footer: {
                        if let lastSavedName {
                            Text("editor.savedNotice \(lastSavedName)")
                        }
                    }
                    .listRowBackground(Color.paper)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.cream.ignoresSafeArea())
            .handwrittenInlineTitle(item == nil ? "editor.title.add" : "editor.title.edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!draft.canSave)
                }
            }
            .confirmationDialog(
                Text("editor.delete.confirm \(draft.name)"), isPresented: $confirmingDelete, titleVisibility: .visible
            ) {
                Button("common.delete", role: .destructive, action: delete)
            }
            .onAppear { if item == nil { nameFocused = true } }
        }
        .tint(Color.ink)
    }

    @ViewBuilder
    private var expiryFooter: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(noteText)
            Spacer(minLength: 8)
            if draft.expiryNote == .edited {
                Button("editor.resetExpiry") { draft.resetExpiry() }
                    .font(.footnote.weight(.semibold))
                    .textCase(nil)
            }
        }
    }

    private var noteText: LocalizedStringResource {
        switch draft.expiryNote {
        case .frozen: "editor.note.frozen"
        case .edited: "editor.note.edited"
        case .auto(let source): "editor.note.auto \(sourceText(source))"
        case .thawed(let source): "editor.note.thawed \(sourceText(source))"
        }
    }

    private func sourceText(_ source: ShelfLifePreset.Source) -> String {
        switch source {
        case .name(let days):
            String(localized: "editor.source.name \(draft.name.trimmingCharacters(in: .whitespacesAndNewlines)) \(days)")
        case .category(let days):
            String(localized: "editor.source.category \(String(localized: draft.category.displayName)) \(days)")
        }
    }

    /// A binding that reads a draft value and writes through one of the draft's rule-applying setters.
    private func binding<Value>(_ value: Value, set: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(get: { value }, set: set)
    }

    private func save() {
        if let item {
            draft.apply(to: item)
        } else {
            modelContext.insert(draft.makeItem())
        }
        dismiss()
    }

    private func saveAndAddAnother() {
        let saved = draft.makeItem()
        modelContext.insert(saved)
        lastSavedName = saved.name
        draft.prepareNextItem()
        nameFocused = true
    }

    private func delete() {
        if let item { modelContext.delete(item) }
        dismiss()
    }
}

#Preview("Add") {
    ItemEditorSheet(item: nil)
        .modelContainer(PreviewData.container(empty: true))
}

#Preview("Edit") {
    let container = PreviewData.container()
    let item = try! container.mainContext.fetch(FetchDescriptor<FoodItem>()).first!
    return ItemEditorSheet(item: item)
        .modelContainer(container)
}
