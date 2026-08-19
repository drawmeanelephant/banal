# Status

**Phase:** 1.0 Silhouette (sit open) · Fluency board written  
**Bar:** The first product is drawn — folders · list · page, three languages, recipe Read, publish as Export. A whole-window sit is still C-1. Fluency (D) deepens the file after that sit — it does not add a column.

## What works today

- Three columns: sidebar ~200pt, list ~280pt, editor takes the rest. Sidebar may collapse; 720×520 still shows list + editor
- List rows: title, two-line snippet, relative date, globe if published
- Editor: title + one quiet metadata row (date, published, tags). Body is a page
- Type: SF Pro body and title, 16pt, line height from Settings, 680pt centered measure when limited
- Caret: flush only when dirty; switch notes resets undo; clean external reload keeps a valid offset; ⇧⌘F shows the find bar
- Empty list / empty folder / no selection / nothing published are one sentence each
- Missing or deleted notes folder shows “This notes folder is missing.” and Choose… — at launch and if the folder vanishes while open; the folder is not silently recreated. Tester script: [`TESTING-NOTES-FOLDER.md`](TESTING-NOTES-FOLDER.md)
- Signed `.app` via `make app`: sandbox, icon, ad-hoc codesign. Notes-folder bookmarks start on restore and stop on quit. No Developer ID / notarization on this machine.
- Folders are real directories: create, rename, trash, nested tree, empty folders stay; Finder mkdir/rename rescans
- New note lands in the selected folder (or Inbox / root, per Settings); New Note Here always uses that folder
- Drag a note onto a folder (or All Notes) to move the file
- Settings (`⌘,`): General, Editor, Publish. Publish can Choose… / Reveal Boris and Oliver; empty is fine. BANAL → About BANAL.
- Publish pane stores site + Cloudflare IDs and optional Boris/Oliver paths in `.banal/config.json`; API token in Keychain
- Publish fields validate inline (http/s base URL, Cloudflare-safe project name; account ID warns)
- Editor: SF Pro, measure cap, line height, spell check / smart quotes
- Menus: ⌘N note, ⇧⌘N folder, ⌘⌫ trash, ⇧⌘P publish, ⌘F find notes, ⇧⌘F find in note
- Oliver: one-shot render after idle typing (`--from` from the file extension). Missing binary is silent. No preview.
- Languages: `.md`, `.textile`, and `.cook` are notes. File → New Textile / New Recipe. Recipes keep Cooklang `>>` metadata, not a YAML fence. Opening any of them is source.
- Recipe Read: `.cook` notes have Edit | Read. Read shows ingredients, cookware, steps, and notes from Oliver’s typed Recipe. ½ 1× 2× 3× scales the view only. Missing or older Oliver (no `serialize --json`) is one sentence; Edit still works.
- Publish Site (⇧⌘P): only `published` notes leave the vault. Markdown uses Boris when present, else builtin HTML+RSS. Textile and Cooklang join the same `.publish/` folder via Oliver. Recipes stay Cooklang on disk. Deploy to Cloudflare is optional and enabled when a Keychain token and project name exist.
- File associations (F-8, issue #44, pulled forward from M10): BANAL declares itself Editor for `.md` / `.textile` / `.cook` (Open With, Dock drag, double-click). A file inside the vault opens in place; one outside is copied into the vault root (unique name, source untouched) and selected. Opens arrive via SwiftUI `.onOpenURL` (first URL of a multi-file open) plus the `application(_:open:)` / `openURLs:` delegate hook (the remaining URLs — without it, multi-select → Open With dropped all but the first file), deduped so one action never imports twice. Card: [`F-8-file-associations.md`](cards/F-8-file-associations.md).

## Still open (Close)

| Gap | Card | Notes |
| --- | --- | --- |
| Whole-window sit | [C-1](cards/C-1-sit.md) | Script: [`TESTING-WINDOW.md`](TESTING-WINDOW.md). Code-backed sit landed (nested publish nav, status grammar, caret id on move). Sit prep is done and CI-green: every brief row was audited against the code, this machine’s Oliver/Boris were probed (Read is the one-sentence path; publish uses builtin), and `make smoke` boots the signed app against a scratch vault on GitHub Actions. **GUI not sat in this environment** — 30s type / ⌘Z, light+dark 720/1100/1400, and VoiceOver stay open until a human runs the window. Outranks every D card. |
| Oliver / Boris paths, About, first-run copy | [C-2](cards/C-2-honesty.md) | Landed. Settings → Publish Choose… / Reveal. About BANAL. |
| Signed `.app` / sandbox | [C-3](cards/C-3-hand-it.md) | Landed — ad-hoc signed `dist/BANAL.app` via `make app`, sandbox on, app icon, bookmarks start/stop. No Developer ID on this machine; not notarized. GUI sit of the signed app still wants a human. |

## Next (Fluency)

Board written. Do not pick until C-1 has been sat.

| Gap | Card | Notes |
| --- | --- | --- |
| Whispered source | [D-1](cards/D-1-whisper.md) | Implemented: headings get weight, sigils are ~30%-opacity hints via temporary attributes (`WhisperScan`, unit-tested, 0.4s idle debounce, Writing-Tools-safe). Card mini-sit still open. |
| Markdown/Textile Read | [D-2](cards/D-2-prose.md) | Implemented: every note gets Edit \| Read (mode renamed to `ViewMode`), prose Read renders Oliver's HTML as a native attributed page on B-1 type (`ProseReadView`), missing Oliver is one sentence, new notes open in Edit. Sit found and fixed one gap: Read → Edit now requests focus (async past the view swap) so the caret lands back in the Markdown — proven with ⌘A → ⌘C on the signed app. Visual gate (page, not browser) open for a human. |
| Recipe references | [D-3](cards/D-3-sauce.md) | `@./sauces/…` inlines for Read. Disk stays two files. |
| Ingredient search | [D-4](cards/D-4-find.md) | ⌘F matches names Oliver parsed. No food ontology. |

Pulled forward from M10 by a real bug report: [F-8 File associations](cards/F-8-file-associations.md) landed (issue #44) — Open With / Dock drag for the three languages, outside files copied into the vault. GUI gate still open on a real machine.

## Known gaps in the scaffold

- List selection and editor flush have store tests and a caret-session fix; they are not battle-tested in the GUI. C-1, still the 30s row.
- Rare editor write-back race (F-9): a timing-dependent stale buffer could bump an imported note's `updated:` frontmatter. Fixed — editor writes are session-guarded (`loadedForID` / `loadedSessionID`), `NoteStore.update` only bumps `updated` on a real field change, and the gate ran 10/10 byte-identical back-to-back imports. Card: [`F-9-updated-bump-race.md`](cards/F-9-updated-bump-race.md).
- Builtin Markdown HTML is a small subset. Fine until Boris is the usual publish path.
- Default vault picker vs `~/Documents/BANAL Notes` first-run uses the same “notes folder” words as Settings. Human sit still C-1.
