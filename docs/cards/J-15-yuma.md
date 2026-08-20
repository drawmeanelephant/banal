# Card J-15 — Yuma — write & crash safety (Drive triage)

**Milestone:** M15 · **Lane:** core · **Status:** board · **Branch:** `fix/j15-yuma` · **Parent:** #112 · **Subissues:** #129 J-15a, #130 J-15b, #131 J-15c

## Handoff

- Board was blank until I-2 files this class (`docs/ROADMAP.md:211`). I-2 light sit passed `make smoke` (`dist/BANAL.app` ad-hoc) and `swift test` 265 green on `main` `613bb5d`; friend full sit still deferred.
- This is the border checkpoint at 115 °F — debounced atomic writes, caret stays, `NSUndoManager` per-note, `kill -9` never leaves a torn fence. Disk is still truth, not a journal.

## Owns

- `Sources/BANALCore/NoteStore.swift` (`writeDebounceNanoseconds:400_000_000`, `pendingWrites`/`writeTasks`, `scheduleWrite`/`finishWrite`/`flush`, `persistImmediately` → `NoteIO.write`)
- `Sources/BANALCore/NoteIO.swift` (`encode` → `FrontmatterCodec.serialize`/`CookMetadata.serialize`, `write` → `NSFileCoordinator.coordinate(.forReplacing)` + `.atomic`, `ContentFingerprint.sha256`)
- `Sources/BANALCore/Frontmatter.swift` (`Frontmatter`/`FrontmatterExtra`, `knownKeys`, `FrontmatterCodec.parse/serialize`, `extras` round-trip)
- `Sources/BANALCore/VaultConfiguration.swift`/`VaultConfigFile` (`VaultBootstrap.prepare/load/save` `.banal/config.json` `.atomic`, `reservedDirectoryNames`, unknown keys)
- `Sources/BANALApp/AppModel.swift` (`select` → `persistEditor` → `loadEditor` → `editorSessionID`/`loadedForID`/`loadedSessionID`, `applyEditorChanges` debounce, `flushEditor`, `isWritingToolsActive` guard)
- `Sources/BANALApp/Views/MarkdownTextView.swift` (`updateNSView` `documentID` → `CaretPlacement.preferred`, `undoManager.disableUndoRegistration` + `removeAllActions`, `applyWhisper` not on caret path)
- `Sources/BANALCore/CaretPlacement.swift` + `Tests/BANALCoreTests/CaretPlacementTests.swift`
- `Tests/BANALCoreTests/NoteStoreTests.swift` (F-9 no-bump, identical byte proof, flush)
- `docs/TESTING-WINDOW.md:112` §3/3b (30s type / switch / ⌘Z, Writing Tools) is the hand gate

## Do not touch

- Bookmark/lifecycle picker (`M13` `J-13`), FSEvents/dirty-clean/watch-off (`M14` `J-14`), latency/5k (`M16`), a11y full audit (`M17`), UTType/QL (`M18`), Copy/Help (`M19`)
- Second DB, journal, or background save that blocks typing
- Sync service, auto-merge, or SQLite index

## Why

If a write tears the fence, the folder outlives nothing (`HOPE-CHEST.md:18`). At Yuma every note is still a file — debounced, atomic, undo-isolated, and readable after `kill -9`.

## Do

### J-15a Debounced atomic saves + caret + per-note undo — 30s type never waits (#TBD)

1. Keep `NoteStore.writeDebounceNanoseconds=400_000_000` `NoteStore.swift:52` (0.4s) `scheduleWrite:499` (`pendingWrites[id]=note`, cancel prior `writeTasks[id]`, `Task.sleep(400ms)` → `finishWrite:510`), `flush:398` cancels tasks + `persistImmediately` synchronously for note switch/quit/publish, `writeTasks`/`pendingWrites` both `MainActor`.
2. Keep `NoteIO.write:67-87` → `NoteIO.encode:50` (`FrontmatterCodec`/`CookMetadata`) → `NSFileCoordinator.coordinate(.forReplacing)` `NoteIO.swift:73` + `Data.write(.atomic)` `NoteIO.swift:75` so the file is never visibly truncated; `persistImmediately:523` sets `recentlyWritten[id]=(fingerprint,+1.5s)` and `upsert` sorts by `updated`. No typing waits on `reindexSpotlight` or Oliver — those are background.
3. Keep caret sane: `AppModel.select:267` `persistEditor(to:old)` flushes debounce `store.update(..., debounce:false)` `NoteStore.swift:334`, then `loadEditor:959` rotates `editorSessionID=UUID()` `AppModel.swift:962` (`documentID` → `MarkdownTextView.updateNSView:148` `documentChanged=true`), `CaretPlacement.preferred` `Sources/BANALCore/CaretPlacement.swift:1` preserves offset (or 0 on new note), `undoManager.removeAllActions()` `MarkdownTextView.swift:164` so `⌘Z` is per-note. `applyWhisper` `MarkdownTextView.swift:289` and `scheduleOliverQuestion` are `0.4s` idle off caret path.
4. Keep Writing Tools guard: `applyEditorChanges:453`/`persistEditor:484` `guard !isWritingToolsActive` + `AppModel.isWritingToolsActive:41` from `MarkdownTextView.textViewWritingToolsWillBegin/DidEnd:265`.

