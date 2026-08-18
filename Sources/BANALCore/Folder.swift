import Foundation

/// A directory in the vault. The `id` is the vault-relative POSIX path.
public struct FolderNode: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var children: [FolderNode]

    public init(id: String, name: String, children: [FolderNode] = []) {
        self.id = id
        self.name = name
        self.children = children
    }

    public var urlRelativeToRoot: String { id }

    /// `nil` when there are no children so `OutlineGroup` does not show a disclosure triangle.
    public var outlineChildren: [FolderNode]? {
        children.isEmpty ? nil : children
    }

    public func contains(path: String) -> Bool {
        path == id || path.hasPrefix(id + "/")
    }
}

public enum FolderName {
    public static func sanitize(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed == "." || trimmed == ".." { return nil }
        if trimmed.contains("/") || trimmed.contains("\\") || trimmed.contains(":") { return nil }
        if trimmed.hasPrefix(".") { return nil }
        if VaultConfiguration.reservedDirectoryNames.contains(trimmed) { return nil }
        if trimmed.utf8.count > 128 { return nil }
        return trimmed
    }

    public static func uniqueSibling(base: String, existing: Set<String>) -> String {
        if !existing.contains(base) { return base }
        var n = 2
        while existing.contains("\(base) \(n)") {
            n += 1
        }
        return "\(base) \(n)"
    }
}

/// Vault-relative folder and note ids (`Essays`, `Essays/Drafts/wip`).
public enum FolderPath {
    public static func contains(_ path: String, folder: String) -> Bool {
        path == folder || path.hasPrefix(folder + "/")
    }

    /// Rewrites `path` after `old` is renamed to `new`. `nil` if `path` is not inside `old`.
    public static func remap(_ path: String, from old: String, to new: String) -> String? {
        if path == old { return new }
        if path.hasPrefix(old + "/") {
            return new + String(path.dropFirst(old.count))
        }
        return nil
    }
}

public enum FolderTree {
    /// Build a nested tree from vault-relative directory paths (`Essays`, `Essays/Drafts`).
    public static func build(paths: [String]) -> [FolderNode] {
        let sorted = paths
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }
            .filter { !$0.isEmpty }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

        class Scratch {
            var name: String
            var id: String
            var kids: [String: Scratch] = [:]
            init(name: String, id: String) {
                self.name = name
                self.id = id
            }

            func node() -> FolderNode {
                let children = kids.values
                    .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                    .map { $0.node() }
                return FolderNode(id: id, name: name, children: children)
            }
        }

        let root = Scratch(name: "", id: "")
        for path in sorted {
            var cursor = root
            var assembled: [String] = []
            for part in path.split(separator: "/").map(String.init) {
                assembled.append(part)
                let id = assembled.joined(separator: "/")
                if cursor.kids[part] == nil {
                    cursor.kids[part] = Scratch(name: part, id: id)
                }
                cursor = cursor.kids[part]!
            }
        }
        return root.node().children
    }

    public static func flatten(_ nodes: [FolderNode]) -> [FolderNode] {
        var out: [FolderNode] = []
        func walk(_ node: FolderNode) {
            out.append(node)
            node.children.forEach(walk)
        }
        nodes.forEach(walk)
        return out
    }
}

public enum NoteSort: String, Codable, CaseIterable, Sendable {
    case updated
    case created
    case title

    public var menuTitle: String {
        switch self {
        case .updated: return "Date Edited"
        case .created: return "Date Created"
        case .title: return "Title"
        }
    }
}

public enum NewNoteLocation: String, Codable, CaseIterable, Sendable {
    case selectedFolder
    case vaultRoot
    case inbox

    public var menuTitle: String {
        switch self {
        case .selectedFolder: return "Selected Folder"
        case .vaultRoot: return "Notes Folder Root"
        case .inbox: return "Inbox"
        }
    }
}

public enum LineHeightSetting: String, Codable, CaseIterable, Sendable {
    case tight
    case normal
    case loose

    public var multiplier: Double {
        switch self {
        case .tight: return 1.35
        case .normal: return 1.5
        case .loose: return 1.7
        }
    }

    public var menuTitle: String {
        rawValue.capitalized
    }
}
