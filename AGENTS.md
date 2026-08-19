# Agent rules — BANAL

This file is binding project policy for AI coding agents and anyone pairing with them.

BANAL is a **native macOS notes app**. It is not Solipsist, not Boris, not a knowledge graph, and not a hosting dashboard. If a change would make the app feel like a productivity suite, stop.

## Session start

1. Read [`docs/NORTH-STAR.md`](docs/NORTH-STAR.md). Implement that feeling. Do not write another manifesto.
2. Pick **one** card from [`docs/cards/README.md`](docs/cards/README.md).
3. Run `swift test` after Swift changes.
4. Open thesis / quality / prefs only when the card needs them.

## Identity

BANAL is **notes in folders on disk** — including recipes.

- One vault: a user-chosen directory. Extensions are languages: `.md` Markdown, `.textile` Textile, `.cook` Cooklang.
- Folders on disk are folders in the sidebar. No virtual notebooks, no tags-as-structure, no graph UI.
- The editor is always source (SwiftUI chrome + AppKit `NSTextView` / TextKit). Oliver answers parse/preview questions. Zero Electron. Zero webviews in the editing loop. A recipe **reading** view is allowed; it is not a second app.
- Oliver owns markup. Boris owns the site graph and publish. Neither owns the window.
- Publishing is optional, explicit, and late. Local notes must work forever with Cloudflare credentials unset.
- Recipes are notes that happen to be dinner. No pantry, meal calendar, or grocery SaaS.

The long picture is [`docs/THESIS.md`](docs/THESIS.md). Named casually — *Boris as Notes App, lawl* — but the bar is not casual: dead simple looking, fluent files, superhappyfuntimes after a paragraph *or* a risotto.

## Hard constraints

Do not violate these unless the user explicitly requests a deviation.

1. **Do not copy Solipsist.** Especially not `Sources/Compose`, the inspector, companions, or any WKWebView preview of `boris watch`. Reimplement Mac patterns here.
2. **Do not rewrite Boris or Oliver.** Call them (subprocess or a later linked library). Do not vendor the Svelte editor, do not reimplement CommonMark/Textile/Cooklang in Swift, do not copy Solipsist Compose.
3. **Do not make it AI-first.** No chatbot pane, no auto-link knowledge graph, no RAG UI, no “ask your notes.”
4. **Do not make it a dashboard.** No multi-pane analytics, no kanban, no calendar, no backlinks map as a product surface.
5. **Do not pretend folders.** A folder is a directory. Create, rename, move, and trash must be filesystem operations the user can see in Finder.
6. **Do not require the network** for creating, editing, searching, or organizing notes.
7. **Do not store Cloudflare tokens in the vault or in git.** Keychain only. Preferences hold *names and IDs*, never secrets.
8. **Do not grow frontmatter into YAML 1.2.** Local keys stay small (`title`, `created`, `updated`, `tags`, `published`). Publishing maps onto Boris’s closed grammar. Unknown extra keys round-trip; they are not a plugin API.
9. **Do not add a second notes database.** No SQLite index that can disagree with disk. Disk is truth. Caches must be disposable.
10. **Do not ship a webview as the editor.** Preview, if it ever exists, is secondary and may not replace TextKit.

## Product surface (this is the whole app)

| Surface | Job |
| --- | --- |
| Sidebar | Vault folders (nested), All Notes, Published, maybe tags as a *filter* not a place |
| List | Notes in the current folder or filter, sorted, instant search |
| Editor | Title + body. Fast. Undo. Standard Mac text behavior |
| Settings | Vault, editor, and a Publish pane. Deploy is a menu item, optional |
| Menus + shortcuts | If it is not in the menu bar, it is not a feature |

That is the app. Features that do not fit this table need a written exception in `docs/STATUS.md` before code.

## Where to edit

| Task | Live here |
| --- | --- |
| Note model, frontmatter, vault paths, FSEvents | `Sources/BANALCore/` |
| Folder create / rename / move / trash | `BANALCore` first, then sidebar UI |
| Editor, split view, menus, Settings | `Sources/BANALApp/` |
| Staging, Boris CLI, RSS, wrangler plan | `Sources/BANALPublisher/` |
| Preferences schema | `docs/PREFERENCES.md` and `VaultConfiguration` / Settings views |
| Quality bar (spacing, type, motion) | `docs/QUALITY.md` — implement against it, do not lower it |

## Implementation taste

- Prefer the filesystem over a clever model.
- Prefer one obvious Settings window over scattered toggles.
- Prefer standard AppKit/SwiftUI controls over custom chrome.
- Prefer deleting UI to adding a preference.
- Match existing Swift 6, `@MainActor` store, and atomic writes.
- New behavior gets a test in `Tests/` when it touches files, frontmatter, folders, or publish mapping.
- Visual work is not done until it has been exercised in the running app, not only compiled.

## Git

- Do not commit or push to `main` unless the user explicitly says to.
- One concern per branch. Prefixes: `feat/`, `fix/`, `docs/`, `ui/`, `chore/`.
- Do not commit `.build/`, `.swiftpm/`, DerivedData, or vault contents from your machine.
- Do not rewrite published history.

## Quick “should I?”

| Idea | Default |
| --- | --- |
| Nested folders that are real directories | **Yes** |
| Drag a note into a folder | **Yes** |
| Settings pane for site title, project name, account id | **Yes** |
| Keychain slot for a Cloudflare API token | **Yes**. Deploy is File → Deploy to Cloudflare when token + project exist |
| Tags as the primary organizer | **No** — folders first; tags are optional filters |
| `.cook` / `.textile` as ordinary files + recipe reading view | **Yes** (after the Markdown silhouette works) |
| Wikilinks, backlinks graph, daily notes ritual | **No** |
| Pantry, meal plan, shopping-list product | **No** |
| Copy Solipsist Compose into the editor | **No** |
| WKWebView Markdown preview as the editor | **No** |
| In-app Cloudflare Worker / R2 multi-tenant host | **No** |
| Electron, Tauri, or a website pretending to be the app | **No** |
| Subscription, accounts, sync service of our own | **No** — the folder *is* the sync story (iCloud Drive / syncthing / git, user’s choice) |

## When you change behavior

- Update `docs/STATUS.md` if the phase or the “what works” list changed.
- Update `docs/PREFERENCES.md` in the same change if you add or rename a setting.
- Add a line to `CHANGELOG.md` under `[Unreleased]` for user-visible work.
- `swift test` must stay green.

## Long-term direction

The destination is a **small, finished Mac app**: a person opens a folder, writes, files notes into folders, and once in a while publishes the marked ones to a static site on Cloudflare Pages via Boris.

AAA here means restraint plus finish — not more surfaces. Typography, latency, keyboard, empty states, and folder operations should feel inevitable. Publishing should feel like Export, not like onboarding a SaaS.
