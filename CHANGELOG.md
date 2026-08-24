# Changelog

## [Unreleased]
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
