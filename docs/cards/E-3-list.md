# Card E-3 — List continuation & breakout

**Milestone:** M9 · **Lane:** editor · **Depends:** M8 done · **Status:** ready — natural list typing

## Handoff

- **Not started.** Pressing Return on a bullet or numbered list line simply starts a fresh blank line without a bullet.
- **Not this card:** syntax whisper (D-1), checkboxes in source (H-1).

## Owns

- `Sources/BANALApp/Views/MarkdownTextView.swift` (key event interception / `insertNewline(_:)`)
- Unit / UI tests for list behaviors

## Do not touch

- Rich text / `NSAttributedString` storage modifications
- Tab key behavior inside code blocks or indented code
- Custom list bullet glyph rendering (stays source `- `, `* `, `1. `)

## Why

Writing a list or a sequence of steps is the most common note activity. Return should continue the list; hitting Return on an empty bullet line should cleanly remove the bullet and start a standard paragraph without backspacing.

## Do

1. When cursor is on a line starting with a bullet marker (`- `, `* `, `+ `, or `- [ ] `):
   - If line contains content: pressing `Return` inserts a newline with the same bullet prefix (`- ` or `- [ ] `).
   - If line contains *only* the bullet prefix: pressing `Return` deletes the bullet prefix and leaves an empty line (breakout).
2. When cursor is on an ordered list line (`1. `, `2. `):
   - If line contains content: pressing `Return` inserts a newline with the incremented number (`2. `, `3. `).
   - If line contains *only* the number prefix: pressing `Return` deletes the number prefix and leaves an empty line.
3. Respect indentation: if the bullet is indented (e.g. `  - `), preserve the indent level on continuation.
4. `⌘Z` (Undo) immediately undoes the auto-inserted bullet cleanly in one step.

## Do not

- Interfere with `Shift+Return` (soft break / plain newline without bullet).
- Auto-continue lists inside code fences (```) or verbatim blocks.
- Grow a complex outliner data model.

## Gate

Type `- First item`, hit Return. Next line begins `- `. Hit Return again immediately. Next line is empty with caret at column 0. `swift test` stays green.
