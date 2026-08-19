import AppKit
import BANALCore
import BANALPublisher
import SwiftUI

struct SettingsRoot: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TabView {
            GeneralSettingsPane(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
                .accessibilityLabel("General")
            EditorSettingsPane(model: model)
                .tabItem { Label("Editor", systemImage: "textformat") }
                .accessibilityLabel("Editor")
            PublishSettingsPane(model: model)
                .tabItem { Label("Publish", systemImage: "globe") }
                .accessibilityLabel("Publish")
        }
        .frame(width: 520, height: 720)
        .accessibilityLabel("Settings")
    }
}

private struct GeneralSettingsPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Notes folder") {
                LabeledContent("Location") {
                    Text(model.store.configuration.rootURL.path)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                HStack {
                    Button("Choose…") { chooseFolder() }
                    Button("Reveal in Finder") { model.revealVault() }
                }
                Toggle("Open this folder when BANAL launches", isOn: $model.preferences.openMostRecentOnLaunch)
            }
            Section("Organization") {
                Picker("Sort notes by", selection: $model.preferences.sort) {
                    ForEach(NoteSort.allCases, id: \.self) { sort in
                        Text(sort.menuTitle).tag(sort)
                    }
                }
                Picker("New notes go in", selection: $model.preferences.newNoteLocation) {
                    ForEach(NewNoteLocation.allCases, id: \.self) { location in
                        Text(location.menuTitle).tag(location)
                    }
                }
                Toggle("Watch for edits from other apps", isOn: $model.preferences.watchExternalEdits)
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .onChange(of: model.preferences) { _, _ in
            model.savePreferences()
        }
    }

    private func chooseFolder() {
        if let url = NotesFolderPicker.run() {
            model.openVault(url)
        }
    }
}

private struct EditorSettingsPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Type") {
                LabeledContent("Size") {
                    HStack(spacing: 10) {
                        Slider(value: $model.preferences.fontSize, in: 13...22, step: 1)
                        Text("\(Int(model.preferences.fontSize.rounded()))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 22, alignment: .trailing)
                    }
                }
                Picker("Line height", selection: $model.preferences.lineHeight) {
                    ForEach(LineHeightSetting.allCases, id: \.self) { height in
                        Text(height.menuTitle).tag(height)
                    }
                }
                Toggle("Limit line length", isOn: $model.preferences.limitLineLength)
            }
            Section("Editing") {
                Toggle("Check spelling", isOn: $model.preferences.spellCheck)
                Toggle("Smart quotes", isOn: $model.preferences.smartQuotes)
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .onChange(of: model.preferences) { _, _ in
            model.savePreferences()
        }
    }
}

private struct PublishSettingsPane: View {
    @ObservedObject var model: AppModel
    @State private var tokenDraft = ""
    @State private var tokenSaved = false

