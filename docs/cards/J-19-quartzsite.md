# Card J-19 — Quartzsite — copy, help & final sit (Drive triage)

**Milestone:** M19 · **Lane:** chrome · **Status:** board · **Branch:** `fix/j19-quartzsite` · **Parent:** #116 · **Subissues:** #147 J-19a, #148 J-19b, #149 J-19c

## Handoff

- `main` at `4378a6a` + `J-16` board+snack, `J-17` board `c453073`, `J-18` board `1d28a1e`. `swift test` 265 green, `make smoke` passed, `hiutil` Help index verified. Quartzsite is the winter RV hell — empties still whisper when the vault is empty or full, and the whole window gets sat before paid I-1.
- Help is one page `Resources/BANAL.help` + About `BanalApp.swift:121`, empties `NoteListView.swift:100`, `CopyAsConverter` already landed (G-2) — this card verifies, not invents.

## Owns

- `Resources/BANAL.help/` (one landing page, 6 anchors, `hiutil` index), `Sources/BANALApp/BanalApp.swift:121` `BanalAbout`, `Sources/BANALApp/Views/NoteListView.swift:100` empties, `CHANGELOG.md` 1.0 notes, `Sources/BANALApp/Views/StatusStripView.swift`
- `Sources/BANALCore/CopyAsConverter.swift` + `Sources/BANALApp/Views/MarkdownTextView.swift` `handleSmartPaste` + `SmartPaste.swift` (`HTMLToMarkdown`, `SmartPaste.linkWrapped`)
- `docs/TESTING-WINDOW.md` (the whole sit script) — the gate
- `Tests/BANALCoreTests/CopyAsTests.swift`, `SmartPasteTests.swift`, `HTMLToMarkdownTests.swift`

## Do not touch

- Bookmark (M13), Gila Bend (M14), Yuma (M15), El Centro (M16), Niland (M17), Desert Center (M18)
- Tour, RTF editor, Help site, fourth pane, webview preview, inspector

## Why

If an empty vault looks like a landing page, the “boring on purpose” bar failed (`NORTH-STAR.md:1`, `HOPE-CHEST.md:112` Japan is after California). Quartzsite proves the window is still `folders · list · page` when it’s empty and when it’s full.

## Do

### J-19a One-sentence empties + Help single page + About + CHANGELOG — friend reads and never asks “where’s the rest?” (#TBD)

1. Keep `NoteListView.swift:100` empties: `No notes in this folder.` / `No notes match.` / `Nothing published.` / `No selection` — one sentence each `Sources/BANALApp/Views/NoteListView.swift:100`, no illustrations, no “tips for your first week.” Keep `BanalAbout.mission` `BanalApp.swift:124` “BANAL is a beautiful, boring, local Mac notes app whose files are allowed to be excellent.” + `version 1.0`, `Resources/BANAL.help` one page `BANAL.html:27` 6 anchors, `hiutil` indexed.
2. Keep `CHANGELOG.md` 1.0 notes — what a friend needs, not a dump.

### J-19b Copy As + paste URL→[text](url) + clean Markdown from Safari/PDF via Oliver stripping spans/divs (#TBD)

1. Keep `CopyAsConverter.copy:647` `CopyAsFormat` Markdown/RTF/HTML via `BANALCore` (`CopyAsTests`), `MarkdownTextView.handleSmartPaste:710` `SmartPaste.linkWrapped` `[selectedText](url)` + `SmartPaste.cleanMarkdown(fromHTML:)` stripping `span`/`div`/`style`/`class` via `HTMLToMarkdown` — provenance: ask Oliver first; fallback is builtin.
2. Keep `⌘C` untouched, `Copy As` via `Edit → Copy As` submenu.

### J-19c Whole-window re-sit light+dark 720/1100/1400 + 30s type/⌘Z + dirty/clean closes C-1/D-1/D-2/F-8 before paid I-1 (#TBD)

1. Re-sit `docs/TESTING-WINDOW.md` end-to-end on `dist/BANAL.app` ad-hoc: `720×520` (sidebar may collapse) / `1100×720` (default 3 columns) / `1400×800` (measure `680pt` centered) light + dark; `Type` SF Pro 16pt; `Empty` one sentence each; `Languages` `.md/.textile/.cook` on disk; `Risotto` Read 2× disk unchanged; `Publish` 3 notes builtin; `VoiceOver` `Folders/Notes/Note`; plus `J-14` dirty/clean Vim + `J-15` 30s type + `J-17` keyboard.
2. Gate closes `C-1` (5 min no explanation) + `D-1/D-2` (whisper hints, Read is page) + `F-8` (Open With) before `I-1` paid `Developer ID` `notarytool` — `HOPE-CHEST.md:18` California free-tier → paid.

**Tests to keep green:** `CopyAsTests`, `SmartPasteTests`, `HTMLToMarkdownTests`, `ExternalEditTests`, `NoteStoreTests`, `swift test` 265, `make smoke`.

## Do not

- Add a welcome tour, RTF editor, or a Help site (`I-3` gate is one page).
- Make focus/paragraph dimming, per-note fonts, or a karma HUD.

## Gate

`docs/TESTING-WINDOW.md:220` pass/fail + `docs/cards/README.md` Board J: empty vault one line not landing page; `Copy As` Markdown/RTF/HTML + paste `URL→[text](url)` + clean Safari paste pass; Help single page + About `1.0` read-aloud pass; whole window light+dark `720/1100/1400` + `30s type/⌘Z` + `dirty/clean` closes `C-1/D-1/D-2/F-8` before paid `I-1`.

## Failure is a landing page

If an empty folder looks like an illustration with “Get started!” or Help is a site, or Copy As clobbers `⌘C`, fails `J-19`.
