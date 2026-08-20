import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

/// Abstraction for CoreSpotlight index operations, allowing unit testing with mocks.
public protocol SpotlightSearchIndex: Sendable {
    func indexSearchableItems(_ items: [CSSearchableItem]) async throws
    func deleteSearchableItems(withIdentifiers identifiers: [String]) async throws
    func deleteSearchableItems(withDomainIdentifiers domainIdentifiers: [String]) async throws
    func deleteAllSearchableItems() async throws
}

/// Production implementation of `SpotlightSearchIndex` delegating to `CSSearchableIndex`.
public final class CoreSpotlightSearchIndex: SpotlightSearchIndex, @unchecked Sendable {
    private let index: CSSearchableIndex

    public init(index: CSSearchableIndex = CSSearchableIndex.default()) {
        self.index = index
    }

    public func indexSearchableItems(_ items: [CSSearchableItem]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            index.indexSearchableItems(items) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    public func deleteSearchableItems(withIdentifiers identifiers: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            index.deleteSearchableItems(withIdentifiers: identifiers) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    public func deleteSearchableItems(withDomainIdentifiers domainIdentifiers: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            index.deleteSearchableItems(withDomainIdentifiers: domainIdentifiers) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    public func deleteAllSearchableItems() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            index.deleteAllSearchableItems { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

/// Constructs `CSSearchableItemAttributeSet` and `CSSearchableItem` for BANAL notes.
public enum NoteSpotlightItem {
    public static func attributeSet(
        for note: Note,
        vaultName: String? = nil,
        ingredients: [String] = []
    ) -> CSSearchableItemAttributeSet {
        let set = CSSearchableItemAttributeSet(contentType: .plainText)
        set.title = note.displayTitle
        set.contentDescription = note.snippet
        set.contentModificationDate = note.updated

        let container = note.folder ?? vaultName
        if let container, !container.isEmpty {
            set.containerTitle = container
        }

        var keywords: [String] = note.tags
        keywords.append(note.language.rawValue)
        keywords.append(note.language.pathExtension)
        if note.language == .cooklang {
            if !ingredients.isEmpty {
                keywords.append(contentsOf: ingredients)
            } else {
                keywords.append(contentsOf: CooklangScanner.ingredientNames(
                    in: note.body,
                    relativeTo: note.fileURL.deletingLastPathComponent()
                ))
            }
        }

        var seen = Set<String>()
        var uniqueKeywords: [String] = []
        for kw in keywords {
            let trimmed = kw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed.lowercased()).inserted {
                uniqueKeywords.append(trimmed)
            }
        }
        set.keywords = uniqueKeywords
        set.textContent = note.body
        return set
    }

    public static func makeItem(
        for note: Note,
        domainIdentifier: String = NoteSpotlightIndexer.domainIdentifier,
        vaultName: String? = nil,
        ingredients: [String] = []
    ) -> CSSearchableItem {
        let attrs = attributeSet(for: note, vaultName: vaultName, ingredients: ingredients)
        return CSSearchableItem(
            uniqueIdentifier: note.id,
            domainIdentifier: domainIdentifier,
            attributeSet: attrs
        )
    }
}

/// Asynchronous, non-blocking Spotlight indexing contract.
public protocol NoteSpotlightIndexing: Sendable {
    func index(notes: [Note], vaultName: String?, ingredients: [String: [String]])
    func deindex(ids: [String])
    func reindexAll(notes: [Note], vaultName: String?, ingredients: [String: [String]])
}

public extension NoteSpotlightIndexing {
    func index(note: Note, vaultName: String? = nil, ingredients: [String] = []) {
        index(notes: [note], vaultName: vaultName, ingredients: [note.id: ingredients])
    }

    func deindex(id: String) {
        deindex(ids: [id])
    }
}

/// Default implementation of `NoteSpotlightIndexing` using CoreSpotlight.
/// All disk indexing operations are non-blocking and performed in background tasks.
public final class NoteSpotlightIndexer: NoteSpotlightIndexing, @unchecked Sendable {
    public static let domainIdentifier = "dev.drawmeanelephant.banal.notes"
    public static let shared = NoteSpotlightIndexer()

    private let index: any SpotlightSearchIndex
    public let domainIdentifier: String

    public init(
        index: any SpotlightSearchIndex = CoreSpotlightSearchIndex(),
        domainIdentifier: String = NoteSpotlightIndexer.domainIdentifier
    ) {
        self.index = index
        self.domainIdentifier = domainIdentifier
    }

    public func index(notes: [Note], vaultName: String? = nil, ingredients: [String: [String]] = [:]) {
        guard !notes.isEmpty else { return }
        let domain = self.domainIdentifier
        let items = notes.map { note in
            NoteSpotlightItem.makeItem(
                for: note,
                domainIdentifier: domain,
                vaultName: vaultName,
                ingredients: ingredients[note.id] ?? []
            )
        }
        let index = self.index
        Task.detached(priority: .utility) {
            do {
                try await index.indexSearchableItems(items)
            } catch {
                // Spotlight index is disposable; failures are non-fatal
            }
        }
    }

    public func deindex(ids: [String]) {
        guard !ids.isEmpty else { return }
        let index = self.index
        Task.detached(priority: .utility) {
            do {
                try await index.deleteSearchableItems(withIdentifiers: ids)
            } catch {
                // Spotlight failures are non-fatal
            }
        }
    }

    public func reindexAll(notes: [Note], vaultName: String? = nil, ingredients: [String: [String]] = [:]) {
        let domain = self.domainIdentifier
        let index = self.index
        let items = notes.map { note in
            NoteSpotlightItem.makeItem(
                for: note,
                domainIdentifier: domain,
                vaultName: vaultName,
                ingredients: ingredients[note.id] ?? []
            )
        }
        Task.detached(priority: .utility) {
            do {
                try await index.deleteSearchableItems(withDomainIdentifiers: [domain])
                if !items.isEmpty {
                    try await index.indexSearchableItems(items)
                }
            } catch {
                // Spotlight failures are non-fatal
            }
        }
    }
}
