# Cards

Session briefs. Pick **one**. Paths are the contract — if two sessions
need the same file, stop and recut.

Read first: [`../NORTH-STAR.md`](../NORTH-STAR.md). Then
[`B-STAR.md`](B-STAR.md) and [`B-X-refuse.md`](B-X-refuse.md). Thesis
and quality docs exist; they do not outrank the North Star. These
cards win on *what to do now*.

The bar is not “it works.” The bar is a window so calm people assume
Apple shipped it, and a file so fluent they cook from it or publish
it without changing apps. If a card would make the silhouette busier,
tear it up.

## Session

Branch `docs/d0-board` (D-0). Next session is a human window sit
([`TESTING-WINDOW.md`](../TESTING-WINDOW.md)), including the signed
`.app` from C-3, or D-1 after that sit. **Do not start D-1 from
compile.**

Each card’s **Handoff** block is the note for the next person.

| Card | Status |
|------|--------|
| D-0 | landed — C Close archived; this README is the D board |
| D-1 | cooking — whisper implemented + unit-tested; card mini-sit open |
| D-2 | ready — waits for C-1 sat |
| D-3 | ready — waits for C-1 sat |
| D-4 | ready — waits for C-1 sat |
| C-1 | cooking — script + code-backed sit; GUI pass still open |
| C-2 | landed — Oliver/Boris paths, About, speakable copy |
| C-3 | landed — ad-hoc signed `.app` + sandbox |

## Board — Fluency

B cards drew the silhouette. C cards sit, delete, and ship. D cards
deepen the *file* without changing the window. Do not start D-1
until C-1 has been sat. If the sit hates the caret or publish feels
like onboarding, that bug outranks every D card.

| Card | Milestone | Lane | Gate |
|------|-----------|------|------|
| [B-STAR](B-STAR.md) | always | chrome | Five minutes, no explanation |
| [B-X Refuse](B-X-refuse.md) | always | policy | The deletion list — read before every PR |
| [D-0 Board](D-0-board.md) | M8 | docs | The board tells the truth about fluency |
| [D-1 Whisper](D-1-whisper.md) | M8 | editor | Headings and sigils are hints; not a theme |
| [D-2 Prose](D-2-prose.md) | M8 | detail | A paragraph can be read; source stays king |
| [D-3 Sauce](D-3-sauce.md) | M8 | detail | `@./sauces/…` cooks; the file stays as written |
| [D-4 Find](D-4-find.md) | M8 | list | ⌘F matches names Oliver already parsed |

Pick in order unless the board says you may parallel. **D-1 first**
after the sit — you live in source. **D-2 and D-3 may run beside
each other** if D-2 does not restyle `RecipeReadView` and D-3 does
not restyle `MarkdownTextView`. **D-4 may run beside D-1**; it
gets better after D-3 inlines a sauce, but body search already
works. **C-3 may run beside any D card** that does not change
first-run or the notes-folder bookmark.

One card = one branch = one PR. Suggested prefix `docs/d0-board`,
`feat/d1-whisper`, `feat/d2-prose`, `feat/d3-sauce`, `feat/d4-find`,
`feat/c3-app`.

## Do not start

Save a scaled recipe copy is named on [B-X](B-X-refuse.md). It is
not a D card until a cook asks. Stylesheets, tags-as-a-place, and
All Recipes are not this board. Looking forward is
[`../HORIZON.md`](../HORIZON.md), [`../ROADMAP.md`](../ROADMAP.md)
M9–M12, and [`../HOPE-CHEST.md`](../HOPE-CHEST.md) (M99) — not a
pick list. If we fall asleep, the hope chest is the navigator.

Never from a card:

- Graph UI, backlinks, inspector
- Solipsist Compose
- Pantry / meal plan / shopping list
- AI
- Electron
- A fourth Settings pane
- A source | preview split

## Archive — Close (C)

The silhouette, sat and handed over. C-1 GUI and C-3 `.app` are
still the Close leftovers — they outrank D if you are shipping.

| Card | Milestone | Lane | Gate |
|------|-----------|------|------|
| [C-0 Board reset](C-0-board-reset.md) | M7 | docs | landed — B closed; C was the board |
| [C-1 Sit](C-1-sit.md) | M7 | chrome | cooking — five minutes, no explanation; GUI still open |
| [C-2 Honesty](C-2-honesty.md) | M7 | settings | landed — every feature is in the menu bar or Settings |
| [C-3 Hand it](C-3-hand-it.md) | M7 | app | landed — ad-hoc signed `.app`; GUI sit still open |

## Archive — Silhouette (B)

The first product. Landed. Open sits moved to C-1.

| Card | Milestone | Lane | Gate |
|------|-----------|------|------|
| [B-0 Silhouette](B-0-silhouette.md) | M3 | chrome | landed — three columns, no extra chrome |
| [B-1 Type](B-1-type.md) | M3 | type | landed — SF Pro, measure, no serif |
| [B-2 Caret](B-2-caret.md) | M3 | editor | landed — 30s undo-in-the-hand is C-1 |
| [B-3 Empty](B-3-empty.md) | M3 | chrome | landed — one-sentence empties |
| [B-4 Folders](B-4-folders.md) | M1 | core+sidebar | landed — Finder and BANAL agree |
| [B-5 Settings](B-5-settings.md) | M2 | settings | landed — three panes; Deploy is B-10 |
| [B-6 Menus](B-6-menus.md) | M3 | app | landed — if it isn’t in the menu bar, it isn’t a feature |
| [B-7 Oliver](B-7-oliver.md) | M4 | publisher/engine | landed — parse this buffer; no preview |
| [B-8 Languages](B-8-languages.md) | M5 | core+app | landed — `.md` / `.textile` / `.cook` as files |
| [B-9 Recipe read](B-9-recipe-read.md) | M5 | detail | landed — risotto sit is C-1 |
| [B-10 Publish](B-10-publish.md) | M6 | publisher | landed — Export, not onboarding |
