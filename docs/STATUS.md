# Status

**Phase:** 1.0 Silhouette (sit open)  
**Bar:** The first product is drawn — folders · list · page, three languages, recipe Read, publish as Export. A whole-window sit is C-1, not another B card.

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

## Still open (Close)

| Gap | Card | Notes |
| --- | --- | --- |
| Whole-window sit | [C-1](cards/C-1-sit.md) | Script: [`TESTING-WINDOW.md`](TESTING-WINDOW.md). Code-backed sit landed (nested publish nav, status grammar, caret id on move). **GUI not sat in this environment** — 30s type / ⌘Z, light+dark 720/1100/1400, and VoiceOver stay open until a human runs the window |
| Oliver / Boris paths, About, first-run copy | [C-2](cards/C-2-honesty.md) | Landed. Settings → Publish Choose… / Reveal. About BANAL. |
| Signed `.app` / sandbox | [C-3](cards/C-3-hand-it.md) | Landed — ad-hoc signed `dist/BANAL.app` via `make app`, sandbox on, app icon, bookmarks start/stop. No Developer ID on this machine; not notarized. GUI sit of the signed app still wants a human. |

## Known gaps in the scaffold

- List selection and editor flush have store tests and a caret-session fix; they are not battle-tested in the GUI. C-1, still the 30s row.
- Builtin Markdown HTML is a small subset. Fine until Boris is the usual publish path.
- Default vault picker vs `~/Documents/BANAL Notes` first-run uses the same “notes folder” words as Settings. Human sit still C-1.
