import AppKit
import Foundation
import BANALCore

/// The sdef's `<cocoa class>` mappings point here. Cocoa scripting routes each
/// Apple event to its `NSScriptCommand` subclass; the verbs themselves live in
/// `NoteScripting`.
///
/// Results go back as text: JSON for note records (agents read it natively),
/// a sentence for `publish site`. Native dictionary-to-record conversion
/// turned out to drop replies on the floor (`_populateReplyAppleEvent…` cannot
/// turn arbitrary string-keyed dictionaries into descriptors).
@objc(ScriptingEventHandlers)
public final class ScriptingEventHandlers: NSObject {
    /// Referenced by `ScriptingBootstrap` so release-build dead stripping
    /// keeps the command classes' Objective-C registrations alive.
    public static func keepAlive() {}
}

@objc(ListNotesScriptCommand)
public final class ListNotesScriptCommand: NSScriptCommand {
    override public func performDefaultImplementation() -> Any? {
        Scripting.run(self) { try Scripting.jsonString(NoteScripting.listNotes()) }
    }
}

@objc(ReadNoteScriptCommand)
public final class ReadNoteScriptCommand: NSScriptCommand {
    override public func performDefaultImplementation() -> Any? {
        guard let id = Scripting.directID(self, verb: "read note") else { return nil }
        return Scripting.run(self) { try Scripting.jsonString(NoteScripting.readNote(id: id)) }
    }
}

@objc(CreateNoteScriptCommand)
public final class CreateNoteScriptCommand: NSScriptCommand {
    override public func performDefaultImplementation() -> Any? {
        let arguments = evaluatedArguments
        let title = arguments?["title"] as? String
        let body = arguments?["body"] as? String
        let folder = arguments?["folder"] as? String
        let language = arguments?["language"] as? String
        let published = (arguments?["published"] as? Bool) ?? false
        return Scripting.run(self) {
            try Scripting.jsonString(NoteScripting.createNote(
                title: title,
                body: body,
                folder: folder,
                language: language,
                published: published
            ))
        }
    }
}

@objc(UpdateNoteBodyScriptCommand)
public final class UpdateNoteBodyScriptCommand: NSScriptCommand {
    override public func performDefaultImplementation() -> Any? {
        guard let id = Scripting.directID(self, verb: "update note") else { return nil }
        guard let body = evaluatedArguments?["body"] as? String else {
            scriptErrorString = "update note needs a body."
            return nil
        }
        return Scripting.run(self) { try Scripting.jsonString(NoteScripting.updateNoteBody(id: id, body: body)) }
    }
}

@objc(SetPublishedScriptCommand)
public final class SetPublishedScriptCommand: NSScriptCommand {
    override public func performDefaultImplementation() -> Any? {
        guard let id = Scripting.directID(self, verb: "set published") else { return nil }
        guard let published = evaluatedArguments?["to"] as? Bool else {
            scriptErrorString = "set published takes true or false."
            return nil
        }
        return Scripting.run(self) { try Scripting.jsonString(NoteScripting.setPublished(published, id: id)) }
    }
}

@objc(PublishSiteScriptCommand)
public final class PublishSiteScriptCommand: NSScriptCommand {
    override public func performDefaultImplementation() -> Any? {
        Scripting.run(self) { try NoteScripting.publishSite() }
    }
}

/// Shared plumbing for the command classes.
enum Scripting {
    static func run(_ command: NSScriptCommand, _ body: @MainActor () throws -> String) -> Any? {
        do {
            return try MainActor.assumeIsolated(body)
        } catch {
            command.scriptErrorString = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            return nil
        }
    }

    static func directID(_ command: NSScriptCommand, verb: String) -> String? {
        guard let id = command.directParameter as? String, !id.isEmpty else {
            command.scriptErrorString = "\(verb) needs a note id."
            return nil
        }
        return id
    }

    static func jsonString(_ object: [[String: Any]]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    static func jsonString(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }
}
