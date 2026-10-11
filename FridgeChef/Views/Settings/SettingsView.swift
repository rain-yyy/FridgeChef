import SwiftUI

/// Settings tab: OpenRouter API key and model, connection test, about.
struct SettingsView: View {
    private enum TestState: Equatable {
        case idle, testing, ok
        case failed(AIError)
    }

    @Environment(AISettings.self) private var settings
    @State private var keyRevealed = false
    @State private var testState: TestState = .idle

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                HStack(spacing: 10) {
                    Text("settings.apiKey").frame(width: 76, alignment: .leading)
                    Group {
                        if keyRevealed {
                            TextField("settings.apiKey.placeholder", text: $settings.apiKey)
                        } else {
                            SecureField("settings.apiKey.placeholder", text: $settings.apiKey)
                        }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.callout.monospaced())
                    Button { keyRevealed.toggle() } label: {
                        Image(keyRevealed ? .iconEyeSlash : .iconEye)
                            .resizable()
                            .frame(width: 22, height: 22)
                            .foregroundStyle(Color.cocoa)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(keyRevealed ? "settings.apiKey.hide" : "settings.apiKey.show"))
                }

                HStack(spacing: 10) {
                    Text("settings.model").frame(width: 76, alignment: .leading)
                    TextField("settings.model.placeholder", text: $settings.model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(.subheadline)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("settings.models.suggested")
                        .font(.caption)
                        .foregroundStyle(Color.cocoa)
                    FlowLayout {
                        ForEach(AISettings.suggestedModels, id: \.self) { model in
                            modelChip(model, selected: settings.trimmedModel == model)
                        }
                    }
                }
                .padding(.vertical, 4)

                HStack(spacing: 10) {
                    Button("settings.test", action: testConnection)
                        .fontWeight(.semibold)
                        .foregroundStyle(settings.isConfigured ? Color.ink : Color.disabledText)
                        .disabled(!settings.isConfigured || testState == .testing)
                    Spacer(minLength: 8)
                    testStatus.font(.subheadline)
                }
                .frame(minHeight: 44)
            } header: {
                VStack(alignment: .leading, spacing: 16) {
                    PageHeader(title: "settings.title", icon: .iconSettings)
                        .textCase(nil)
                    Text("settings.section.ai")
                }
            } footer: {
                Text("settings.ai.footer")
            }
            .listRowBackground(Color.paper)

            Section("settings.section.about") {
                LabeledContent("settings.version", value: Self.versionText)
                LabeledContent("settings.appName") { Text("settings.appNote") }
            }
            .listRowBackground(Color.paper)
        }
        .foregroundStyle(Color.ink)
        .scrollContentBackground(.hidden)
        .background(Color.cream.ignoresSafeArea())
        .scrollDismissesKeyboard(.immediately)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: settings.apiKey) { testState = .idle }
        .onChange(of: settings.model) { testState = .idle }
    }

    private func modelChip(_ model: String, selected: Bool) -> some View {
        Button { settings.model = model } label: {
            Text(verbatim: model)
                .font(.caption.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.onPastel : Color.ink)
                .padding(.horizontal, 10)
                .frame(minHeight: 30)
                .background(selected ? Color.honey : Color.paper, in: Capsule())
                .overlay(Capsule().strokeBorder(selected ? Color.ink : Color.weakStroke, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var testStatus: some View {
        switch testState {
        case .idle:
            Text("settings.test.idle").foregroundStyle(Color.cocoa)
        case .testing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("settings.test.testing")
            }
            .foregroundStyle(Color.cocoa)
        case .ok:
            HStack(spacing: 6) {
                Image(.iconCheck)
                    .resizable()
                    .frame(width: 11, height: 11)
                    .foregroundStyle(Color.onPastel)
                    .frame(width: 20, height: 20)
                    .background(Color.catVeg, in: Circle())
                    .overlay(Circle().strokeBorder(Color.ink, lineWidth: 1.5))
                Text("settings.test.ok")
            }
            .foregroundStyle(Color.cocoa)
        case .failed(let error):
            Text(error.detail ?? "settings.test.failed")
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.trailing)
        }
    }

    private func testConnection() {
        testState = .testing
        let client = settings.makeClient()
        Task {
            do throws(AIError) {
                try await client.testConnection()
                testState = .ok
            } catch {
                testState = .failed(error)
            }
        }
    }

    private static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(AISettings())
}
