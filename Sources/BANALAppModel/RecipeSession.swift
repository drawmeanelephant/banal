import BANALCore
import BANALPublisher
import Combine
import Foundation

/// What a recipe session needs to know about the app around it. Narrow on
/// purpose: the coordinator implements this in a few lines, tests fake it.
@MainActor
public protocol RecipeContext: AnyObject {
    var store: NoteStore { get }
    var selectedID: String? { get }
    var selectedNote: Note? { get }
    var viewMode: ViewMode { get }
    /// The current editor buffer text (the source recipes are asked about).
    var bufferText: String { get }
    func cacheIngredients(_ names: [String], forNoteID noteID: String)
    func showStatus(_ message: String)
}

/// Oliver integration for the open buffer: idle prose renders, recipe
/// asks (Read mode), ingredient-cache warming, scaled copies, and
/// Textile conversion. Owns the Oliver binaries' resolution so typing
/// never waits on a process.
@MainActor
public final class RecipeSession: ObservableObject {
    @Published public var recipeScale: RecipeScale = .one
    @Published public var oliverRecipe: OliverRecipe?
    @Published public var recipeError: String?
    /// One-sentence sauce problems from inlining (D-3): missing sauce,
    /// a cycle, too many levels. Non-fatal — the recipe still reads.
    @Published public var recipeIssues: [String] = []
    /// Last Oliver HTML for the open buffer. Published so the prose Read
    /// view (D-2) updates when the idle render lands; the editor itself
    /// ignores it (a render never changes the text).
    @Published public private(set) var lastOliverRender: OliverRender?

    private var oliverClient: OliverClient?
    private var oliver: OliverDebounce
    private let recipeQueue = DispatchQueue(label: "dev.drawmeanelephant.banal.recipe", qos: .userInitiated)
    private var generation = 0

    public init() {
        oliverClient = nil
        oliver = OliverDebounce(client: nil)
    }

    /// Whether a render binary is configured — distinguishes the prose
    /// Read view's "Reading…" from "This note needs Oliver."
    public var canRender: Bool {
        oliver.isAvailable
    }

    // MARK: - Binary resolution

