# Card D-1 — Whisper the source

**Milestone:** M8 · **Lane:** editor · **Depends:** C-1 sat · **Status:** cooking — implemented + unit-tested; the card's mini-sit is the remaining human gate

## Handoff

- **Implemented.** `MarkdownTextView` now marks headings and
  sigils as layout-manager temporary attributes (~0.4s after
  idle, skipped while Writing Tools is active) via
  `WhisperScan` in `BANALCore` (unit-tested, UTF-16-safe).
  The storage string, undo, and Find stay character-based;
  `isRichText` is still `false`.
- **Remaining:** the card's own mini-sit — type a heading and a
  risotto step, the page still looks like B-1, ⌘Z after thirty
  seconds is sane. If it shouts, delete colors until only
  weight remains.
- **Not this card:** Markdown/Textile Read (D-2), Cooklang
  highlighting as a language pack, stylesheets, a theme toggle.

## Touch-list (scouted against current code — do not start until C-1 sat)

Editor today: `MarkdownTextView.swift` (~183 lines), plain `NSTextView`,
`isRichText = false`, SF Pro. `apply(style:)` writes font/color/paragraph
and **flattens the whole storage** on style change
(`storage.addAttributes` over `0..<length`). No temporary attributes, no
highlighting, no `isWritingToolsActive` anywhere. `EditorStyle` carries
only size / line-height / spell / smart-quotes. Oliver idle lives in
`AppModel.scheduleOliverQuestion` — view-layer only, untouched by this card.

Minimal path:

1. **Layer: layout-manager temporary attributes**
   (`layoutManager.addTemporaryAttributes`). Display-only, so the storage
   string, undo, and ⇧⌘F stay character-based, and the storage flatten in
   `apply(style:)` cannot wipe the marks. Spike first: confirm temporary
   attributes render with `isRichText = false`; if not, re-apply after
   idle on storage instead. Never `isRichText = true`.
2. **Trigger: a debounce like Oliver’s, in the view layer.** ~0.4s after
   `textDidChange` (coalescing), never inside it. Clear marks on
   `documentChanged` (note switch). Skip the pass while
   `isWritingToolsActive` — do not restyle under the system rewrite.
   No `AppModel` changes.
3. **Ordering:** run the pass after `apply(style:)`, and again when
   `EditorStyle` changes, so whisper survives the flatten.
4. **Scanner: local, no subprocess, no CommonMark/TextMate.** A tiny
   pure line/pattern scanner (suggest a `WhisperScan` type beside the
   view — unit-testable). Mark:
   - Markdown: `^#{1,6} ` headings, `**`/`*`/`_` emphasis, `[label](url)`
   - Textile: `^h[1-6]. ` headings, `*`/`_` emphasis, `"label":url`
   - Cooklang: `@…{…}` ingredients, `#…{…}` cookware, `~…{…}` timers,
     `>> ` metadata lines
5. **Style: one voice, same metrics.** Weight for headings,
   `secondaryLabelColor` / ~30%-opacity markers for sigils. Same font
   metrics. If it shouts, delete colors until only weight remains.
6. **Tests:** scanner unit tests (ranges per language; no false marks
   inside code spans or `>>>`); a guard that the pass never mutates the
   storage string. The D-1 gate is its own mini-sit: a heading + a
   risotto step, still looks like B-1, ⌘Z after thirty seconds sane,
   `swift test` green.

D-2 must not restyle `RecipeReadView` and D-3 must not restyle
`MarkdownTextView` — this card owns the view file and nothing else.

## Owns

- `Sources/BANALApp/Views/MarkdownTextView.swift`
- Temporary attributes or a layout-manager pass only
- Tests that typing / undo still replace characters, not spans

## Do not touch

- `isRichText = true`
- `NSWritingToolsCoordinator` (stock `NSTextView` already participates; a coordinator is for a custom canvas)
- Forcing TextKit 1
- Recipe Read layout (`RecipeReadView.swift`)
- Editor Settings (no Highlighting checkbox)
- Solipsist Compose, a Swift CommonMark, Rainbow tokens

## Why

The editor is a page, not a textarea and not an IDE. Headings,
emphasis, and Cooklang sigils should read as *hints* so a
human sees the shape of the file without leaving source.
QUALITY already forbade a syntax theme. This card is that
whisper, or it is a delete.

## Do

1. After idle (same spirit as Oliver’s debounce — not on the
   caret path), mark:
   - Markdown/Textile: headings, emphasis, links
   - Cooklang: `@` ingredients, `#` cookware, `~` timers, `>>`
     metadata
2. Hints use weight, a touch of `secondaryLabelColor`, or
   markers at ~30% opacity in the *same* metrics as the text —
   one voice, both appearances. Not six hues. Not a Fira Code
   skin. Markers stay visible. If they vanish, you hid syntax.
3. The string in the view is still the file. Undo is still
   characters. Find in note (⇧⌘F) still works. If
   `isWritingToolsActive`, do not restyle or replace `string`
   out from under the system rewrite.
4. Missing Oliver: hint from the bytes you already have. Do
   not block typing on a subprocess.
5. Light and dark, 720 and 1400. If it shouts, delete colors
   until only weight remains.

## Do not

- Color every token.
- Run a highlighter inside `textDidChange` without coalescing.
- Add “Syntax highlighting” to Settings. If it needs a switch,
   it is too loud.
- Copy Compose or vendor a TextMate grammar.

## Gate

Type a heading and a risotto step. The page still looks like
B-1. Someone who uses iA Writer does not flinch. ⌘Z after
thirty seconds still makes sense. `swift test` stays green.
