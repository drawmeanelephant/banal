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

Tucson is drawn: E (M9) and F (M10) are landed, G (M11) is landed,
H (M12) is landed (issues #37–40). **California free-tier** (M20):
I-1 is **deferred** (no paid `Developer ID Application` — only free team `ZQT4XUHVT5` / ad-hoc; `Scripts/notarize.sh` no-ops), I-3 is **landed** (`dac8c14` PR #108), I-2 whole-window sit rolls up C-1 + D-1/D-2 + F-8 gates on the **ad-hoc** build (you light sit now, friend full light+dark 720/1100/1400 + VoiceOver later). Pick I-2 now; I-1 notarize is the paid next. M13–M19 sit bugs are the only Board J until I-2 closes.

Each card’s **Handoff** block is the note for the next person.

| Card | Status |
|------|--------|
| I-1 | **deferred — free tier** — pipeline landed `F-1` (`make release`/`Scripts/notarize.sh`), no paid `Developer ID Application` on this Mac; ad-hoc `-` / `Apple Development ZQT4XUHVT5` ships via right-click Open |
| I-2 | **board — whole-window release sit** (closes C-1, D-1/D-2, F-8) — on ad-hoc build; local light sit may run now, friend full sit gate |
| I-3 | **landed** — 1.0 copy `dac8c14` Help/About/empties/`CHANGELOG.md` |
| C-1 | **rolled into I-2** — script + code-backed sit landed; GUI 30s type/⌘Z + 720/1100/1400 still open |
| D-1 | **landed code, gate pending** — whisper `WhisperScan` 0.4s idle, pending I-2 friend visual |
| D-2 | **landed code, gate pending** — `ProseReadView` native page, pending I-2 friend visual |
| D-3 | landed — recipe references inlined in Read |
| D-4 | landed — ⌘F matches ingredient names + inlined sauces |
<<<<<<< HEAD
| M13–M19 | **active triage — Drive** — J-13 Casa Grande (`fix/j13-casa-grande` #110 → #117-#120) landed, J-14 Gila Bend (`fix/j14-gila-bend` #111 → #123-#126) landed `686d972`, J-15 Yuma (`fix/j15-yuma` #112 → #129 #130 #131) landed `c2d039e`, J-16 El Centro (`fix/j16-el-centro` #113 → #134 #135 #136) board + snack `4378a6a`, J-17 Niland (`fix/j17-niland` #114 → #139 #140 #141) board, J-18 Desert Center (`fix/j18-desert-center` #115 → #143 #144 #145) board; M19 stay blank until I-2 files that class |

### Board J — The Drive: Casa Grande → Quartzsite (M13–M19) — stability triage

I-8 shithole towns, not macOS names. One sit bug = one card in the town whose theme it broke. Blank until filed; J-13 is now the first cut. Do not pull M14–M19 work into J-13.

| Card | Milestone | Lane | Gate |
|------|-----------|------|------|
| [J-13 Casa Grande](J-13-casa-grande.md) | M13 | core+app | **landed** — bookmark survives move/rename/reboot; first-run vs missing; vanish-while-open dumps to picker; Reveal after Finder rename. Subissues #117 #118 #119 #120 · `fix/j13-casa-grande` · `docs/TESTING-NOTES-FOLDER.md:1` |
| [J-14 Gila Bend](J-14-gila-bend.md) | M14 | core | **landed** — external truth (FSEvents dirty/clean, F-9) — coalesce/no DB/empty folders + dirty-keep/clean-reload + watch-off + F-9 guard. Subissues #123 #124 #125 #126 · `fix/j14-gila-bend` `686d972` · `docs/TESTING-WINDOW.md:4` |
| [J-15 Yuma](J-15-yuma.md) | M15 | core | **landed** — write & crash safety (atomic 0.4s, caret/undo per-note, kill -9, config) — `fix/j15-yuma` `c2d039e` · `docs/TESTING-WINDOW.md:112` |
| [J-16 El Centro](J-16-el-centro.md) | M16 | app | **board** — latency & large vault (5k, ⌘F, Spotlight disposable) — `fix/j16-el-centro` #113 · `docs/TESTING-WINDOW.md:112` |
| [J-17 Niland](J-17-niland.md) | M17 | chrome | **board** — a11y & keyboard (VoiceOver, ⌘1/⌘2/⌘3, Reduce Motion/Contrast) — `fix/j17-niland` #114 · `docs/TESTING-WINDOW.md:199` |
<| [J-18 Desert Center](J-18-desert-center.md) | M18 | system | **board** — system furniture (UTType/Quick Look/Print) — `fix/j18-desert-center` #115 · `docs/TESTING-WINDOW.md:4` |
| M19 Quartzsite | M19 | chrome | **blank** — copy/help & final sit — cut only if I-2 files |

Suggested prefixes: `fix/j13-casa-grande` … `fix/j19-quartzsite`. One card = one branch = one PR; `swift test` green, no second DB, no silently recreating the vault.

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

## Boards — Tucson (M9–M12)

Stage after M8 is done (or beside D where noted).

### Board E — Type in the page (M9)

| Card | Milestone | Lane | Gate |
|------|-----------|------|------|
| [E-1 Focus](E-1-focus.md) | M9 | chrome | landed — ⌘1/⌘2/⌘3 column focus, Tab cycle, arrow keys |
| [E-2 Paste](E-2-paste.md) | M9 | editor | landed — `[text](url)` on paste; clean Markdown from web/PDF |
| [E-3 List](E-3-list.md) | M9 | editor | landed — Return continues list; empty bullet breaks out |
| [E-4 Fences](E-4-fences.md) | M9 | editor | landed — Smart quotes/dashes off inside ``` and ` ` |
| [E-5 Heading & Tools](E-5-heading-tools.md) | M9 | editor | landed — Heading space-after hugs text; Writing Tools safe |

### Board F — System (M10)

| Card | Milestone | Lane | Gate |
|------|-----------|------|------|
| [F-1 Notarize](F-1-notarize.md) | M10 | app | landed — Developer ID + notarization pipeline & signed DMG |
| [F-2 Intents](F-2-intents.md) | M10 | system | landed — Siri & Shortcuts: New Note, New Recipe, Take a Note |
| [F-3 Spotlight](F-3-spotlight.md) | M10 | system | landed — `CSSearchableItem` / `NoteEntity` finds notes + ingredients |
| [F-4 Quick Look](F-4-quicklook.md) | M10 | system | landed — `NotePreviewGenerator` RTF for `.md`/`.cook`/`.textile`; Spacebar in note list opens `QLPreviewPanel` |
| [F-5 Print & Share](F-5-print-share.md) | M10 | system | landed — File → Print (⌘P), Share sheet, Services menu item |
| [F-6 Translate](F-6-translate.md) | M10 | system | landed — Edit → Translate… via system Translation session (`TranslationPresentation` / `NSTextView`) |
| [F-7 System sit](F-7-system-sit.md) | M10 | chrome | landed — VoiceOver, Reduce Motion, Increase Contrast audit |
| [F-8 File associations](F-8-file-associations.md) | M10 | system | Open With / double-click `.md`, `.textile`, `.cook` in Finder |

### Board G — Files (M11)

| Card | Milestone | Lane | Gate |
|------|-----------|------|------|
| [G-1 Assets](G-1-assets.md) | M11 | files | landed — drop photo copies to `assets/` + relative link |
| [G-2 Copy As](G-2-copy-as.md) | M11 | editor | landed — Edit → Copy As: Markdown, Rich Text (RTF), HTML |
| [G-3 Import](G-3-import.md) | M11 | files | landed — File → Import… (⌘I) copies folder/files into vault |
| [G-4 Pickers](G-4-pickers.md) | M11 | editor | landed — Edit → Insert Contact… / Insert File… |
| [G-5 Drag out](G-5-drag-out.md) | M11 | list | landed — Drag note from list into Mail / Messages / Finder |

### Board H — Consider (M12)

Landed (issues #37–40). The four maybes became cards.

| Card | Milestone | Lane | Gate |
|------|-----------|------|------|
| [H-1 Checkbox](H-1-checkbox.md) | M12 | editor | landed — Click `- [ ]` in source to toggle `- [x]` |
| [H-2 Word count](H-2-word-count.md) | M12 | chrome | landed — Quiet word / character count in existing status strip |
| [H-3 Tags filter](H-3-tags-filter.md) | M12 | list | landed — Tags section in sidebar as secondary filter |
| [H-4 New window](H-4-new-window.md) | M12 | chrome | landed — File → New Window on the same notes folder |

### Board I — California (M20) — free-tier vs paid

The drive. Cut strictly from the M20 checklist in
[`../HOPE-CHEST.md`](../HOPE-CHEST.md). Free-tier ships ad-hoc (right-click Open); paid adds notarize. Sit bugs found by I-2 are
the only thing allowed to fill M13–M19. Pick I-2 now; I-1 paid re-opens after friend sit + Program.

| Card | Milestone | Lane | Gate |
|------|-----------|------|------|
| [I-1 Release](I-1-release.md) | M20 free → paid | app | **Free deferred** — `F-1` pipeline done, `make app` ad-hoc/`ZQT4XUHVT5` ships; **Paid gate** = `Developer ID Application` + notarized + stapled DMG, stranger double-clicks no warning |
| [I-2 Release sit](I-2-release-sit.md) | M20 | chrome | One human, one afternoon, the **ad-hoc** build (you light + friend full 720/1100/1400 + VoiceOver); closes C-1/D-1/D-2/F-8 |
| [I-3 Copy](I-3-copy.md) | M20 | copy | **Landed** `dac8c14` — Help single page + About + empties `Sources/BANALApp/Views/NoteListView.swift:100`; friend re-read is I-2 |

**Next after free-tier:** M13–M19 drive — one sit-bug card at a time, then paid I-1 notarize when `Developer ID Application` available, then Japan (M50) `HOPE-CHEST.md:112`.

## Do not start

Save a scaled recipe copy is named on [B-X](B-X-refuse.md). It is
not a D card until a cook asks. Stylesheets, tags-as-a-place, and
All Recipes are not this board. Looking forward is
[`../HORIZON.md`](../HORIZON.md), [`../ROADMAP.md`](../ROADMAP.md)
M9–M20, and [`../HOPE-CHEST.md`](../HOPE-CHEST.md) (M99) — not a
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
