# Card G-2 — Copy As formats

**Milestone:** M11 · **Lane:** editor · **Depends:** M8 done · **Status:** ready — Copy As Markdown, RTF, HTML

## Handoff

- **Not started.** Edit → Copy copies raw editor text. Edit → Copy As is not present in menus.
- **Not this card:** export wizard, PDF generator.

## Owns

- `Sources/BANALApp/Commands/EditCommands.swift` (Edit → Copy As submenu)
- `Sources/BANALPublisher/OliverClient.swift` / plain text converters for RTF/HTML rendering to pasteboard

## Do not touch

- Standard `⌘C` (Copy) behavior (must remain instant raw plain text copy)
- Modifying buffer text or selection

## Why

When taking notes or sharing an essay into an email, Keynote, or Slack, users need to copy the formatted text as Rich Text (RTF) or rendered HTML without losing headings and emphasis.

## Do

1. Add Edit → Copy As submenu:
   - **Copy as Markdown** (`⌥⇧⌘C`): copies raw plain text markdown (or converts selection).
   - **Copy as Rich Text** (`⌥⌘C`): renders markdown selection to formatted `public.rtf` on pasteboard.
   - **Copy as HTML**: uses Oliver to render clean HTML snippet to pasteboard.
2. If text is selected, convert only selection; if no text is selected, convert entire note.
3. Keep conversion fast and synchronous from memory.

## Do not

- Complicate standard ⌘C.
- Insert heavy inline styling sheets into the HTML/RTF clipboard data.

## Gate

Select a heading and bullet list in BANAL, choose Edit → Copy As → Rich Text, paste into Mail.app. Mail receives formatted bold heading and bulleted list. `swift test` stays green.
