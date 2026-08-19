# Card F-8 — File associations and Open With

**Milestone:** M10 · **Lane:** system · **Status:** landed — implemented + unit-tested; the GUI gate (Open With → BANAL, Dock drag) is a human pass on a real machine

## Handoff

- **Landed (issue #44, pulled forward).** `Info.plist` declares `CFBundleDocumentTypes`
  (Markdown `net.daringfireball.markdown`, Textile `org.textile.markup`, Cooklang
  `com.cooklang.recipe`, role Editor) plus `UTImportedTypeDeclarations` for
  textile/cooklang so the extensions map to their UTIs. `LSHandlerRank` is
  `Alternate` — BANAL appears under Open With without hijacking `.md` from the
  user's main editor.
- `BanalAppDelegate.application(_:openFiles:)` is the one route for Finder
  double-click, Open With, and Dock drags (no `.onOpenURL`, so one action can
  never import twice). Events before the window appears are queued in the
  delegate; files opened before a notes folder exists are queued in `AppModel`
  and imported once `bootstrap()` opens a vault.
- Open behavior: file inside the vault → select it and focus the editor; file
  outside → `NoteStore.importFile` copies it into the vault root (unique `-2`
  name on collision, source left untouched, extension decides language) and
  selects it; unsupported extensions and folders are rejected with a spoken
  status message.
- Tests: `NoteStoreTests` — copy-in with source untouched, unique name on
  collision, unsupported extension throws, inside-vault throws, import into a
  folder. `swift test` green; `make smoke` green.
- **Not this card:** quick look preview generation (F-4), bulk folder import UI
  (G-3).

## Owns

- `Supporting/Info.plist` (`CFBundleDocumentTypes`, `UTImportedTypeDeclarations`)
- `Sources/BANALApp/BanalApp.swift` (`application(_:openFiles:)` + delegate queue)
- `Sources/BANALApp/AppModel.swift` (`openExternalNote`, pending-import queue)
- `Sources/BANALCore/NoteStore.swift` (`importFile`)

## Do not touch

- Direct filesystem truth (disk is truth — import is a copy, never a cache)
- Multi-vault simultaneous sessions

## Why

BANAL is an app for notes on disk. When a user double-clicks a `.md`,
`.textile`, or `.cook` file in Finder, selects "Open With → BANAL", or drags a
note onto the BANAL Dock icon, the app should launch, open the file, and place
the caret right in the source.

## Do

1. Declare `CFBundleDocumentTypes` in `Info.plist` (done — see Handoff).
2. Handle open events in `BanalApp.swift` (done — one route, queued until the
   model and the vault exist).
3. Support dragging `.md`, `.textile`, or `.cook` files onto the BANAL Dock
   icon (done — the same `openFiles` route).

## Do not

- Create a custom temporary file sandbox cache that gets out of sync.
- Block the app launch if opening an invalid file path.

## Gate

Right-click `recipe.cook` in Finder → Open With → BANAL. BANAL launches and
opens the recipe in the editor. Drag `draft.md` onto the BANAL Dock icon: the
note opens in BANAL. `swift test` stays green.

**Mini-sit (human):** on a real machine, Open With → BANAL on a `.cook` and a
`.md`, and a Dock drag of a file outside the vault — expect the note selected
with the caret in source, and a copy in the vault root.
