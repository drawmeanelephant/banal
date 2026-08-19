# BANAL architecture

BANAL is a local-first native macOS notes app. Notes are ordinary Markdown files. Publishing is optional and talks to Boris as an external compiler.

Product intent, quality bar, and Settings live elsewhere — this file is only the Boris / Solipsist / storage boundary.

- [`THESIS.md`](THESIS.md) — how this wins (simple window, Oliver markup, Boris site)
- [`MISSION.md`](MISSION.md) — what the app is
- [`QUALITY.md`](QUALITY.md) — AAA finish
- [`PREFERENCES.md`](PREFERENCES.md) — Settings + Cloudflare-ready fields
- [`ROADMAP.md`](ROADMAP.md) — folders, then prefs, then finish, then deploy
- [`../AGENTS.md`](../AGENTS.md) — binding agent rules

## Clean separation

| Product | Role | This repo |
| --- | --- | --- |
| **Boris** | Zig documentation compiler. Markdown → validated HTML site. Closed frontmatter grammar, Apex Markdown, layouts, watch mode. | Not vendored. Invoked as a binary when present. |
| **Oliver** | Zig markup library. Markdown / Textile → document; Cooklang → Recipe; deterministic HTML. | Not vendored. `OliverClient` runs `oliver render --from markdown` when present. Cooklang Read uses `serialize --from cooklang --json` and `scale --from cooklang`; scaled text is never written. |
| **Solipsist** | Native Mac wrapper around Boris for documentation authoring. Owns Compose, the content graph inspector, companions, and engine embedding. | Not imported. No Swift sources copied. |
| **BANAL** | Notes app. Owns the vault, the editor, and an isolated publisher adapter. | This repository. |

Confirmed by inspection of:

- `drawmeanelephant/banal` — empty product repo (LICENSE + Xcode gitignore only) before this scaffold.
- `drawmeanelephant/boris/main` — slim v0.8.0 compiler used by this MVP. Contracts under `docs/contracts/`, CLI in `src/cli.zig`. No RSS, no `published_at`, no AppKit.
- `drawmeanelephant/boris/worktrees/freebuff` — fuller v0.8.1 product (Oliver, `published_at`/`summary`, `boris --rss`, `boris.json`, Svelte editor, Cloudflare Worker host). Not a dependency of this MVP.
- `drawmeanelephant/solipsist/worktrees/grok-base` — XcodeGen app with `Sources/Compose`, `Sources/Engine`, `Sources/App`. No BANAL mention.

No Solipsist module is a dependency. No Compose type, view, or coordinator appears here.

## Reuse ledger (from Boris)

Reused **as contracts and CLI**, not by copying Zig into the app:

| Boris surface | Path inspected | How BANAL uses it |
| --- | --- | --- |
| Closed frontmatter *style* (fence `---`, `key: value`, `tags: [a, b]`) | `docs/contracts/frontmatter.md`, `src/parser.zig` | Local notes use a **different key set**. Publisher maps onto Boris keys. |
| `status: draft \| published \| archived` | `src/page.zig` `Status` | Local `published: true` → staged `status: published`. |
| HTML compile CLI | `src/cli.zig` | `boris --input content --html-dir <out> --html-layout layouts/main.html --quiet` |
| Layout slots `{{title}} {{nav}} {{content}}` | `layouts/main.html` | Bundled theme in `BorisAdapter.BundledTheme` follows the same markers. |
| Default content root `content/` | CLI defaults | Staging tree uses `content/` + `layouts/`. |
| Page-local assets `{stem}.assets/` | `docs/contracts/content-local-assets.md` | Documented; MVP copies the vault's flat `assets/` folder next to the theme. |
| Watch debounce idea (100–150 ms) | `docs/contracts/watch-mode.md` | Independent FSEvents monitor in `DirectoryMonitor`. |

## Deliberately omitted (from Boris)

| Omitted | Why |
| --- | --- |
| Trunk / Satellite graph, `parent`, `relations` | Notes app, not a documentation graph. |
| RAG, Context Bundle, `llms.txt` | User asked for no AI-first tool. |
| Multi-target isolated output, layout rules | Hosting complexity. |
| `hosts/cloudflare-worker` (Wasm compile + R2 upload tollbooth) | Multi-tenant host glue. BANAL writes static files and an optional wrangler plan instead. |
| `editor/` (Zig + Svelte web UI) | User asked for zero webviews in the editing loop. |
| Migration labs (WordPress, Notion, Obsidian, Starlight) | Out of scope. |
| Textile adapter, Apex C ABI in-process | BANAL does not embed Zig. |
| Incremental cache / PageDb | Publisher is a batch compile of marked notes. |

## Deliberately omitted (from Solipsist)

| Omitted | Why |
| --- | --- |
| `Sources/Compose` and any Compose implementation | Explicitly forbidden. |
| Engine embedding, `embed-boris.sh`, sandbox entitlements copy | Different product. |
| Inspector, companions, Play, content graph chrome | Not a documentation IDE. |
| WKWebView preview of `boris watch --serve` | Not the notes editing loop. |

Native Mac patterns (menus, `NSTextView`, security-scoped bookmarks, `NSFilePresenter`) are reimplemented here, not copied.

## Storage contract

Vault (user-chosen folder, default `~/Documents/BANAL Notes`):

```
<vault>/
  Welcome.md
  2026-08-18-untitled.md
  assets/            # flat media
  .banal/config.json
  .banal/stage/      # publisher scratch
  .publish/          # last site artifact
```

Each note is UTF-8 Markdown with optional frontmatter:

```markdown
---
title: Shopping
created: 2026-08-18T16:00:00Z
updated: 2026-08-18T16:30:00Z
tags: [life]
published: false
---

Body…
```

Filesystem is truth. `DirectoryMonitor` uses FSEvents + `NSFilePresenter`. Writes are atomic and coordinated.

### Why local keys ≠ Boris keys

Boris rejects unknown keys (`EFRONTMATTER`). The product asked for `created`, `updated`, and `published: Bool`. Those are not in Boris's closed set (`id`, `title`, `parent`, `status`, `tags`, `relations`).

`BANALPublisher` stages a Boris-legal tree: drop `created`/`updated`, map `published: true` → `status: published`, only copy published notes.

## Modules

```
BANALCore        Note, Frontmatter, NoteStore, DirectoryMonitor, vault layout
BANALPublisher   BorisAdapter, SiteCompiling (builtin + Boris CLI), RSS, Cloudflare plan
BANALApp         SwiftUI NavigationSplitView + AppKit NSTextView
```

Publishing never runs during typing. File → Publish Site… (⇧⌘P) is explicit.

## Deferred

The product sequence is [`ROADMAP.md`](ROADMAP.md): **folders → Settings → finish → deploy**. Do not pull these forward ahead of that.

Later, if ever: live preview (not a webview editor), freebuff `published_at`/`summary`/`--rss`, `{stem}.assets/`, signed `.app`, importers as file copy. Never: wiki-graph, Solipsist Compose, Cloudflare Worker host.

## Tests

- `BANALCoreTests` — frontmatter, file serialization, store, external-change sync, FSEvents.
- `BANALPublisherTests` — Boris mapping, builtin SSG + RSS, optional live Boris binary, wrangler plan.
