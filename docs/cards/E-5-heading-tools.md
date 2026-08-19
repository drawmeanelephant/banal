# Card E-5 — Heading space-after & Writing Tools guard

**Milestone:** M9 · **Lane:** editor · **Depends:** M8 done · **Status:** ready — layout polish & system rewrite safety

## Handoff

- **Not started.** Headings have the same uniform line spacing as paragraphs. While system Writing Tools (macOS 15+) or dictation is active, background idle debouncers or store flushes could clobber the active text session.
- **Not this card:** syntax whisper (D-1), custom writing tools coordinator.

## Owns

- `Sources/BANALApp/Views/MarkdownTextView.swift`
- Paragraph style paragraphSpacing / spacingAfter on heading lines (`# `, `## `, `### `)
- Guarding `isWritingToolsActive` across idle timers, debounce loops, and save flushes

## Do not touch

- Stock `NSTextView` participation in Writing Tools (do NOT implement a custom `NSWritingToolsCoordinator` canvas)
- Forcing TextKit 1 (TextKit 2 is required for inline Writing Tools)
- Plain text disk representation (no rich text on disk)

## Why

A heading introduces the paragraph that follows it. Giving heading lines slightly more space *before* and a tighter hug *after* makes long essays significantly more scannable in source without converting to a preview. And when a writer uses Apple Intelligence Writing Tools or Dictation, BANAL must never replace or restyle the string out from under the system rewrite session.

## Do

1. Apply paragraph spacing metrics to heading lines:
   - Extra space before heading (`paragraphSpacingBefore`).
   - Tighter connection to the following paragraph (`paragraphSpacing`).
   - Keep standard SF Pro type and source representation.
2. In `MarkdownTextView` (and `AppModel` save routines):
   - Check `#available(macOS 15.0, *)` and `textView.isWritingToolsActive`.
   - If `isWritingToolsActive` is true, suppress background idle styling passes, text resets, and note reloads until the user accepts or cancels the Writing Tools session.
3. Ensure typing and caret navigation feel continuous.

## Do not

- Replace `textView.string` while Writing Tools is performing an inline replacement.
- Turn headings into separate rendered SwiftUI blocks or widgets.

## Gate

A document with `# Heading` followed by a paragraph has clear visual grouping. On macOS 15, invoking Writing Tools proofread cleanly replaces text without caret glitches or premature store wipes. `swift test` stays green.
