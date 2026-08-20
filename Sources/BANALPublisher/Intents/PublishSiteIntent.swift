import AppIntents
import BANALCore
import Foundation

public struct PublishSiteIntent: AppIntent {
    public static let title: LocalizedStringResource = "Publish Site"
    public static let description = IntentDescription("Publish notes in BANAL.")
    public static let openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let (statusCopy, dialog) = try await MainActor.run { () -> (String, String) in
            let store = try IntentVaultResolver.loadStore()
            let vault = store.configuration
            _ = CompilerBookmark.access(path: vault.borisBinaryPath, name: "boris")
            _ = CompilerBookmark.access(path: vault.oliverBinaryPath, name: "oliver")
            let configuration = PublishConfiguration.default(for: vault)
            let publisher = BANALPublisher.make(configuration: configuration)
            do {
                let result = try publisher.publish(
                    notes: store.notes,
                    vault: vault,
                    configuration: configuration
                )
                return (result.statusCopy, result.statusCopy)
            } catch PublishError.noPublishedNotes {
                return ("Nothing published.", "Nothing published — no notes are marked as published.")
            } catch PublishError.nothingCompiled {
                return ("Nothing published — recipes need Oliver.", "Nothing published — recipes need Oliver.")
            } catch {
                throw IntentVaultError.publishFailed(error.localizedDescription)
            }
        }

        return .result(
            value: statusCopy,
            dialog: IntentDialog(stringLiteral: dialog)
        )
    }
}