    var body: some View {
        Form {
            Section {
                TextField("Site title", text: siteTitle)
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Base URL", text: siteBaseURL)
                        .textContentType(.URL)
                    if let message = PublishSettings.baseURLMessage(model.store.configuration.siteBaseURL) {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                TextField("Author", text: siteAuthor)
            } header: {
                Text("Site")
            } footer: {
                Text("Used for the published site and RSS.")
            }
            Section {
                compilerRow(
                    title: "Boris (optional)",
                    path: model.store.configuration.borisBinaryPath,
                    choose: { chooseBinary(named: "Boris") { path in
                        var next = model.store.configuration
                        next.borisBinaryPath = path
                        model.updateVaultConfiguration(next)
                    } },
                    reveal: { revealBinary(model.store.configuration.borisBinaryPath) },
                    clear: {
                        CompilerBookmark.forget(name: "boris")
                        var next = model.store.configuration
                        next.borisBinaryPath = nil
                        model.updateVaultConfiguration(next)
                    }
                )
                compilerRow(
                    title: "Oliver (optional)",
                    path: model.store.configuration.oliverBinaryPath,
                    choose: { chooseBinary(named: "Oliver") { path in
                        var next = model.store.configuration
                        next.oliverBinaryPath = path
                        model.updateVaultConfiguration(next)
                    } },
                    reveal: { revealBinary(model.store.configuration.oliverBinaryPath) },
                    clear: {
                        CompilerBookmark.forget(name: "oliver")
                        var next = model.store.configuration
                        next.oliverBinaryPath = nil
                        model.updateVaultConfiguration(next)
                    }
                )
            } header: {
                Text("Boris and Oliver")
            } footer: {
                Text("Boris compiles the site. Oliver reads recipes. Empty is fine.")
            }
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Cloudflare Pages project", text: projectName)
                    if let message = PublishSettings.projectNameMessage(model.store.configuration.cloudflareProjectName) {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Account ID", text: accountID)
                    if let message = PublishSettings.accountIDMessage(model.store.configuration.cloudflareAccountID ?? "") {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                TextField("Custom domain", text: customDomain)
                LabeledContent("API token (Keychain)") {
                    VStack(alignment: .leading, spacing: 6) {
                        SecureField(tokenSaved ? "Token saved in Keychain" : "Paste token", text: $tokenDraft)
                        HStack {
                            Button("Save in Keychain") { saveToken() }
                                .disabled(tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            if tokenSaved {
                                Button("Remove", role: .destructive) { removeToken() }
                            }
                        }
                        Text(tokenSaved ? "Token saved in Keychain." : "Not connected — publishing stays on this Mac.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Cloudflare Pages")
            } footer: {
                Text("Names and IDs travel with the notes folder. The token stays in Keychain.")
            }
            Section {
                Text(wranglerPreview)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                HStack {
                    Button("Copy command") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(wranglerPreview, forType: .string)
                    }
                    Button("Deploy to Cloudflare") {
                        model.deployToCloudflare()
                    }
                    .disabled(!model.canDeploy)
                    .help(model.canDeploy
                          ? "Deploy the last site to Cloudflare Pages."
                          : "Save an API token (Keychain) to enable deploy.")
                }
            } header: {
                Text("Deploy")
            } footer: {
                Text("Publish Site writes the folder. Deploy is optional.")
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .onAppear {
            tokenSaved = PublishKeychain.hasToken(vaultURL: model.store.configuration.rootURL)
        }
    }

    @ViewBuilder
    private func compilerRow(
        title: String,
        path: String?,
        choose: @escaping () -> Void,
        reveal: @escaping () -> Void,
        clear: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
            Text(compilerPathLabel(path))
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(path ?? "")
            HStack {
                Button("Choose…") { choose() }
                Button("Reveal") { reveal() }
                    .disabled(!compilerPathIsSet(path))
                if compilerPathIsSet(path) {
                    Button("Clear") { clear() }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(compilerPathLabel(path))
    }

    private func compilerPathLabel(_ path: String?) -> String {
        guard let path, !path.isEmpty else { return "Not set" }
        return path
    }

    private func compilerPathIsSet(_ path: String?) -> Bool {
        guard let path else { return false }
        return !path.isEmpty
    }

    private func chooseBinary(named name: String, set: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Choose"
        panel.message = "Choose \(name)."
        if panel.runModal() == .OK, let url = panel.url {
            CompilerBookmark.save(url, name: name.lowercased())
            set(url.path)
        }
    }

    private func revealBinary(_ path: String?) {
        guard let path, !path.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private var siteTitle: Binding<String> {
        field(\.siteTitle) { $0.siteTitle = $1 }
    }

    private var siteBaseURL: Binding<String> {
        field(\.siteBaseURL) { $0.siteBaseURL = $1 }
    }

    private var siteAuthor: Binding<String> {
        field(\.siteAuthor) { $0.siteAuthor = $1 }
    }

    private var projectName: Binding<String> {
        field(\.cloudflareProjectName) { $0.cloudflareProjectName = $1 }
    }

    private var accountID: Binding<String> {
        Binding(
            get: { model.store.configuration.cloudflareAccountID ?? "" },
            set: { value in
                var next = model.store.configuration
                next.cloudflareAccountID = value.isEmpty ? nil : value
                model.updateVaultConfiguration(next)
            }
        )
    }

    private var customDomain: Binding<String> {
        field(\.cloudflareCustomDomain) { $0.cloudflareCustomDomain = $1 }
    }

    private func field<T>(
        _ keyPath: KeyPath<VaultConfiguration, T>,
        set: @escaping (inout VaultConfiguration, T) -> Void
    ) -> Binding<T> {
        Binding(
            get: { model.store.configuration[keyPath: keyPath] },
            set: { newValue in
                var next = model.store.configuration
                set(&next, newValue)
                model.updateVaultConfiguration(next)
            }
        )
    }

    private var wranglerPreview: String {
        let vault = model.store.configuration
        let plan = CloudflareDeployer.plan(
            artifactDirectory: vault.publishURL,
            projectName: vault.cloudflareProjectName,
            accountID: vault.cloudflareAccountID,
            dryRun: true
        )
        return plan.command.joined(separator: " ")
    }

    private func saveToken() {
        do {
            try PublishKeychain.save(token: tokenDraft, vaultURL: model.store.configuration.rootURL)
            tokenDraft = ""
            tokenSaved = PublishKeychain.hasToken(vaultURL: model.store.configuration.rootURL)
        } catch {
            model.statusMessage = error.localizedDescription
        }
    }

    private func removeToken() {
        PublishKeychain.delete(vaultURL: model.store.configuration.rootURL)
        tokenDraft = ""
        tokenSaved = false
    }
}
