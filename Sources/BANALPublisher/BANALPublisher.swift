import Foundation
import BANALCore

/// Isolated publishing service. Local editing never calls this.
public struct BANALPublisher: Sendable {
    public var compiler: any SiteCompiling
    public var oliver: OliverClient?

    public init(compiler: any SiteCompiling = BuiltinSiteCompiler(), oliver: OliverClient? = nil) {
        self.compiler = compiler
        self.oliver = oliver
    }

    public static func make(configuration: PublishConfiguration) -> BANALPublisher {
        let oliverURL = configuration.oliverBinaryURL
            ?? OliverLocator.resolve()
        let oliver = oliverURL.map { OliverClient(binaryURL: $0) }
        if configuration.preferBoris, let binary = configuration.borisBinaryURL {
            return BANALPublisher(compiler: BorisCLICompiler(binaryURL: binary), oliver: oliver)
        }
        return BANALPublisher(compiler: BuiltinSiteCompiler(), oliver: oliver)
    }

    public func publish(
        notes: [Note],
        vault: VaultConfiguration,
        configuration: PublishConfiguration,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) throws -> PublishResult {
        let published = BorisAdapter.publishedNotes(from: notes)
        if published.isEmpty {
            throw PublishError.noPublishedNotes
        }

        var compiled: [Note] = []
        var skipped: [PublishSkip] = []
        var extras: [(page: BorisPage, html: String)] = []

        for note in published {
            if note.language == .markdown {
                compiled.append(note)
                continue
            }
            if let html = renderMarkup(note) {
                extras.append((BorisAdapter.page(from: note, among: published), html))
                compiled.append(note)
            } else {
                skipped.append(PublishSkip(noteID: note.id, language: note.language))
            }
        }

        if compiled.isEmpty {
            throw PublishError.nothingCompiled
        }

        let staged = try BorisAdapter.stage(
            notes: compiled,
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

        for extra in extras {
            let html = SiteHTML.document(
                page: extra.page,
                pages: staged.pages,
                configuration: configuration,
                bodyHTML: extra.html
            )
            try SiteHTML.write(html, entityID: extra.page.entityID, artifactDirectory: configuration.artifactDirectory, fileManager: fileManager)
        }

        let rss = RSSFeed.xml(
            siteTitle: configuration.siteTitle,
            siteBaseURL: configuration.siteBaseURL,
            notes: compiled,
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
            compiledNoteIDs: compiled.map(\.id),
            skipped: skipped,
            compilerName: compile.compilerName
        )
    }

    private func renderMarkup(_ note: Note) -> String? {
        guard let oliver else { return nil }
        let frontend = OliverFrontend(language: note.language)
        guard let html = try? oliver.render(note.body, frontend: frontend).html else { return nil }
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : html
    }
}
