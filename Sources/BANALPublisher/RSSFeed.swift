import Foundation
import BANALCore

public enum RSSFeed {
    public static func xml(
        siteTitle: String,
        siteBaseURL: String,
        notes: [Note],
        now: Date = Date()
    ) -> String {
        let base = siteBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        func link(for note: Note) -> String {
            let slug = BorisAdapter.entityID(for: note)
            if base.isEmpty { return "\(slug).html" }
            return "\(base)/\(slug).html"
        }
        func home() -> String {
            if base.isEmpty { return "index.html" }
            return base
        }

        var items = ""
        for note in BorisAdapter.publishedNotes(from: notes) {
            let title = XML.escape(note.displayTitle)
            let url = XML.escape(link(for: note))
            let date = RFC822.string(from: note.updated)
            let description = XML.escape(note.snippet)
            items += """
              <item>
                <title>\(title)</title>
                <link>\(url)</link>
                <guid>\(url)</guid>
                <pubDate>\(date)</pubDate>
                <description>\(description)</description>
              </item>

            """
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
          <channel>
            <title>\(XML.escape(siteTitle))</title>
            <link>\(XML.escape(home()))</link>
            <description>Published notes from BANAL</description>
            <lastBuildDate>\(RFC822.string(from: now))</lastBuildDate>
        \(items)  </channel>
        </rss>
        """
    }
}

public enum RFC822 {
    public static func string(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss '+0000'"
        return formatter.string(from: date)
    }
}

enum XML {
    static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
