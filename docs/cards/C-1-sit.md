# Card C-1 — Sit the window

**Milestone:** M7 · **Lane:** chrome · **Depends:** C-0 · **Status:** cooking — script written; GUI pass still open

## Handoff

- **Script:** [`../TESTING-WINDOW.md`](../TESTING-WINDOW.md). Code-backed
  sit fixed nested `.publish/` nav, “1 note” status grammar, and
  caret identity so a folder rename/move is not a new undo stack.
  **Nobody has sat the running window in this pass.** 30s type / ⌘Z,
  light+dark 720/1100/1400, and VoiceOver stay open. Mixed publish
  and relative nav are proven in tests. This machine’s Oliver has
  no `serialize --json`, so Read is the one-sentence path here.
- **Not this card:** Oliver path in Settings (C-2), signed `.app` (C-3),
  whispered highlighting, prose preview.

## Owns

- A sit script: [`../TESTING-WINDOW.md`](../TESTING-WINDOW.md) (write it)
- Fixes the sit hates, if they are small and already in the silhouette
- `docs/STATUS.md` “Still open” rows that the sit closes

## Do not touch

- New chrome, a fourth Settings pane, a preview column
- Sandbox / signing (C-3)
- Fluency work from B-X “maybe later”

## Why

The B cards said do not start Oliver until someone sat in the
window and did not hate it. Languages and publish landed anyway.
The north star is still the gate: five minutes, no explanation.
Compile is not QA.

## Do

1. Write `docs/TESTING-WINDOW.md` in the voice of
   [`../TESTING-NOTES-FOLDER.md`](../TESTING-NOTES-FOLDER.md).
   Cover, in one sitting:
   - First-run picker and `Documents/BANAL Notes`
   - Light + dark at 720, 1100, 1400
   - Type thirty seconds, switch notes, ⌘Z still makes sense
   - Dirty Vim keeps the buffer; clean Vim reloads
   - Empty folder, empty search, missing folder
   - New Textile, New Recipe; Finder shows three extensions
   - Open `Recipes/risotto.cook`, Read, 2×, file on disk unchanged
   - Mark two Markdown notes and the risotto published; ⇧⌘P
   - VoiceOver on the three columns
2. Sit it in the running app. Fix only what you would show a
   friend and then have to apologize for.
3. Update STATUS. If the sit invents a feature, it is a new card,
   not a drive-by.

## Do not

- “While I’m here” preview, tags filter, or stylesheets.
- Lower the quality bar because the sit is long.
- Claim the sit passed from `swift test`.

## Gate

Five minutes in the running app. If you are explaining the
window, you failed. Risotto is cookable. Publish is Export.
A longer type / ⌘Z pass in the hand is no longer an open row
unless the sit still hates the caret.
