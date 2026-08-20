import AppIntents
import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

public struct NoteEntity: AppEntity, Identifiable, Sendable {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Note"
    public static let defaultQuery = NoteEntityQuery()

    public var id: String
    public var title: String
    public var folder: String?
    public var language: String

    public init(id: String, title: String, folder: String? = nil, language: String = "markdown") {
        self.id = id
        self.title = title
        self.folder = folder
        self.language = language
    }

    public init(from note: Note) {
        self.id = note.id
        self.title = note.displayTitle
        self.folder = note.folder
        self.language = note.language.rawValue
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: folder.map { "\($0)" } ?? ""
        )
    }

    public var attributeSet: CSSearchableItemAttributeSet {
        let set = CSSearchableItemAttributeSet(contentType: .plainText)
        set.title = title
        if let folder {
            set.containerTitle = folder
        }
        set.keywords = [language]
        return set
    }
}

public struct NoteEntityQuery: EntityQuery, Sendable {
    public typealias Entity = NoteEntity

    public init() {}

    public func entities(for identifiers: [NoteEntity.ID]) async throws -> [NoteEntity] {
        await MainActor.run {
            guard let store = try? IntentVaultResolver.loadStore() else { return [] }
            return store.notes.filter { identifiers.contains($0.id) }.map(NoteEntity.init(from:))
        }
    }

    public func suggestedEntities() async throws -> [NoteEntity] {
        await MainActor.run {
            guard let store = try? IntentVaultResolver.loadStore() else { return [] }
            return Array(store.notes.prefix(10)).map(NoteEntity.init(from:))
        }
    }
}
