import Foundation
import BANALCore

/// Isolated publishing service. Local editing never calls this.
public struct BANALPublisher: Sendable {
    public var compiler: any SiteCompiling

    public init(compiler: any SiteCompiling = BuiltinSiteCompiler()) {
        self.compiler = compiler
    }

    public static func make(configuration: PublishConfiguration) -> BANALPublisher {
        if configuration.preferBoris, let binary = configuration.borisBinaryURL {
            return BANALPublisher(compiler: BorisCLICompiler(binaryURL: binary))
        }
        return BANALPublisher(compiler: BuiltinSiteCompiler())
    }

    public func publish(
        notes: [Note],
        vault: VaultConfiguration,
        configuration: PublishConfiguration,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) throws -> PublishResult {
        let staged = try BorisAdapter.stage(
            notes: notes,
            configuration: configuration,
            assetsSource: vault.assetsURL,
            fileManager: fileManager
        )
        let compile = try compiler.compile(
            stagingDirectory: configuration.stagingDirectory,
            artifactDirectory: configuration.artifactDirectory,
            pages: staged.pages,
            configuration: configuration
        )

        let published = BorisAdapter.publishedNotes(from: notes)
        let rss = RSSFeed.xml(
            siteTitle: configuration.siteTitle,
            siteBaseURL: configuration.siteBaseURL,
            notes: published,
            now: now
        )
        let rssURL = configuration.artifactDirectory.appendingPathComponent("feed.xml")
        try Data(rss.utf8).write(to: rssURL, options: .atomic)

        let plan = CloudflareDeployer.plan(
            artifactDirectory: configuration.artifactDirectory,
            projectName: vault.cloudflareProjectName,
            accountID: vault.cloudflareAccountID,
            dryRun: true
        )
        _ = try CloudflareDeployer.writeWranglerConfig(plan: plan, artifactDirectory: configuration.artifactDirectory)

        let indexURL = configuration.artifactDirectory.appendingPathComponent("index.html")
        return PublishResult(
            artifactDirectory: configuration.artifactDirectory,
            indexURL: indexURL,
            rssURL: rssURL,
            pageCount: staged.pages.count,
            usedBorisBinary: compile.usedBorisBinary,
            compiledNoteIDs: published.map(\.id),
            compilerName: compile.compilerName
        )
    }
}
