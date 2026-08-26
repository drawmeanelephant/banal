import Foundation

/// Where BANAL's own copy of a helper engine lives inside this bundle.
/// `make app` packages universal binaries into `Contents/Helpers/`.
///
/// We ask `forAuxiliaryExecutable` first (Apple's sanctioned lookup) and
/// also probe the plain `Contents/Helpers/<name>` path we package into.
/// Running unsandboxed from source there is nothing — resolution then
/// falls through to env/PATH/sibling checkout exactly as before.
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
}
