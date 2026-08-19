# Card D-2 — Read a paragraph

**Milestone:** M8 · **Lane:** detail · **Depends:** C-1 sat · **Status:** ready — source stays king

## Handoff

- **Not started.** `.cook` already has Edit | Read. `.md` and
  `.textile` are source only. `OliverClient` already renders
  HTML after idle; nothing shows it.
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