    /// Honor the notes folder's Oliver path without a relaunch.
    public func refreshOliver(configured: String?) {
        _ = CompilerBookmark.access(path: configured, name: "oliver")
        recipeQueue.async { [weak self] in
            // Recipe Read needs `serialize --json`; a render-only Oliver is
            // not enough, so Read says "This recipe needs Oliver." Idle
            // render keeps the plain fallback — older binaries still render.
            let recipeURL = OliverLocator.resolveRecipeJSON(configured: configured)
            let renderURL = recipeURL ?? OliverLocator.resolve(configured: configured)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.oliverClient = recipeURL.map { OliverClient(binaryURL: $0) }
                self.oliver = renderURL.map { OliverDebounce(client: OliverClient(binaryURL: $0)) }
                    ?? OliverDebounce(client: nil)
                if let context = self.context, context.viewMode == .read, context.selectedNote?.language == .cooklang {
                    self.askOliverForRecipe()
                }
                if let client = self.oliverClient {
                    self.warmIngredientCaches(with: client)
                }
            }
        }
    }

    public weak var context: RecipeContext?

    // MARK: - Idle prose render + open-note ingredients

    /// Ask Oliver what this buffer is, after idle. Missing binary is
    /// silent. The process runs off the main queue so typing never waits.
    public func scheduleIdleRender() {
        guard let context else { return }
        guard oliver.isAvailable else {
            lastOliverRender = nil
            return
        }
        let noteID = context.selectedID
        let frontend = OliverFrontend(language: context.selectedNote?.language ?? .markdown)
        oliver.schedule(source: context.bufferText, frontend: frontend) { [weak self] render in
            Task { @MainActor [weak self] in
                guard let self, let context = self.context, context.selectedID == noteID else { return }
                self.lastOliverRender = render
            }
        }
        if context.selectedNote?.language == .cooklang, let client = oliverClient, let note = context.selectedNote {
            let source = context.bufferText
            let directory = note.fileURL.deletingLastPathComponent()
            let targetID = note.id
            recipeQueue.async { [weak self] in
                let inlined = RecipeInliner.inline(
                    source: source,
                    relativeTo: directory,
                    scaler: { try client.scaleSource($0, percent: $1) }
                )
                if let recipe = try? client.recipe(inlined.source, scale: .one) {
                    let names = recipe.ingredientIndex.map(\.name)
                    Task { @MainActor [weak self] in
                        guard let self, self.context != nil else { return }
                        self.context?.cacheIngredients(names, forNoteID: targetID)
                    }
                }
            }
        }
    }

    /// Prime the store's ingredient cache for every `.cook` note in the
    /// vault, off the main queue.
    public func warmIngredientCaches(with client: OliverClient) {
        guard let context else { return }
        let cookNotes = context.store.notes.filter { $0.language == .cooklang }
        recipeQueue.async { [weak self] in
            for note in cookNotes {
                let directory = note.fileURL.deletingLastPathComponent()
                let inlined = RecipeInliner.inline(
                    source: note.body,
                    relativeTo: directory,
                    scaler: { try client.scaleSource($0, percent: $1) }
                )
                if let recipe = try? client.recipe(inlined.source, scale: .one) {
                    let names = recipe.ingredientIndex.map(\.name)
                    Task { @MainActor [weak self] in
                        self?.context?.cacheIngredients(names, forNoteID: note.id)
                    }
                }
            }
        }
    }

    // MARK: - Recipe asks (Read mode)

    public func askOliverForRecipe() {
        guard let context else { return }
        guard context.viewMode == .read, context.selectedNote?.language == .cooklang else {
            clearRecipe()
            return
        }
        guard let client = oliverClient else {
            oliverRecipe = nil
            recipeError = "This recipe needs Oliver."
            recipeIssues = []
            return
        }
        generation += 1
        let currentGeneration = generation
        let source = context.bufferText
        let directory = context.selectedNote?.fileURL.deletingLastPathComponent()
        let scale = recipeScale
        let noteID = context.selectedID
        let apply: @Sendable (Result<OliverRecipe, Error>, [String]) -> Void = { [weak self] result, issues in
            Task { @MainActor in
                guard let self else { return }
                guard let context = self.context,
                      currentGeneration == self.generation,
                      context.viewMode == .read,
                      context.selectedID == noteID else { return }
                switch result {
                case .success(let recipe):
                    self.oliverRecipe = recipe
                    self.recipeError = nil
                    self.recipeIssues = issues
                    if let noteID {
                        context.cacheIngredients(recipe.ingredientIndex.map(\.name), forNoteID: noteID)
                    }
                case .failure:
                    self.oliverRecipe = nil
                    self.recipeError = "This recipe didn't parse."
                    self.recipeIssues = issues
                }
            }
        }
        recipeQueue.async { [client, directory] in
            do {
                // D-3: walk `@./path{scale}` refs before Oliver sees the
                // source — a path walk, never a rewrite of the file.
                let inlined = directory.map {
                    RecipeInliner.inline(
                        source: source,
                        relativeTo: $0,
                        scaler: { try client.scaleSource($0, percent: $1) }
                    )
                }
                let recipe = try client.recipe(inlined?.source ?? source, scale: scale)
                apply(.success(recipe), inlined?.issues ?? [])
            } catch {
                apply(.failure(error), [])
            }
        }
    }

    public func cancelRecipeAsk() {
        generation += 1
    }

    public func clearRecipe() {
        oliverRecipe = nil
        recipeError = nil
        recipeIssues = []
    }

    // MARK: - Save Scaled Copy

    /// Write a scaled copy of the recipe to disk. The original is never
    /// mutated; the copy lands as `<title> (<scale>).<ext>` beside it.
    /// Returns the new file URL for the coordinator to select once the
    /// monitor has seen it, or nil when nothing was written.
    @discardableResult
    public func saveScaledCopy(of note: Note) -> URL? {
        guard note.language == .cooklang, recipeScale != .one else { return nil }
        guard let client = oliverClient else {
            context?.showStatus("Oliver is not installed.")
            return nil
        }
        let source = note.body
        let directory = note.fileURL.deletingLastPathComponent()
        let scaled: String
        do {
            let inlined = RecipeInliner.inline(
                source: source,
                relativeTo: directory,
                scaler: { try client.scaleSource($0, percent: $1) }
            )
            scaled = try client.scaleSource(inlined.source, percent: recipeScale.percent)
        } catch {
            context?.showStatus("Scale failed: \(error.localizedDescription)")
            return nil
        }
        let baseName = note.fileURL.deletingPathExtension().lastPathComponent
        let ext = note.fileURL.pathExtension
        let scaleLabel = recipeScale.label
        let newURL = directory.appendingPathComponent("\(baseName) (\(scaleLabel)).\(ext)")
        do {
            try Data(scaled.utf8).write(to: newURL, options: .atomic)
            context?.showStatus("Saved scaled copy: \(newURL.lastPathComponent)")
            return newURL
        } catch {
            context?.showStatus("Save failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Convert Textile to Markdown

    /// Convert a `.textile` note to `.md` via Oliver + HTMLToMarkdown.
    /// The original is moved to Trash. Only on explicit user request.
    /// Returns the new Markdown URL for the coordinator to select.
    @discardableResult
    public func convertTextileToMarkdown(of note: Note) -> URL? {
        guard note.language == .textile else { return nil }
        guard let client = oliverClient else {
            context?.showStatus("Oliver is not installed.")
            return nil
        }
        let html: String
        do {
            html = try client.render(note.body, frontend: .textile).html
        } catch {
            context?.showStatus("Textile render failed: \(error.localizedDescription)")
            return nil
        }
        let markdown = HTMLToMarkdown.convert(html)
        let directory = note.fileURL.deletingLastPathComponent()
        let stem = note.fileURL.deletingPathExtension().lastPathComponent
        let newURL = directory.appendingPathComponent("\(stem).md")
        do {
            // Write the new .md file
            try Data(markdown.utf8).write(to: newURL, options: .atomic)
            // Move the original .textile to Trash
            let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first
                ?? directory.appendingPathComponent(".trash")
            try FileManager.default.createDirectory(at: trashURL, withIntermediateDirectories: true)
            let trashedURL = trashURL.appendingPathComponent(note.fileURL.lastPathComponent)
            // Handle name collision in trash
            var finalTrashURL = trashedURL
            var suffix = 2
            while FileManager.default.fileExists(atPath: finalTrashURL.path) {
                finalTrashURL = trashURL.appendingPathComponent("\(stem)-\(suffix).textile")
                suffix += 1
            }
            try FileManager.default.moveItem(at: note.fileURL, to: finalTrashURL)
            context?.showStatus("Converted \(stem).textile to \(stem).md")
            return newURL
        } catch {
            context?.showStatus("Conversion failed: \(error.localizedDescription)")
            return nil
        }
    }
}
