# Changelog

## [Unreleased]
- Settings Publish pane layout (issue #215): expanded Settings window height to fit all Publish pane sections and action buttons (`wrangler.toml` preview, Copy command, Deploy to Cloudflare) comfortably without clipping or requiring vertical scrolling.
- Settings Publish pane fits all controls (issue #215): streamlined the Deploy section with compact labeled rows and optimized the Settings window frame height so all deployment controls and action buttons fit comfortably without clipping on any Mac display size.
- Prose Read link styling: fixed an attribute traversal issue in `ProseReadView` where non-link text was styled as blue underlined links.
- CLI doctor check: fixed configured binary check to verify the specified engine path directly rather than falling back to system binaries in PATH.
- Boris and Oliver ship inside the app (issue #209): `make app` builds universal binaries from their Zig checkouts into `Contents/Helpers`, the locators prefer them, and Settings → Publish loses its binary pickers — recipe Read and Publish Site now work in the sandboxed app on a machine with nothing installed. Debug overrides stay available via `BANAL_OLIVER_BIN` / `BANAL_BORIS_BIN`; legacy paths in `.banal/config.json` still round-trip. AppleScript errors now surface their message instead of returning silently.
- AppleScript support: BANAL now has a scripting dictionary. Scripts can list and read notes, create notes (plain names, real folders, `.md`/`.textile`/`.cook`), edit bodies, flip Published, and run the publish pipeline — all through the same store the app uses, so every change lands as an ordinary file on disk.
- Agent CLI (issue #204): `banal vault|notes|show|publish|doctor` — a thin read-mostly command over the same vault resolution, note store, and publish pipeline as the app, with plain text or `--json` output and honest exit codes. For scripts, tests, and agents that were burning tokens UI-scripting the window. It never creates or changes notes; the editor stays the app.
- Publish survives plain names (issue #202): a note titled with spaces (`Published Note.md`) no longer fails the real Boris compile with `InvalidPath`. Entity ids handed to Boris are made Boris-shaped at the publish boundary — whitespace runs become `-`, `#?%` are rewritten — while files in your vault keep their plain names untouched.
- Retitle renames stay quiet (issue #192): renaming a note's file after an in-app retitle is one clean event — the store swallows the filesystem echo of its own rename, so the note list never blips and stale delete-echoes fire nothing at all.
- Internal (issue #181): `AppModel` no longer implements every domain itself. Editor session, recipes/Oliver, folders, imports, publishing, enrichment, and translation now live in focused types under a new `BANALAppModel` target with their own unit tests; `AppModel` coordinates them. No behavior change.
- No more list flicker on Finder renames (issue #186): directory-level filesystem events no longer reload every note in the vault. The store diffs disk against memory and updates only what actually moved, so notes outside the renamed folder keep their place — and a folder that returns to disk clears its own "moved or renamed" badge.
- Menus stay live when Settings is key (issue #191): Publish Site…, New Note, Import…, and friends no longer gray out while the Settings window has focus, or after the last notes window closes. Menu commands now act on the most recent notes window instead of a stale launch-time fallback.
- Plain names (issue #192): new notes land as `<Title>.md` — `Risotto.md`, not `2026-08-25-risotto.md` — with Finder-style collision numbering (`Risotto 2.md`) and titles that keep their case and accents. Retitling a plain-named note renames its file on disk the moment the buffer settles; legacy date-stamped files stay exactly as they are until you rename them yourself.
- Folder tree refresh without the re-read (issue #186): a Finder folder rename (or any directory-level change) no longer re-reads every note in the vault. `reloadAll` stats each file first and reuses the in-memory note when mtime + size are unchanged — untouched notes keep their objects and list rows, only notes whose path or file stats (mtime, size) changed are loaded, and an unchanged rescan does not republish the note list at all.
- Toolbar as content (issue #179): the big "Notes" header row above the note list is gone. The filter name now rides inline in the title bar and search is the native toolbar field at the top-right — the row it used to occupy goes to your notes, and the list starts level with the sidebar instead of a row below it.
- Warm first run (issue #177): the vault picker greets you with the app icon, one honest sentence — "Notes are plain files in a folder you own" — and, on a true first run, "Use Documents/BANAL Notes" as the default button so Return starts you writing. A brand-new vault is seeded with a single deletable `Welcome.md` (only at creation, only when the folder holds no notes; never recreated), which opens selected with the caret ready. The powerbox path seeds an empty picked folder too — sandboxed first runs always go through it. Editor empty state gains a quiet New Note button beside the ⌘N sentence; Settings → General explains that the notes folder works in Finder, iCloud Drive, or git.
- One stylesheet — single global pairing, system-honest (issue #160): `BanalTypography` (SF Pro + SF Mono via system fonts, no bundled fonts) is the one stylesheet for editor, Prose/Recipe Read, Quick Look, Print, and `boris.css` (`system-ui` + `ui-monospace`). Not per-note, no theme store, no serif personality. `EditorTypography` now delegates to it; `boris.css` measure stays 42rem ≈ 680pt.

## [1.0] — 2026

BANAL is a notes app. You open a folder, you write, you file notes into folders, and once in a while you publish the marked ones to a static site on Cloudflare Pages.

### What's in it

- **Notes in three languages.** Markdown, Textile, and Cooklang are just files in your folder. Open them in Finder, edit them in any text editor — BANAL notices.
- **Folders are real.** The sidebar shows your actual directory tree. Create, rename, move, trash — it all happens on disk.
- **Find everything.** ⌘F searches titles, bodies, tags, and recipe ingredients across all notes. ⌧⌘F searches the open note.
- **Read view.** Every note has Edit and Read. Recipes show ingredients, cookware, and steps with scale.
- **Publish when you want.** Mark notes Published, choose File → Publish Site. Deploy to Cloudflare Pages when you're ready. Writing works without any of it.
- **Quick Look.** Space in the note list opens the system preview — no external app launches.
- **Import.** File → Import copies notes and folders from other apps into your vault.
- **Copy As.** Copy as Markdown, Rich Text, or HTML from the Edit menu.
- **Keyboard-driven.** ⌘1/⌘2/⌘3 focus columns. ⌘[/⌘] switch Edit and Read. Every primary action is in the menu bar.
- **One window, one folder.** File → New Window opens another window for the same folder, each with its own selection and search.

### What's not in it

No accounts. No sync service. No subscription. No AI chatbot. Your notes are files on disk — iCloud Drive, syncthing, or git handles the rest.

### Previously

- 0.1 scaffold: native Mac app, three-column window, Markdown/Textile/Cooklang, sidebar, editor, publish, deploy.
