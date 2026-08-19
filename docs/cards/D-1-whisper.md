# Card D-1 — Whisper the source

**Milestone:** M8 · **Lane:** editor · **Depends:** C-1 sat · **Status:** ready — hints, not a theme

## Handoff

- **Not started.** `MarkdownTextView` is plain `NSTextView`,
  `isRichText = false`, SF Pro, no attributes beyond the B-1
  paragraph style. Oliver already parses after idle; the editor
  does not show what it knows.
- **Not this card:** Markdown/Textile Read (D-2), Cooklang
  highlighting as a language pack, stylesheets, a theme toggle.

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
