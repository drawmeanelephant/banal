# Card D-2 — Read a paragraph

**Milestone:** M8 · **Lane:** detail · **Depends:** C-1 sat · **Status:** cooking — implemented + built + unit-checked; the card's mini-sit (does it look like a page, not a browser?) is the human gate

## Handoff

- **Implemented.** Edit | Read now belongs to every note. The recipe-only
  `RecipeMode` became `ViewMode` (`viewMode` / `sessionViewMode` /
  `showsViewSwitcher` / `setViewMode`); `.md` and `.textile` get the same
  segmented Edit | Read control, View → Edit Note / Read Note menu items,
  per-session memory, and new notes open in Edit.
- `ProseReadView.swift` (new): a native, read-only `NSTextView` page that
  imports Oliver's HTML with the system importer and remaps every run onto
  B-1 type — the user's body size, weight/italic traits preserved, links
  tinted (headings read as weight, one voice, like D-1's whisper). No
  webview, no Swift CommonMark. Missing Oliver: “This note needs Oliver.”
  Pending render with Oliver configured: “Reading…”.
- `lastOliverRender` is now `@Published` so the read view updates when the
  idle render lands; the editor ignores it (a render never changes text).
- **Not this card:** whispered source (D-1), sauce walks (D-3),
  a preview column, WKWebView as the editor.

## Owns

- `Sources/BANALApp/Views/EditorView.swift` mode switcher
  expanded to Markdown and Textile
- A new small reading view (native first). Name it like
  `ProseReadView.swift` — not a second app
- Oliver HTML already produced by `OliverClient` / debounce

## Do not touch

- `MarkdownTextView` highlighting (D-1)
- Recipe Read internals (`RecipeReadView.swift`) except to
  share a measure/type helper if one already exists
- Publish staging
- A fourth Settings pane, a Preview checkbox that becomes a
  religion

## Why

A recipe may be read because dinner is kinder as a list. A
paragraph may be read because Oliver already knows the
document. Both are the same kindness: Edit is the file, Read
is secondary, the window does not grow a column.

Thesis: preview, if it ever exists, is secondary and may not
replace TextKit. This is that card. If Read wants to be the
default, tear it up.

## Do

1. `.md` / `.textile` selected → the same Edit | Read control
   recipes already use, or one shared control that says Edit /
   Read. Default **Edit**. Remember per session, per note.
2. Read draws Oliver’s document: headings, paragraphs, lists,
   emphasis. Type matches B-1 (SF, measure). Native stack or
   a read-only attributed page. Prefer no webview.
3. If you must use a webview: Oliver HTML, sandboxed,
   read-only, never first responder for typing. It is not the
   editor.
4. Missing Oliver: one sentence. Edit still works. Do not
   grow a Swift CommonMark to fake Read.
5. New notes open in Edit. Switching notes does not leave you
   trapped in someone else’s Read.
6. View menu already has Edit Recipe / Read Recipe — extend
   honestly, or one pair of items that follow the file.

## Do not

- A fourth column or a split source|preview.
- Live-updating Read on every keystroke. Idle is enough.
- CSS themes, reading-time, or “focus mode.”
- Giving `.cook` a second, different Read.

## Gate

Open an essay. Hit Read. It looks like a page, not a browser.
Hit Edit: the caret is in the Markdown. The default window is
still folders · list · page. `swift test` stays green.

**Status note (2026-08-19):** implemented and verified headlessly —
`swift test` green (94), `make smoke` green, and the running app with
Oliver configured survives open → Read with no crash (the HTML import
pipeline was also exercised directly on Oliver's real output). The
*visual* half of the gate — headings read as weight, links tinted, the
page not a browser — needs a human at the window, with a real Markdown
essay (this machine's Oliver renders oddly; that is Oliver's contract,
not this card's).
