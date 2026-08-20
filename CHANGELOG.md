# Changelog

## [Unreleased]

- Apple Help Book: Help → BANAL Help (⌘?) now opens a bundled, searchable Help Book in the macOS Help Viewer. The book keeps one concise landing page covering the core writing, filing, finding, reading, and publishing paths, with contextual links from the editor and Publish settings.
- On-device translation session (F-6, issue #30): Edit → Translate… menu item under Edit menu is active when text is selected in the editor. On macOS 15+, presents the native system on-device translation sheet (`translationPresentation`) with interactive translation, copying, and in-place replacement. On macOS 14, falls back gracefully to standard `NSTextView` contextual menu and responder action (`translate:`). No API keys or cloud tokens required; no translation flags or badges clutter the UI chrome.
- Quick Look preview generator (F-4, issue #28): native `NotePreviewGenerator` in `BANALCore` produces formatted RTF previews for `.md`, `.cook`, and `.textile` in SF Pro — no WebView, no subprocess, no background engine. Cooklang recipes show title, `>>` metadata (source, tags, yield), ingredient list (name + quantity + unit), cookware, and numbered steps. Markdown renders headings, emphasis, bullets, numbered lists, blockquotes, and code fences. Textile follows the same structure. Spacebar in the note list opens `QLPreviewPanel`; UTI registrations for Markdown, Cooklang, and Textile are declared in `Info.plist`.
- Spotlight indexing and searchable item navigation (F-3, issue #27): Full macOS CoreSpotlight integration via `NoteSpotlightIndexer` and `CSSearchableItem`. Notes on disk donate searchable metadata (titles, 2-line snippets, folders/vault names, modification timestamps, tags, language extensions, and parsed recipe ingredients for `.cook` notes) asynchronously in non-blocking background tasks. Disk remains sole truth (no secondary database, disposable index); clicking a Spotlight result deep-links into BANAL, selecting the note and focusing the editor via `NSUserActivity` (`CSSearchableItemActionType`).
- Notarized release pipeline & DMG packaging (F-1, issue #25): Developer ID Application signing with hardened runtime (`--options runtime --timestamp`), `xcrun notarytool` automated submission and stapling for `.app` bundles and DMGs (supporting Keychain profiles, App Store Connect API keys, and Apple ID credentials with graceful ad-hoc fallback in `Scripts/notarize.sh`), and signed DMG packaging with `/Applications` shortcut (`make dmg`, `make release-dmg`, `make release`).
- Heading space-after & Writing Tools guard (E-5, issue #24): Heading lines (`# `, `## `, `### `, `#### `, `##### `, `###### ` and Textile `h1.`–`h6.`) apply distinct paragraph spacing (`paragraphSpacingBefore` 10pt with top-of-file exception, `paragraphSpacing` 4pt to hug following text cleanly) while keeping standard SF Pro typography. Writing Tools sessions (macOS 15+) guard against background idle styling passes, external file reload wipes, and midway flushes.
- Punctuation discipline in fences (E-4, issue #23): Smart quotes, smart dashes, text replacement, and spell checking are dynamically suppressed when the insertion point is inside fenced code blocks (` ``` `, `~~~`), inline code spans (`` `...` ``), or Cooklang metadata lines (`>>`). Punctuation typed and pasted into code retains literal ASCII (`"`, `'`, `--`, `---`), while standard prose retains user preferences.
- List continuation and breakout (E-3, issue #22): Typing Return on bullet (`- `, `* `, `+ `, `- [ ] `) or numbered (`1. `, `2. `) list lines continues the list with indentation preserved (numbered items increment; checked `- [x]` items continue as unchecked `- [ ]`). Pressing Return on an empty bullet line cleanly breaks out leaving a blank line with caret at column 0. Soft breaks via `Shift+Return` insert plain newlines, code fences suppress list continuation, and `⌘Z` undo works in a single clean step.
- Smart paste and links (E-2, issue #21): Pasting a URL over selected text wraps it in `[selectedText](url)` with caret right after `)`. Pasting rich text or HTML from web browsers and PDFs converts cleanly to Markdown while stripping spans, styles, divs, and classes. Full `⌘Z` undo support.
- Column focus & keyboard navigation (E-1, issue #20): ⌘1 (Focus Sidebar), ⌘2 (Focus Note List), ⌘3 (Focus Editor) under View menu. Full keyboard flow with arrow navigation, folder expand/collapse in sidebar, Return to jump to editor caret, Escape in editor to return to note list, and Tab / ⇧Tab column cycling without breaking code fence indentation.
- Find the saffron (D-4): ⌘F search in list view matches recipe ingredients in `.cook` notes (bare tokens, braced multi-word ingredients, and inlined sauces) and Oliver's parsed ingredient index in a disposable in-memory cache. Missing Oliver searches file body and tokens accurately without subprocess latency.
- Recipe references (D-3): a risotto that says `@./sauces/Hollandaise{150%g}` shows the sauce's ingredients and steps in Read, scaled by the reference's percent — the file on disk still says `@./sauces/…`.

### Fixed

- D-2 sit found it: switching Read back to Edit restored the source but left focus elsewhere. Now the caret lands back in the Markdown (focus is requested after the editor view is swapped in).

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

- Multi-select → Open With (and a Dock drag of several files) now imports **every** file: a SwiftUI `WindowGroup` routes only the first URL of a multi-file open to `.onOpenURL` — the rest now arrive via the `application(_:open:)` / `openURLs:` delegate hook, which was missing.

- Imported notes no longer risk a bumped `updated:` frontmatter from a rare stale editor write-back race: editor writes are session-guarded, and a save that changes nothing on disk is a no-op (F-9).

- Opening a note file (Finder double-click, Open With → BANAL, Dock drag) now actually opens it: SwiftUI `WindowGroup` delivers file opens to `.onOpenURL`, not the app delegate's `openFiles` hook, so the first F-8 build silently swallowed them. Both routes now feed `AppModel.openExternalNote` with a 2s dedupe guard.

- Recipe Read on a render-only Oliver (no `serialize --json`) now says “This recipe needs Oliver.” instead of the misleading “This recipe didn’t parse.” Idle render still works with older binaries.

### Added

- Read a paragraph (D-2): every note — Markdown and Textile too, not just recipes — has an Edit | Read control (View → Edit Note / Read Note). Read is a native, read-only page rendering Oliver's HTML on B-1 type: headings as weight, emphasis and links kept, the user's body size. Missing Oliver is one sentence; new notes open in Edit; the file stays source.

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
