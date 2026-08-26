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
        .accessibilityIdentifier("settings-root")
    }
}

private struct GeneralSettingsPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section {
                LabeledContent("Location") {
                    Text(model.store.configuration.rootURL.path)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                .accessibilityLabel("Notes folder location")
                .accessibilityValue(model.store.configuration.rootURL.path)
                HStack {
                    Button("Choose…") { chooseFolder() }
                        .accessibilityLabel("Choose notes folder")
                        .accessibilityHint("Select notes directory on disk")
                    Button("Reveal in Finder") { model.revealVault() }
                        .accessibilityLabel("Reveal notes folder in Finder")
                }
                Toggle("Open this folder when BANAL launches", isOn: $model.preferences.openMostRecentOnLaunch)
                    .accessibilityLabel("Open this folder when BANAL launches")
            } header: {
                Text("Notes folder")
            } footer: {
                Text("Your notes are ordinary files. This folder works in Finder, iCloud Drive, or git — BANAL never locks them up.")
            }
            Section("Organization") {
                Picker("Sort notes by", selection: $model.preferences.sort) {
                    ForEach(NoteSort.allCases, id: \.self) { sort in
                        Text(sort.menuTitle).tag(sort)
                    }
                }
                .accessibilityLabel("Sort notes by")
                Picker("New notes go in", selection: $model.preferences.newNoteLocation) {
                    ForEach(NewNoteLocation.allCases, id: \.self) { location in
                        Text(location.menuTitle).tag(location)
                    }
                }
                .accessibilityLabel("New notes default location")
                Toggle("Watch for edits from other apps", isOn: $model.preferences.watchExternalEdits)
                    .accessibilityLabel("Watch for edits from other apps")
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
                            .accessibilityLabel("Font size")
                            .accessibilityValue("\(Int(model.preferences.fontSize.rounded())) points")
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
                .accessibilityLabel("Line height")
                Toggle("Limit line length", isOn: $model.preferences.limitLineLength)
                    .accessibilityLabel("Limit line length")
                    .accessibilityHint("Restricts editor text column width to optimal measure")
            }
            Section("Editing") {
                Toggle("Typewriter scrolling", isOn: $model.preferences.typewriter)
                    .accessibilityLabel("Typewriter scrolling")
                    .accessibilityHint("Keeps the caret vertically centered while you type")
                Toggle("Check spelling", isOn: $model.preferences.spellCheck)
                    .accessibilityLabel("Check spelling")
                Toggle("Smart quotes", isOn: $model.preferences.smartQuotes)
                    .accessibilityLabel("Smart quotes and dashes")
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
                    .accessibilityLabel("Site title")
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Base URL", text: siteBaseURL)
                        .textContentType(.URL)
                        .accessibilityLabel("Site base URL")
                    if let message = PublishSettings.baseURLMessage(model.store.configuration.siteBaseURL) {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                TextField("Author", text: siteAuthor)
                    .accessibilityLabel("Site author")
            } header: {
                Text("Site")
            } footer: {
                Text("Used for the published site and RSS.")
            }
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Cloudflare Pages project", text: projectName)
                        .accessibilityLabel("Cloudflare Pages project name")
                    if let message = PublishSettings.projectNameMessage(model.store.configuration.cloudflareProjectName) {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Account ID", text: accountID)
                        .accessibilityLabel("Cloudflare account ID")
                    if let message = PublishSettings.accountIDMessage(model.store.configuration.cloudflareAccountID ?? "") {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                TextField("Custom domain", text: customDomain)
                    .accessibilityLabel("Custom domain")
                LabeledContent("API token (Keychain)") {
                    VStack(alignment: .leading, spacing: 6) {
                        SecureField(tokenSaved ? "Token saved in Keychain" : "Paste token", text: $tokenDraft)
                            .accessibilityLabel("Cloudflare API token")
                            .accessibilityHint("Secure token stored in macOS Keychain")
                        HStack {
                            Button("Save in Keychain") { saveToken() }
                                .accessibilityLabel("Save API token in Keychain")
                                .disabled(tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            if tokenSaved {
                                Button("Remove", role: .destructive) { removeToken() }
                                    .accessibilityLabel("Remove API token from Keychain")
                            }
                        }
                        Text(tokenSaved ? "Token saved in Keychain." : "Not connected — publishing stays on this Mac.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                HStack {
                    Text("Cloudflare Pages")
                    Spacer()
                    HelpLink(anchor: BanalHelp.readPublishAnchor, book: BanalHelp.bookName)
                        .help("Help with publishing")
                        .accessibilityLabel("Help with publishing")
                }
            } footer: {
                Text("Names and IDs travel with the notes folder. The token stays in Keychain.")
            }
            Section {
                Text(wranglerTOMLPreview)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .accessibilityLabel("Wrangler configuration: \(wranglerTOMLPreview)")
                HStack {
                    Button("Copy wrangler.toml") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(wranglerTOMLPreview, forType: .string)
                    }
                    .accessibilityLabel("Copy wrangler.toml configuration")
                }
            } header: {
                Text("wrangler.toml")
            } footer: {
                Text("Written to the artifact folder on publish. Copy this to customize before deploy.")
            }
            Section {
                Text(wranglerCommandPreview)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .accessibilityLabel("Wrangler command: \(wranglerCommandPreview)")
                HStack {
                    Button("Copy command") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(wranglerCommandPreview, forType: .string)
                    }
                    .accessibilityLabel("Copy wrangler deployment command")
                    Button("Deploy to Cloudflare") {
                        model.deployToCloudflare()
                    }
                    .accessibilityLabel("Deploy to Cloudflare Pages")
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

    private var deployPlan: CloudflareDeployPlan {
        let vault = model.store.configuration
        return CloudflareDeployer.plan(
            artifactDirectory: vault.publishURL,
            projectName: vault.cloudflareProjectName,
            accountID: vault.cloudflareAccountID,
            dryRun: true
        )
    }

    private var wranglerTOMLPreview: String {
        deployPlan.wranglerTOML
    }

    private var wranglerCommandPreview: String {
        deployPlan.command.joined(separator: " ")
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