### J-15b `kill -9` leaves frontmatter intact — no torn `---` fence (#TBD)

1. Keep `NoteIO.encode:50` single-string build (`FrontmatterCodec.serialize:166` `---\n...---\n<body>\n`) then single `Data.write(.atomic)` to `note.fileURL` `NoteIO.swift:75` under `NSFileCoordinator`. A `kill -9` between `encode` and `write` leaves old file; mid-`.atomic` rename leaves either old or new bytes — never a half-fence. Manual gate: `30s type → kill -9 $(pgrep BANAL)` → reopen → `FrontmatterCodec.parse` succeeds, `title`/`tags`/`published`/`created`/`updated` intact, body has last flushed paragraph not a truncated `---`.
2. Keep `VaultBootstrap.prepare:149` + `Welcome.md` `VaultConfiguration.swift:175` `.atomic` same guarantee for first note. Do not add a journal/WAL — atomic `Data.write` is the contract.

### J-15c `.banal/config.json` unknown keys round-trip + vault not recreated (#TBD)

1. Keep `VaultConfigFile:76` `Codable` with `decodeIfPresent ?? default` `VaultConfiguration.swift:121-128` and `JSONEncoder.pretty` `.sortedKeys` `VaultConfiguration.swift:207`, `VaultBootstrap.load:180`/`save:200` both `.atomic` `VaultConfiguration.swift:157,203`. Unknown top-level keys in `config.json` today are **not** preserved (pure `VaultConfigFile`), but `Frontmatter` extras **are** round-tripped `Frontmatter.swift:18,39`/`FrontmatterCodec.serialize:182` (only `!knownKeys`). For Yuma the gate is: extra keys in `.banal/config.json` must not be stripped on `save` after `Site title` change, and a vault deleted on disk is never silently recreated by `store.open` or `applyExternalChange`.
2. Keep `NoteStore.open:146` `throws .vaultNotDirectory` when `!isDirectory` `NoteStoreTests:135` and never `createDirectory` for missing vault; `applyExternalChange:419` `!rootExists -> rootMissing` not recreate; `VaultBookmark.createFolderIfAllowed` probe only after explicit `Documents/BANAL Notes` button, never at launch `Tests/BANALCoreTests/VaultBookmarkTests:50`. Add test that `VaultBootstrap.save` preserves unknown JSON keys if `I-2` files config-loss — otherwise document as known limitation and file `M15` follow-up (defer to El Centro audit).

**Tests to keep green:** `NoteStoreTests:testCreateUpdateAndTrash` `testIdenticalUpdateDoesNotBumpUpdated` `testUpdateWithStaleUpdatedButIdenticalFieldsIsNoop` `testUpdateWithRealChangeBumpsUpdatedAndPersists` `testOpenMissingDirectoryDoesNotCreateIt` `testApplyExternalChangeSetsRootMissingWhenVaultVanishes` `CaretPlacementTests` `ExternalEditTests` (isWritingToolsActive), `FrontmatterTests` extras round-trip.

## Do not

- Add a journal, WAL, or background save that blocks the caret (`isWritingToolsActive` guard must stay).
- Copy Solipsist compose / ship webview preview as editor; Oliver stays subprocess.
- Grow frontmatter beyond `knownKeys` `Frontmatter.swift:83` or store `banal-notes` project secrets in vault.

## Gate

1. **30s type → switch notes → ⌘Z** `TESTING-WINDOW.md:112`: type 30s in Welcome, `⌘Z`/`⇧⌘Z` in-note, click other note type word `⌘Z` undoes that word only, switch back Welcome text still there and its `⌘Z` does not replay the other note. Caret never jumps, no hitch on save. Writing Tools dictation/rewrite in `NSTextView` not clobbered by `scheduleOliverQuestion`/`applyWhisper`.
2. **`kill -9` mid-save**: type paragraph, `kill -9` within `0.4s` debounce or during `persistImmediately` → reopen vault → file parses, `Frontmatter` intact, no `---` truncation, last flushed edit present or cleanly absent — never half YAML.
3. **Config**: add `"extraKey": "keep me"` to `.banal/config.json`, change `Site title` in Settings → `save` → reopen → `extraKey` still there **or** documented as not-yet-round-tripped with failing test marked `xfail` — no silent delete of vault dir.
4. `swift test` green; `grep -rn "SQLite\|WAL\|journal" Sources` zero.

## Failure is a torn fence

Any path where `NoteIO.write` is not `.atomic` under `NSFileCoordinator`, or `NoteStore.update` bumps `updated` on identical `title/body/tags/published/extras`, or `select` does not `flush` + reset undo (`MarkdownTextView.swift:164`), or a vanished vault is recreated without explicit `Choose…`, fails `J-15`.
