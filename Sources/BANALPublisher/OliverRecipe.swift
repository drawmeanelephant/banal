import Foundation

/// Display scale for a recipe reading view. Applied by Oliver, never
/// written back to the `.cook` file.
public enum RecipeScale: String, CaseIterable, Equatable, Sendable, Identifiable {
    case half
    case one
    case two
    case three

    public var id: String { rawValue }

    /// Argument to `oliver scale --factor`.
    public var factorArgument: String {
        switch self {
        case .half: return "1/2"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        }
    }

    public var label: String {
        switch self {
        case .half: return "½"
        case .one: return "1×"
        case .two: return "2×"
        case .three: return "3×"
        }
    }
}

/// Oliver's typed Recipe as dumped by `serialize --from cooklang --json`.
///
/// Sections are flattened: a section header is followed by its steps and
/// notes at the same level. Recipe references (`@./path`) arrive as text.
public struct OliverRecipe: Equatable, Sendable, Decodable {
    public var blocks: [OliverRecipeBlock]

    public init(blocks: [OliverRecipeBlock]) {
        self.blocks = blocks
    }

    public static func decode(from json: String) throws -> OliverRecipe {
        try JSONDecoder().decode(OliverRecipe.self, from: Data(json.utf8))
    }

    /// First-seen ingredients, case-sensitive names, first quantity/units/prep.
    public var ingredientIndex: [RecipeIndexItem] {
        var seen = Set<String>()
        var items: [RecipeIndexItem] = []
        for part in stepParts {
            guard case .ingredient(let ingredient) = part else { continue }
            if seen.contains(ingredient.name) { continue }
            seen.insert(ingredient.name)
            items.append(
                RecipeIndexItem(
                    name: ingredient.name,
                    quantity: ingredient.displayQuantity,
                    units: ingredient.displayUnits,
                    preparation: ingredient.displayPreparation
                )
            )
        }
        return items
    }

    /// First-seen cookware names.
    public var cookwareIndex: [RecipeIndexItem] {
        var seen = Set<String>()
        var items: [RecipeIndexItem] = []
        for part in stepParts {
            guard case .cookware(let cookware) = part else { continue }
            if seen.contains(cookware.name) { continue }
            seen.insert(cookware.name)
            items.append(RecipeIndexItem(name: cookware.name))
        }
        return items
    }

    private var stepParts: [OliverRecipePart] {
        blocks.flatMap { block -> [OliverRecipePart] in
            if case .step(let parts) = block { return parts }
            return []
        }
    }
}

public struct RecipeIndexItem: Equatable, Sendable {
    public var name: String
    public var quantity: String?
    public var units: String?
    public var preparation: String?

    public init(name: String, quantity: String? = nil, units: String? = nil, preparation: String? = nil) {
        self.name = name
        self.quantity = quantity
        self.units = units
        self.preparation = preparation
    }

    public var amountText: String? {
        Self.amountText(quantity: quantity, units: units)
    }

    public var displayLine: String {
        var line = ""
        if let amount = amountText {
            line.append(amount)
            line.append(" ")
        }
        line.append(name)
        if let preparation, !preparation.isEmpty {
            line.append(" (")
            line.append(preparation)
            line.append(")")
        }
        return line
    }

    static func amountText(quantity: String?, units: String?) -> String? {
        let q = quantity?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let u = units?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if q.isEmpty, u.isEmpty { return nil }
        if u.isEmpty { return q }
        if q.isEmpty { return u }
        return "\(q) \(u)"
    }
}

public enum OliverRecipeBlock: Equatable, Sendable {
    case step([OliverRecipePart])
    case section(String)
    case note(String)
}

public enum OliverRecipePart: Equatable, Sendable {
    case text(String)
    case ingredient(OliverIngredient)
    case cookware(OliverCookware)
    case timer(OliverTimer)
    case lineBreak

    public var inlineText: String {
        switch self {
        case .text(let text):
            return text
        case .ingredient(let ingredient):
            return ingredient.inlineText
        case .cookware(let cookware):
            return cookware.name
        case .timer(let timer):
            return timer.inlineText
        case .lineBreak:
            return "\n"
        }
    }
}

public struct OliverIngredient: Equatable, Sendable {
    public var name: String
    public var quantity: String?
    public var units: String?
    public var preparation: String?

    public init(name: String, quantity: String? = nil, units: String? = nil, preparation: String? = nil) {
        self.name = name
        self.quantity = quantity
        self.units = units
        self.preparation = preparation
    }

    public var displayQuantity: String? { nilIfEmpty(quantity) }
    public var displayUnits: String? { nilIfEmpty(units) }
    public var displayPreparation: String? { nilIfEmpty(preparation) }

    public var inlineText: String {
        var text = ""
        if let amount = RecipeIndexItem.amountText(quantity: quantity, units: units) {
            text.append(amount)
            text.append(" ")
        }
        text.append(name)
        if let preparation = displayPreparation {
            text.append(" (")
            text.append(preparation)
            text.append(")")
        }
        return text
    }
}

public struct OliverCookware: Equatable, Sendable {
    public var name: String
    public var quantity: String?

    public init(name: String, quantity: String? = nil) {
        self.name = name
        self.quantity = quantity
    }
}

public struct OliverTimer: Equatable, Sendable {
    public var name: String
    public var quantity: String?
    public var units: String?

    public init(name: String, quantity: String? = nil, units: String? = nil) {
        self.name = name
        self.quantity = quantity
        self.units = units
    }

    public var inlineText: String {
        if let amount = RecipeIndexItem.amountText(quantity: quantity, units: units) {
            if name.isEmpty { return amount }
            return "\(amount) \(name)"
        }
        return name
    }
}

extension OliverRecipeBlock: Decodable {
    private enum CodingKeys: String, CodingKey {
        case kind, parts, name, text
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "step":
            self = .step(try container.decode([OliverRecipePart].self, forKey: .parts))
        case "section":
            self = .section(try container.decode(String.self, forKey: .name))
        case "note":
            self = .note(try container.decode(String.self, forKey: .text))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "unknown recipe block kind \(kind)"
            )
        }
    }
}

extension OliverRecipePart: Decodable {
    private enum CodingKeys: String, CodingKey {
        case kind, text, name, quantity, units, preparation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "text":
            self = .text(try container.decode(String.self, forKey: .text))
        case "ingredient":
            self = .ingredient(
                OliverIngredient(
                    name: try container.decode(String.self, forKey: .name),
                    quantity: try container.decodeIfPresent(String.self, forKey: .quantity),
                    units: try container.decodeIfPresent(String.self, forKey: .units),
                    preparation: try container.decodeIfPresent(String.self, forKey: .preparation)
                )
            )
        case "cookware":
            self = .cookware(
                OliverCookware(
                    name: try container.decode(String.self, forKey: .name),
                    quantity: try container.decodeIfPresent(String.self, forKey: .quantity)
                )
            )
        case "timer":
            self = .timer(
                OliverTimer(
                    name: try container.decodeIfPresent(String.self, forKey: .name) ?? "",
                    quantity: try container.decodeIfPresent(String.self, forKey: .quantity),
                    units: try container.decodeIfPresent(String.self, forKey: .units)
                )
            )
        case "line_break":
            self = .lineBreak
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "unknown recipe part kind \(kind)"
            )
        }
    }
}

private func nilIfEmpty(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
