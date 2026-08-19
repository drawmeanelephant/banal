# Changelog

## [Unreleased]

### Changed

- Close (C-0): B-0–B-10 marked landed. Next work is sit, Settings honesty, and a signed `.app` — not a new language or pane. See [`docs/cards/README.md`](docs/cards/README.md).
- Honesty (C-2): Publish, skip, and deploy status is a spoken sentence. Missing Oliver on a recipe Read says so.
- Editor type is SF Pro. Serif toggle is gone. Stylesheets later.
- Publish status strip says “1 note” when the count is one.
- A recipe (or any note in a folder) published to `.publish/` links back to the index with a relative href. Opening `Recipes/risotto.html` from Finder no longer 404s the home page.
- Moving or renaming a folder no longer treats the open note as a new document (caret and undo stay).

### Added

- Hand it (C-3): a notes-app icon, sandbox on, and `make app` which writes an ad-hoc signed `dist/BANAL.app`. No Developer ID on this machine; not notarized. Security-scoped bookmarks start on restore and stop on quit. A vanished notes folder is still not recreated.
- Tester brief for the whole window: [`docs/TESTING-WINDOW.md`](docs/TESTING-WINDOW.md) (first-run, light+dark 720/1100/1400, 30s type/⌘Z, dirty Vim, empties, three languages, risotto Read, ⇧⌘P, VoiceOver).
- Honesty (C-2): Settings → Publish chooses Boris and Oliver (empty is fine). BANAL → About names the app, version 0.1.0, and the mission. Oliver’s path lives in `.banal/config.json` like Boris.

- Publish (B-10): File → Publish Site writes `.publish/` for marked Markdown, Textile, and Cooklang notes. Recipes stay Cooklang on disk. File → Deploy to Cloudflare is optional and uses the Keychain token.
- Recipe Read (B-9): `.cook` notes have Edit | Read. Read is a native ingredient list and steps. ½ 1× 2× 3× scales the view; the file on disk does not change.
- Languages (B-8): `.md`, `.textile`, and `.cook` are notes in the same list. File → New Textile and File → New Recipe. Recipes write Cooklang (`>> title`, one ingredient, one step), not YAML. Opening each is source.
- Tester brief for the notes folder: [`docs/TESTING-NOTES-FOLDER.md`](docs/TESTING-NOTES-FOLDER.md) (first run, missing at launch, vanish while open, do not recreate).
- Sit: VoiceOver labels on folders, notes, editor, and Settings; a vanished notes folder shows the picker while the app is open; Watch for edits from other apps actually gates reloads; typing undo is no longer eaten by style updates.
- Oliver (B-7): `OliverClient` asks `oliver render --from markdown` after idle typing. Locate via `BANAL_OLIVER_BIN`, PATH, or a sibling checkout. Missing binary is silent. No preview column. Idle ask only renders the last buffer; locate is injectable so tests do not need a machine `PATH`.
- Sit fixes: selecting a note no longer rewrites a clean file; Find Notes always focuses search; a vanished folder filter falls back to All Notes; the Publish pane is tall enough to show Deploy.
- Settings (B-5): Publish pane uses the Preferences copy, validates base URL and project name inline, warns on an odd account ID, and persists site + Cloudflare IDs in `.banal/config.json` without a token.
- Folders (B-4): New Note Here creates in that directory even when new notes default to Inbox; renaming a folder keeps the open note; Finder rename of a folder rescans ids; reserved directories stay off the sidebar.
- Caret (B-2): switching notes no longer rewrites a clean file; dirty flag clears when the buffer matches disk; caret resets on note change and holds on a clean external reload; Find in Note opens the find bar.
- Menus (B-6): File has New Note, New Folder, Trash, Open/Reveal notes folder, Publish Site; Find Notes and Find in Note live in one Find menu.
- Empty states (B-3): one-sentence first-run, empty folder, empty search, no selection, nothing published; missing notes folder is the same picker, not a sheet stack.
- Type (B-1): New York / system-serif body and title, 16pt default, line height applied to the open note, 680pt centered measure, system-accent selection.
- Silhouette (B-0): three-column window with ~200pt folders and ~280pt list, two-line snippets, globe for published, title plus a quiet metadata row, transient status strip, no toolbar icons.
- North Star (`docs/NORTH-STAR.md`): Sparrow/Mailbox/early-Twitter/Tapbots qualities, Ive × Kondo test, files own the destiny. Chrome pass: search on ⌘F, no tags sidebar, publish is ⇧⌘U, title+body only.
- Session cards in `docs/cards/` (silhouette, type, caret, folders, recipe read, refuse).
- Product thesis: `docs/THESIS.md` — dead-simple window, Markdown/Textile/Cooklang files, notes + recipes, Oliver for markup, Boris for site. Graph stays out of the UI.
- First product draft: real folders (create, rename, move, trash, nested tree), notes created in the selected folder, drag-and-drop onto folders.
- Settings window (`⌘,`) with General, Editor, and Publish. Cloudflare fields persist; API token goes to the Keychain; Deploy is present and disabled.
- Editor preferences: serif body, size, line height, measure cap, spelling, smart quotes.
- Project policy and destination docs: `AGENTS.md`, `docs/MISSION.md`, `docs/QUALITY.md`, `docs/PREFERENCES.md`, `docs/STATUS.md`, `docs/ROADMAP.md`.

### Previously

- 0.1 scaffold: `BANALCore`, `BANALPublisher`, native `BANALApp` MVP, tests.
