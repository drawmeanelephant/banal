# BANAL

A native Mac notes app. You pick a folder, you write Markdown, you file notes into folders. That is the product.

Publishing through [Boris](https://github.com/drawmeanelephant/boris) to a static site (eventually Cloudflare Pages) is a preference and a menu item — never required to take a note.

The destination is a small AAA app that *looks* like Notes and *files* like Markdown, Textile, or Cooklang — notes and recipes, same folder. Read [`docs/THESIS.md`](docs/THESIS.md).

BANAL is not Solipsist, not a knowledge graph, and not a hosting dashboard.

## Requirements

- macOS 14+
- Xcode 16+ / Swift 6 (`swift --version`)
- Optional: a `boris` binary on `PATH` (or `BANAL_BORIS_BIN`) for the real SSG
- Optional: an `oliver` binary on `PATH` (or `BANAL_OLIVER_BIN`) for Markdown parse/render and recipe Read (`serialize --json`). The app still edits without it.

## Build and test

```bash
swift test
swift build
swift run BANAL
```

`swift test` is the source of truth for the storage contract and the publisher. The app target is a native SwiftUI + AppKit executable; it does not use Electron or a webview for editing.

### Signed `.app`

```bash
make app
```

That writes `dist/BANAL.app` (version 0.1.0), sandbox on, and signs it. This machine has no Developer ID certificate, so the signature is **ad-hoc** (`codesign -s -`). Drag it to `/Applications`. Gatekeeper will warn; right-click → Open the first time, or `xattr -cr dist/BANAL.app`.

It is not notarized. To sign with a Developer ID you have locally:

```bash
make app SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
```

Still not notarized unless you run `notarytool` yourself.

`swift run BANAL` is **not** sandboxed. Use `make app` when you want the real bookmark / picker sit. Boris and Oliver stay on PATH or Settings → Publish (Choose…). They are not inside the bundle.

## Vault

Default folder: `~/Documents/BANAL Notes`.

Each note is a `.md`, `.textile`, or `.cook` file. The extension is the language. Markdown and Textile use lightweight frontmatter (`title`, `created`, `updated`, `tags`, `published`). Cooklang files stay Cooklang (`>> title`). Media lives in `./assets/`. Edits made in Finder, Vim, or VS Code are observed via FSEvents and `NSFilePresenter`.

## Keys

| Shortcut | Action |
| --- | --- |
| ⌘N | New note, focus editor |
| ⌘⌫ | Move note to Trash |
| ⌘F | Search the note list |
| ⇧⌘F | Find in the current note |
| ⇧⌘P | Publish marked notes to `.publish/` |

## Publish

Mark notes **Published**, then File → Publish Site….

- Notes with `published: true` are staged as Boris pages (`status: published`).
- If `boris` is available it compiles HTML. Otherwise the builtin compiler writes HTML + `feed.xml`.
- A dry-run `wrangler.toml` is written next to the artifact. Cloudflare credentials are never required for local notes.

## Docs

| File | Role |
| --- | --- |
| [`AGENTS.md`](AGENTS.md) | Binding rules for anyone (or any model) writing code here |
| [`docs/NORTH-STAR.md`](docs/NORTH-STAR.md) | How it should feel. Wins when docs disagree. |
| [`docs/THESIS.md`](docs/THESIS.md) | Languages and engines (do not grow this) |
| [`docs/cards/README.md`](docs/cards/README.md) | What to build next (one card per PR) |
| [`docs/MISSION.md`](docs/MISSION.md) | One-page version |
| [`docs/QUALITY.md`](docs/QUALITY.md) | AAA finish bar |
| [`docs/PREFERENCES.md`](docs/PREFERENCES.md) | Settings + Publish pane (Deploy is live) |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Folders → Settings → Finish → Languages → Publish → Close |
| [`docs/STATUS.md`](docs/STATUS.md) | What works now |
| [`docs/TESTING-NOTES-FOLDER.md`](docs/TESTING-NOTES-FOLDER.md) | How to sit the notes-folder picker (first run, missing, vanish while open) |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Boris / Solipsist boundary |
