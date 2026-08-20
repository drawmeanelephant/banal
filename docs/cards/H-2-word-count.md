# Card H-2 — Quiet word count

**Milestone:** M12 · **Lane:** chrome · **Depends:** M7 Close landed · **Status:** landed — subtle word count in footer

## Handoff

- **Landed.** Status strip quietly shows word and character count (e.g. "342 words · 1,840 characters") when editing a note, and reverts to vault note count (e.g. "12 notes") when no note is selected.
- **Not this card:** reading-time estimates, typing goals, daily karma HUD.

## Owns

- `Sources/BANALApp/Views/StatusStripView.swift`
- `Sources/BANALApp/Models/AppModel.swift`

## Do not touch

- Existing status strip layout metrics
- Adding modal inspectors or stats panels

## Why

Writers often have word budgets (500-word essay, 200-word blurb). A subtle word and character count in the existing status strip gives feedback without cluttering the page or demanding attention.

## Do

1. When a note is selected and being edited, update the status strip to show:
   - "342 words" or "342 words · 1,840 characters" in secondary typography.
2. Count words in memory using standard linguistic character break iterators (`NLTokenizer` or whitespace count).
3. Keep the display quiet and understated.

## Do not

- Add reading speed calculations ("4 min read"), streaks, or celebration badges.
- Grow a dedicated statistics popover.

## Gate

Type a paragraph in a note. Status strip quietly displays the word count. Delete words; the count updates. `swift test` stays green.
