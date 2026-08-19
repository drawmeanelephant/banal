# Status

**Phase:** 0.4 Silhouette  
**Bar:** Sat in the running app (light + dark, 1100 / 1400 / 720). The window is folders · list · page. VoiceOver labels are on the three columns. A longer type/⌘Z sit in the hand is still open.

## What works today

- Three columns: sidebar ~200pt, list ~280pt, editor takes the rest. Sidebar may collapse; 720×520 still shows list + editor
- List rows: title, two-line snippet, relative date, globe if published
- Editor: title + one quiet metadata row (date, published, tags). Body is a page
- Type: system serif body and title, 16pt, line height from Settings, 680pt centered measure when limited
- Caret: flush only when dirty; switch notes resets undo; clean external reload keeps a valid offset; ⇧⌘F shows the find bar
- Empty list / empty folder / no selection / nothing published are one sentence each
- Missing or deleted notes folder shows “This notes folder is missing.” and Choose… — at launch and if the folder vanishes while open; the folder is not silently recreated. Tester script: [`TESTING-NOTES-FOLDER.md`](TESTING-NOTES-FOLDER.md)
- Folders are real directories: create, rename, trash, nested tree, empty folders stay; Finder mkdir/rename rescans
- New note lands in the selected folder (or Inbox / root, per Settings); New Note Here always uses that folder
- Drag a note onto a folder (or All Notes) to move the file
- Settings (`⌘,`): General, Editor, Publish
- Publish pane stores site + Cloudflare IDs in `.banal/config.json`; API token in Keychain; Deploy is visible and disabled
- Publish fields validate inline (http/s base URL, Cloudflare-safe project name; account ID warns)
- Editor: system serif, measure cap, line height, spell check / smart quotes
- Menus: ⌘N note, ⇧⌘N folder, ⌘⌫ trash, ⇧⌘P publish, ⌘F find notes, ⇧⌘F find in note
- Oliver: one-shot Markdown render (`oliver render --from markdown`) after idle typing. Missing binary is silent. No preview.

## Still open

| Gap | Notes |
| --- | --- |
| Longer type / ⌘Z sit | Switch + clean Vim reload + dirty keep-buffer verified; 30s undo-in-the-hand still a human pass |
| Live Cloudflare deploy | Intentionally later — pane exists, Deploy disabled |
| Oliver preview / `.cook` | M5 (B-8, B-9). This card only asks the question. |
| Signed `.app` / sandbox | `swift run` only |

## Known gaps in the scaffold

- List selection and editor flush are careful but not battle-tested in the GUI (tests cover the store, not the window).
- Builtin Markdown HTML is a small subset. Fine until Boris is the usual publish path.
- Default vault picker vs `~/Documents/BANAL Notes` first-run still needs the Settings copy.
