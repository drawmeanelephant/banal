import AppKit
import BANALCore
import BANALPublisher
import Combine
import Foundation

/// Publishing and Cloudflare deploy: build the static site from the
/// vault's published notes, then optionally push it. Publishing stays
/// optional, explicit, and late — local notes never require it.
@MainActor
public final class PublishController: ObservableObject {
    @Published public private(set) var lastResult: PublishResult?

    /// Side effect seam so tests stay hermetic; defaults to Finder reveal.
    public var reveal: (URL) -> Void = { NSWorkspace.shared.activateFileViewerSelecting([$0]) }

    public init() {}

    // MARK: - Capability

    public func canDeploy(vault: VaultConfiguration) -> Bool {
        CloudflareDeployer.canDeploy(
            projectName: vault.cloudflareProjectName,
            token: PublishKeychain.token(vaultURL: vault.rootURL)
        )
    }

    // MARK: - Publish site

    public struct Outcome {
        public var message: String
        /// Artifact to reveal in Finder, when one was produced.
        public var artifact: URL?
        /// Log text to put on the clipboard (deploy failures).
        public var clipboardLog: String?
    }

    /// Publish the vault to its local staging area.
    public func publishSite(vault: VaultConfiguration, notes: [Note]) -> Outcome {
        do {
            let result = try publishNow(vault: vault, notes: notes)
            lastResult = result
            return Outcome(message: result.statusCopy, artifact: result.artifactDirectory, clipboardLog: nil)
        } catch PublishError.noPublishedNotes {
            return Outcome(message: "Nothing published.", artifact: nil, clipboardLog: nil)
        } catch PublishError.nothingCompiled {
            return Outcome(message: "Nothing published — recipes need Oliver.", artifact: nil, clipboardLog: nil)
        } catch {
            return Outcome(message: error.localizedDescription, artifact: nil, clipboardLog: nil)
        }
    }

    /// Deploy the staged site to Cloudflare Pages, publishing first when
    /// no artifact exists yet.
    public func deployToCloudflare(vault: VaultConfiguration, notes: [Note]) -> Outcome {
        guard let token = PublishKeychain.token(vaultURL: vault.rootURL),
              CloudflareDeployer.canDeploy(projectName: vault.cloudflareProjectName, token: token)
        else {
            return Outcome(message: "Not connected — publishing stays on this Mac.", artifact: nil, clipboardLog: nil)
        }
        do {
            let index = vault.publishURL.appendingPathComponent("index.html")
            if !FileManager.default.fileExists(atPath: index.path) {
                _ = try publishNow(vault: vault, notes: notes)
            }
            let plan = CloudflareDeployer.plan(
                artifactDirectory: vault.publishURL,
                projectName: vault.cloudflareProjectName,
                accountID: vault.cloudflareAccountID,
                dryRun: false
            )
            _ = try CloudflareDeployer.deploy(plan: plan, token: token)
            return Outcome(message: "Deployed to Cloudflare Pages.", artifact: nil, clipboardLog: nil)
        } catch CloudflareDeployError.wranglerMissing {
            return Outcome(message: "Can't deploy — wrangler isn't installed.", artifact: nil, clipboardLog: nil)
        } catch CloudflareDeployError.failed(_, let log) {
            return Outcome(message: "Deploy failed. The log is on the clipboard.", artifact: nil, clipboardLog: log)
        } catch PublishError.noPublishedNotes {
            return Outcome(message: "Nothing published.", artifact: nil, clipboardLog: nil)
        } catch PublishError.nothingCompiled {
            return Outcome(message: "Nothing published — recipes need Oliver.", artifact: nil, clipboardLog: nil)
        } catch {
            return Outcome(message: error.localizedDescription, artifact: nil, clipboardLog: nil)
        }
    }

    // MARK: - Pipeline

    private func publishNow(vault: VaultConfiguration, notes: [Note]) throws -> PublishResult {
        _ = CompilerBookmark.access(path: vault.borisBinaryPath, name: "boris")
        _ = CompilerBookmark.access(path: vault.oliverBinaryPath, name: "oliver")
        let configuration = PublishConfiguration.default(for: vault)
        return try BANALPublisher.make(configuration: configuration).publish(
            notes: notes,
            vault: vault,
            configuration: configuration
        )
    }
}
