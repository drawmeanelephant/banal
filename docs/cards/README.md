# Cards

Session briefs. Pick **one**. Paths are the contract — if two sessions
need the same file, stop and recut.

Read first: [`../NORTH-STAR.md`](../NORTH-STAR.md). Then
[`B-STAR.md`](B-STAR.md). Thesis and quality docs exist; they do not
outrank the North Star. These cards win on *what to do now*.

The bar is not “it works.” The bar is a window so calm people assume
Apple shipped it, and a file so fluent they cook from it or publish
it without changing apps. If a card would make the silhouette busier,
tear it up.

## Session

Branch `feat/m3-sit` off `main` (PR #1 landed). Finish-batch sit: VoiceOver, missing folder, dirty-Vim, ⌘Z.
Each card’s **Handoff** block is the note for the next person.

| Card | Status |
|------|--------|
| B-0 | cooking — sat light+dark 1100/1400/720; VoiceOver labels on the three columns |
| B-1 | cooking — sat 1400px light+dark; column reads as a page |
| B-2 | cooking — dirty-Vim keeps the buffer; style updates no longer steal ⌘Z; 30s in the hand still a human pass |
| B-3 | cooking — empty folder + empty search sat; missing-folder picker shows when the directory is gone |
| B-6 | cooking — menus sat; Find Notes focus fixed |
| B-4 / B-5 | cooking — sat; Finder rename + Publish persist; Deploy visible |
| B-7 | cooking — OliverClient + skip-if-missing tests; no preview |

## Board

| Card | Milestone | Lane | Gate |
|------|-----------|------|------|
| [B-STAR](B-STAR.md) | always | chrome | Five minutes, no explanation |
| [B-0 Silhouette](B-0-silhouette.md) | M3 | chrome | Three columns, no extra chrome, light+dark, narrow+wide |
| [B-1 Type](B-1-type.md) | M3 | type | New York / SF pairing, measure, no code-editor skin |
| [B-2 Caret](B-2-caret.md) | M3 | editor | Typing never waits; undo/find feel native |
| [B-3 Empty](B-3-empty.md) | M3 | chrome | Every empty/error state is a sentence, not a marketing page |
| [B-4 Folders](B-4-folders.md) | M1 | core+sidebar | Finder and BANAL never disagree |
| [B-5 Settings](B-5-settings.md) | M2 | settings | Three panes; Publish looks finished with Deploy disabled |
| [B-6 Menus](B-6-menus.md) | M3 | app | If it isn’t in the menu bar, it isn’t a feature |
| [B-7 Oliver](B-7-oliver.md) | M4 | publisher/engine | cooking — parse this buffer; no preview |
| [B-8 Languages](B-8-languages.md) | M5 | core+app | `.md` / `.textile` / `.cook` as files |
| [B-9 Recipe read](B-9-recipe-read.md) | M5 | detail | Cook from a reading view; source stays the file |
| [B-10 Publish](B-10-publish.md) | M6 | publisher | Export, not onboarding; graph stays in Boris |
| [B-X Refuse](B-X-refuse.md) | always | policy | The deletion list — read before every PR |

Pick in order unless the board says you may parallel. **B-4 and B-5
may run beside each other** (core folders vs Settings views). **B-0
through B-3 and B-6 are the finish batch** — do not start B-7 until
someone has sat in the running app and not hated the window.

One card = one branch = one PR. Suggested prefix `feat/b4-folders`.

## Do not start from a card

- Graph UI, backlinks, inspector
- Solipsist Compose
- Pantry / meal plan / shopping list
- AI
- Electron
- A fourth Settings pane
