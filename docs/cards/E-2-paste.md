# Card E-2 — Smart paste and links

**Milestone:** M9 · **Lane:** editor · **Depends:** M8 done · **Status:** landed — clean paste from the web & URLs

## Handoff

- **Landed.** Pasting a URL over selected text creates `[selectedText](url)` with caret right after `)`.
- Pasting rich text or HTML converts cleanly to Markdown (headings, bold, italic, links, lists, code blocks, blockquotes) while stripping spans, styles, divs, and classes via `HTMLToMarkdown` in `BANALCore`.
- Full undo support with `⌘Z`.
- **Not this card:** list indentation (E-3), images (G-1).

## Owns

- `Sources/BANALApp/Views/MarkdownTextView.swift` (paste handling / `readSelection(from:pasteboard:type:)`)
- `Sources/BANALPublisher/OliverClient.swift` if calling Oliver for HTML → Markdown conversion
- Tests for URL wrapping and clean markdown paste

## Do not touch

- `isRichText = false` (must stay plain text `NSTextView`)
- Automatic conversion of entire files or rewriting disk files on paste
- Adding custom parser frameworks or third-party web scraper libraries

## Why

Writers collect quotes and references from Safari, PDFs, and mail. Dropping text into BANAL should give clean, readable source without HTML spans, font declarations, or proprietary styles. Pasting a URL over a title should make a markdown link in one stroke.

## Do

1. **Paste URL over selection:**
   - When text is selected in the editor and the pasteboard contains a valid URL string (`http://` or `https://`), paste becomes `[selectedText](url)`.
   - Caret lands right after the closing parenthesis `)`.
2. **Paste rich text / HTML from web / PDF:**
   - Detect `public.html` or `public.rtf` on NSPasteboard.
   - Clean the text into plain Markdown (headings `#`, lists `- `, bold `**`, italic `*`, links `[text](url)`).
   - Prefer asking Oliver (or a compact standard converter) to convert HTML to Markdown. Strip `span`, `div`, inline colors, backgrounds, and custom fonts.
   - Fall back gracefully to plain text string if HTML parser is unavailable.
3. Keep undo intact (`⌘Z` cleanly restores the pre-paste selection and text).

## Do not

- Retain inline CSS styles, font families, or background color tags.
- Block the main typing thread on heavy subprocesses.
- Grow a massive custom CommonMark AST library.

## Gate

Select the word "Apple" in a note, copy `https://apple.com`, and press ⌘V. Result is `[Apple](https://apple.com)`. Copy a rich paragraph with bold text from Safari and press ⌘V: clean Markdown with `**bold**` lands with no `<span>` tags. `swift test` stays green.
