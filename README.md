# BANAL

A native Mac notes app. You pick a folder, you write Markdown, you file notes into folders. That is the product.

Publishing through [Boris](https://github.com/drawmeanelephant/boris) to a static site (eventually Cloudflare Pages) is a preference and a menu item — never required to take a note.

The destination is a small AAA app that *looks* like Notes and *files* like Markdown, Textile, or Cooklang — notes and recipes, same folder. Read [`docs/THESIS.md`](docs/THESIS.md).

BANAL is not Solipsist, not a knowledge graph, and not a hosting dashboard.

## Requirements

- macOS 14+
- Xcode 16+ / Swift 6 (`swift --version`)
- Optional: a `boris` binary on `PATH` (or `BANAL_BORIS_BIN`) for the real SSG

## Build and test

```bash
swift test
swift build
swift run BANAL
```

`swift test` is the source of truth for the storage contract and the publisher. Pull requests and `main` run that same command on GitHub Actions (`macos-15`). The app target is a native SwiftUI + AppKit executable; it does not use Electron or a webview for editing.

## Vault

Default folder: `~/Documents/BANAL Notes`.

Each note is a `.md` file with lightweight frontmatter (`title`, `created`, `updated`, `tags`, `published`). Media lives in `./assets/`. Edits made in Finder, Vim, or VS Code are observed via FSEvents and `NSFilePresenter`.

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
| [`docs/PREFERENCES.md`](docs/PREFERENCES.md) | Settings + Cloudflare-ready Publish pane |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Folders → Settings → Finish → Deploy |
| [`docs/STATUS.md`](docs/STATUS.md) | What works now |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Boris / Solipsist boundary |
