import Foundation

/// Where BANAL's own copy of a helper engine lives.
/// `make app` packages universal binaries into `Contents/Helpers/`.
///
/// We ask `forAuxiliaryExecutable` first (Apple's sanctioned lookup) and
/// also probe the plain `Contents/Helpers/<name>` path we package into.
/// Running unsandboxed from source there is nothing — resolution then
/// falls through to env/PATH/sibling checkout exactly as before.
///
/// `installedAppHelperURLs` is deliberately NOT part of `executables`:
/// it is machine-global (any installed BANAL.app), so locator tests with
/// default auxiliary injection must stay isolated from it. The one caller
/// is the CLI's doctor — publish keeps the locator chain, so a bare-CLI
/// publish matches the app's own engine choice, not a borrowed bundle.
public enum BundledHelper {
    public static func executables(named name: String) -> [URL] {
        var urls: [URL] = []
        if let url = Bundle.main.url(forAuxiliaryExecutable: name) {
            urls.append(url)
        }
        urls.append(
            Bundle.main.bundleURL
                .appendingPathComponent("Contents", isDirectory: true)
                .appendingPathComponent("Helpers", isDirectory: true)
                .appendingPathComponent(name)
        )
        return urls
    }

    /// `Contents/Helpers/<name>` inside every installed-app candidate,
    /// user-local `~/Applications` first, then the system `/Applications`.
    public static func installedAppHelperURLs(named name: String) -> [URL] {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Applications", isDirectory: true),
            URL(fileURLWithPath: "/Applications", isDirectory: true),
        ]
        .map { $0.appendingPathComponent("BANAL.app", isDirectory: true)
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Helpers", isDirectory: true)
            .appendingPathComponent(name) }
    }
}
