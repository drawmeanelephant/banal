# Card B-1 — Type

**Milestone:** M3 · **Lane:** type · **Status:** cooking — serif pairing, 680pt measure, live line height

## Handoff

- **Landed:** System serif body + title (`EditorTypography`). 16pt default. Line height applied to the open buffer, not just new typing. 680pt centered measure. System-accent selection. Settings size shows the point value.
- **Sit (this session):** 1400px light + dark. Serif title + body, 16pt, centered measure, system-accent selection. Reads as a page, not an IDE. Spell-check underline is the only chrome in the text.

## Owns

- `EditorView.swift`, `MarkdownTextView.swift`
- Editor fields in `AppPreferences` / Settings Editor pane
- List and sidebar fonts only if they are currently shouting

## Do not touch

- Highlighting as a syntax theme (later, whispered, different card)
- Oliver / preview HTML typography
- A custom bundled display face

## Why

This is the inhale. If the body type is SF at 13pt in a 2000px-wide
column, nobody cares that Cooklang parses. Notes apps are judged as
type first, features second. We steal the pairing from Apple’s
serious text (New York or system serif + SF chrome), not from VS Code.

## Do

1. Body: system serif via `fontDescriptor.withDesign(.serif)` at
   16–17pt default. Chrome and lists: SF.
2. Title: same family as body, heavier, ~26pt, not a third face.
3. Line height from preferences (`tight` 1.35 / `normal` 1.5 /
   `loose` 1.7) applied as `NSParagraphStyle.lineHeightMultiple`.
4. Measure: when “Limit line length” is on, cap the editor column
   around 66 characters (~680pt) and center it. A huge window must
   not become a lawn of text.
5. Selection color is the system accent. Text is `textColor`.
6. No ligature circus, no OpenDyslexic as default, no Fira Code.

## Do not

- Ship a theme pack.
- Color headings six different hues.
- Let the title field and the body disagree about family.

## Gate

One note, light and dark, window at 1400px wide: the column of text
looks like a book page, not an IDE. Someone who uses iA Writer does
not flinch.
