# Card H-1 — Source checkbox toggle

**Milestone:** M12 · **Lane:** editor · **Depends:** M9 E-3 done · **Status:** landed — toggle `- [ ]` in source

## Handoff

- **Landed.** Clicking within the bounding rect or character bounds of `- [ ]` or `- [x]` at the start of a line toggles the character between ` ` and `x` directly in the text view buffer with full `⌘Z` undo support.
- **Not this card:** rendered interactive checklist widget, animated strike-throughs.

## Owns

- `Sources/BANALApp/Views/MarkdownTextView.swift` (mouse down / click intercept on `[ ]` and `[x]`)
- Unit tests for source toggling

## Do not touch

- Source-as-truth (no custom inline attachment cells)
- Plain text undo history (toggling must be an undoable character replacement)

## Why

Checking off a grocery item or a task should be as effortless as clicking the box, without switching to a rendered preview mode or turning the editor into a custom canvas.

## Do

1. Detect mouse clicks within the bounding rect of `- [ ]` or `- [x]` at the start of a line.
2. Toggle the characters between ` ` and `x` directly in the text view buffer.
3. Register the character swap with `NSUndoManager`.
4. Leave all other text and typing untouched.

## Do not

- Render custom animated checkmark graphics or checkboxes.
- Hide the `[ ]` source syntax.

## Gate

Click inside the `[ ]` of `- [ ] buy lemons`. The line becomes `- [x] buy lemons`. Press ⌘Z: it returns to `- [ ] buy lemons`. `swift test` stays green.
