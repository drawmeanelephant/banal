import Foundation

public struct WordCountStats: Equatable, Sendable {
    public var words: Int
    public var characters: Int

    public init(words: Int, characters: Int) {
        self.words = words
        self.characters = characters
    }

    public var formattedDescription: String {
        let wordPart = words == 1 ? "1 word" : "\(words.formatted()) words"
        let charPart = characters == 1 ? "1 character" : "\(characters.formatted()) characters"
        return "\(wordPart) · \(charPart)"
    }
}

public enum WordCount: Sendable {
    public static func count(in text: String) -> WordCountStats {
        var words = 0
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: [.byWords, .localized]) { _, _, _, _ in
            words += 1
        }
        return WordCountStats(words: words, characters: text.count)
    }
}
