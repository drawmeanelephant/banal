# Card G-2 — Copy As formats

**Milestone:** M11 · **Lane:** editor · **Depends:** M8 done · **Status:** landed — Copy As Markdown, RTF, HTML

## Handoff

- **Landed.** Edit → Copy As submenu is integrated with Copy as Markdown (`⌥⇧⌘C`), Copy as Rich Text (`⌥⌘C`), and Copy as HTML.
- Selection vs full note conversion is handled seamlessly.
- Pure in-memory synchronous conversion via `CopyAsConverter` in `BANALCore`.
- Standard `⌘C` (Copy) is untouched.
- Unit tested in `CopyAsTests.swift`.

## Owns

- `Sources/BANALApp/Commands/EditCommands.swift` (Edit → Copy As submenu)
- `Sources/BANALCore/CopyAs/` (`CopyAsConverter.swift`, `CopyAsFormat.swift`, `CopyAsPayload.swift`)

## Do not touch

- Standard `⌘C` (Copy) behavior (must remain instant raw plain text copy)
- Modifying buffer text or selection

## Why

When taking notes or sharing an essay into an email, Keynote, or Slack, users need to copy the formatted text as Rich Text (RTF) or rendered HTML without losing headings and emphasis.

## Do

1. Add Edit → Copy As submenu:
   - **Copy as Markdown** (`⌥⇧⌘C`): copies raw plain text markdown (or converts selection).
   - **Copy as Rich Text** (`⌥⌘C`): renders markdown selection to formatted `public.rtf` on pasteboard.
   - **Copy as HTML**: renders clean HTML markup to `public.html` + `public.utf8-plain-text` on pasteboard.
2. If text is selected, convert only selection; if no text is selected, convert entire note.
3. Keep conversion fast and synchronous from memory.

## Do not

- Complicate standard ⌘C.
- Insert heavy inline styling sheets into the HTML/RTF clipboard data.

## Gate

Select a heading and bullet list in BANAL, choose Edit → Copy As → Rich Text, paste into Mail.app. Mail receives formatted bold heading and bulleted list. `swift test` stays green.
