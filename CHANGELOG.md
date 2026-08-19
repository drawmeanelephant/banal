# Changelog

## [Unreleased]

### Added

- Sit: VoiceOver labels on folders, notes, editor, and Settings; a vanished notes folder shows the picker while the app is open; Watch for edits from other apps actually gates reloads; typing undo is no longer eaten by style updates.
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
