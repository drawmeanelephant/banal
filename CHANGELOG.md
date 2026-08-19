# Changelog

## [Unreleased]

### Changed

- Fluency (D-0): Close is archive. Next *feature* work is whispered source, prose Read, sauce walks, and ingredient search — after the C-1 sit, and without a new column. See [`docs/cards/README.md`](docs/cards/README.md).
- Horizon: looking-forward notes for furniture, system pickers, and import-as-files. Not a board. [`docs/HORIZON.md`](docs/HORIZON.md).
- Platform cut (macOS 15–27 SDK): sit Writing Tools and dictation; later App Intents + Spotlight entities and the system Translate sheet. SwiftData, Inspector, canvas, Genmoji stay refused.
- Beyond M8: M9 Type, M10 System, M11 Files are implement-after-Fluency. M12 is consider-only. A rendered canvas in the editor is refused. See [`docs/ROADMAP.md`](docs/ROADMAP.md).
- Hope chest: the route to M99 (Home). Tucson is M9–M12. California is 1.0. Japan is vacation after that. [`docs/HOPE-CHEST.md`](docs/HOPE-CHEST.md).
- Close (C-0): B-0–B-10 marked landed. Next work is sit, Settings honesty, and a signed `.app` — not a new language or pane. See [`docs/cards/README.md`](docs/cards/README.md).
- Honesty (C-2): Publish, skip, and deploy status is a spoken sentence. Missing Oliver on a recipe Read says so.
- Editor type is SF Pro. Serif toggle is gone. Stylesheets later.
- Publish status strip says “1 note” when the count is one.
- A recipe (or any note in a folder) published to `.publish/` links back to the index with a relative href. Opening `Recipes/risotto.html` from Finder no longer 404s the home page.
- Moving or renaming a folder no longer treats the open note as a new document (caret and undo stay).

### Fixed

- Imported notes no longer risk a bumped `updated:` frontmatter from a rare stale editor write-back race: editor writes are session-guarded, and a save that changes nothing on disk is a no-op (F-9).

- Opening a note file (Finder double-click, Open With → BANAL, Dock drag) now actually opens it: SwiftUI `WindowGroup` delivers file opens to `.onOpenURL`, not the app delegate's `openFiles` hook, so the first F-8 build silently swallowed them. Both routes now feed `AppModel.openExternalNote` with a 2s dedupe guard.

- Recipe Read on a render-only Oliver (no `serialize --json`) now says “This recipe needs Oliver.” instead of the misleading “This recipe didn’t parse.” Idle render still works with older binaries.

### Added

- Whisper (D-1): headings get semibold weight and syntax markers (`#`, `**`, `@`, `{`, `>>`, …) are dimmed hints at ~30% opacity, applied ~0.4s after idle as layout-manager temporary attributes — the storage string, undo, and Find stay character-based, and the pass skips while Writing Tools is rewriting. Scanner is `WhisperScan` in `BANALCore` with per-language unit tests (Markdown/Textile/Cooklang; no false marks inside code spans or `>>>`; UTF-16-safe).

- File associations (F-8, issue #44): BANAL registers as an Editor for `.md`, `.textile`, and `.cook` — double-click, Open With → BANAL, and Dock drags now open a note (or import it from outside the vault with a unique name, source left untouched). One open route, so a single action never imports twice. `NoteStore.importFile` is unit-tested.

- Hand it (C-3): a crafted notes-app icon (tactile cotton pad, machined brass pen, terracotta ribbon), candidate icon reference gallery, sandbox on, and `make app` which writes an ad-hoc signed `dist/BANAL.app` stamped with version. Security-scoped bookmarks start on restore and stop on quit. Stale compiler bookmarks are dropped on path change. Settings binary pickers are individually accessible to VoiceOver.
- Fluency briefs: [`docs/cards/D-1-whisper.md`](docs/cards/D-1-whisper.md), [`D-2-prose.md`](docs/cards/D-2-prose.md), [`D-3-sauce.md`](docs/cards/D-3-sauce.md), [`D-4-find.md`](docs/cards/D-4-find.md). Save a scaled recipe stays off the board until a cook asks.
- Tester brief for the whole window: [`docs/TESTING-WINDOW.md`](docs/TESTING-WINDOW.md) (first-run, light+dark 720/1100/1400, 30s type/⌘Z, dirty Vim, empties, three languages, risotto Read, ⇧⌘P, VoiceOver).
- Honesty (C-2): Settings → Publish chooses Boris and Oliver (empty is fine). BANAL → About names the app, version 0.1.0, and the mission. Oliver’s path lives in `.banal/config.json` like Boris. Probing Oliver runs asynchronously off the main actor.

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
