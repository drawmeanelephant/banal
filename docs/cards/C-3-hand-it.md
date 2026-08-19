# Card C-3 — Hand it to someone

**Milestone:** M7 · **Lane:** app · **Depends:** C-1 · **Status:** landed — ad-hoc signed `.app` + sandbox

## Handoff

- **Landed:** `make app` writes `dist/BANAL.app` (0.1.0), sandbox on,
  app icon, ad-hoc signed (`codesign -s -`). No Developer ID on the
  build machine; **not notarized**. Bookmarks are app-scoped: save
  stores bookmark + path, restore calls `startAccessing`, quit
  `stopAccessing`. A vanished folder is not recreated. Boris/Oliver
  stay PATH + Settings (C-2); user-chosen binaries get their own
  bookmarks so the sandbox can still run them. `swift run` is still
  unsandboxed.
- **Not this card:** fluency ([D-1](D-1-whisper.md)–[D-4](D-4-find.md)), a
  website, notarization-as-a-product, auto-update SaaS.

## Owns

- App icon
- Signed `.app` build (Developer ID or local sign — say which)
- App sandbox + security-scoped bookmarks that still open a
  user-chosen notes folder
- First-run and missing-folder under sandbox (re-sit
  [`../TESTING-NOTES-FOLDER.md`](../TESTING-NOTES-FOLDER.md))

## Do not touch

- Embedding Boris or Oliver in the bundle “so it just works”
  unless the sit proves we must — prefer PATH + Settings (C-2)
- iCloud Drive as a service we operate
- Sparkle / a fourth Settings pane for updates

## Why

The files are the destiny. The Mac app is supposed to be yours
too. A friend cannot `swift run` their way into a notes folder.
Sandbox is how we find out whether bookmarks and the picker
were real.

## Do

1. An icon that looks like a finished Mac app, not a WWDC
   placeholder. One image, system appearance.
2. A signed `.app` someone can drag to `/Applications`. Version
   may stay 0.x.
3. Sandbox on. User-selected file access and app-scoped
   bookmarks. Notes folder still works after quit.
4. Re-sit first-run, missing folder, vanish-while-open, publish
   to `.publish/`, optional deploy. Fix what sandbox breaks.
5. Document the build in the README. `swift test` remains the
   contract for storage and publish.

## Do not

- Ship an unsigned zip and call it the app.
- Recreate a vanished notes folder “because sandbox is hard.”
- Vendor wrangler, Node, or a Cloudflare dashboard.

## Gate

A friend who does not have this checkout opens a folder, writes,
files, cooks risotto, optionally publishes. Bookmarks survive
quit. Local notes never need a token.
