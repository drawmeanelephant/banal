# Roadmap

Small surface. High finish. Publishing last.

Work is filed as cards in [`cards/README.md`](cards/README.md). One
card, one branch, one PR.

## M1 — Folders

The app becomes a notes app instead of a flat list with a sidebar costume.

- Recursive folder tree in the sidebar (real directories)
- New Folder (⇧⌘N), rename, trash, move
- New Note lands in the selected folder
- Drag notes between folders (filesystem move)
- Empty folders remain
- Tests: create/rename/move/external Finder mkdir

## M2 — Preferences

A real Settings window so Cloudflare can arrive without a redesign.

- General / Editor / Publish panes ([`PREFERENCES.md`](PREFERENCES.md))
- Vault bookmark picker in Settings
- Font, measure, sort
- Publish: site title, base URL, project name, account ID
- Keychain API token (store/replace/delete) — no deploy yet
- Disabled “Deploy to Cloudflare” with a copyable wrangler command

## M3 — Finish

Same features, AAA execution ([`QUALITY.md`](QUALITY.md)).

- Typography and measure
- Empty / dirty-external / missing-vault states
- Full menu bar, find, undo
- Light and dark, narrow and wide
- VoiceOver pass on the three columns + Settings
- Human pass in the running app (not only `swift test`)

## M4 — Oliver in the basement

Parse this buffer. Diagnostics. Optional Markdown preview. Still one silhouette. Do not start here if M1–M3 are soft.

## M5 — Textile and Cooklang as files

`.textile` and `.cook` in the vault. New Recipe / New Textile. Recipe **reading** view (ingredients, steps, display scale). No pantry. No meal plan.

## M6 — Publish for real

Only after M2’s pane exists.

- Mixed vault (md / textile / cook): Markdown through Boris when present; Textile/Cooklang via Oliver in the same `.publish/` folder
- Deploy uses Keychain token + saved project/account
- Graph stays in the compiler
- Still no Worker host, no R2 browser, no billing

## Explicitly not on the roadmap

Daily notes, wikilinks, graph, backlinks, plugins, Electron, AI chat, multi-vault windows-as-IDE, Solipsist Compose, hosted accounts.

If one of those becomes real, it gets a new milestone and a mission amendment — it does not sneak into M1–M3.
