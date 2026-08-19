# Card B-1 — Type

**Milestone:** M3 · **Lane:** type · **Status:** cooking — SF Pro, 680pt measure, live line height

## Handoff

- **Landed:** SF Pro body + title. No serif. 16pt default. Line height on the open buffer. 680pt centered measure. Stylesheets later.
- **Sit:** 1400px light + dark as a page, not an IDE. Serif was pulled — do not put it back.

## Owns

- `EditorView.swift`, `MarkdownTextView.swift`
- Editor fields in `AppPreferences` / Settings Editor pane
- List and sidebar fonts only if they are currently shouting

## Do not touch

- Highlighting as a syntax theme (later, whispered, different card)
- Oliver / preview HTML typography
- A custom bundled display face

## Why

This is the inhale. Type first, features second. SF Pro, not New York,
not a code editor. Stylesheets are a later card.

## Do

1. Body and chrome: SF Pro at 16pt default.
2. Title: same family, heavier, ~26pt.
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
