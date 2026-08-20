# Card J-14 — Gila Bend — external truth (Drive triage)

**Milestone:** M14 · **Lane:** core · **Status:** landed — `686d972` (#127) · **Branch:** `fix/j14-gila-bend` · **Parent:** #111 · **Subissues:** #123 J-14a, #124 J-14b, #125 J-14c, #126 J-14d — closed

## Handoff

- **Landed `686d972` (#127) — all 4 slices verified green.** `fix/j14-gila-bend` → `main`. Subissues #123-#126 closed, parent #111 closed. `swift test` 265 green pre-merge, same on `main` post-merge.
- **What shipped:** `NoteStore.update:351` now includes `extras` in F-9 guard; `NoteStore.reloadAll:169` evicts `ingredientCache`/`recentlyWritten` for vanished ids; `AppModel.reconcileExternalSelection:506` `bufferMatches` now includes parsed `tags` + `loadedExtras` (was title/body/published only); `loadedExtras` tracked via `loadEditor:972`/`persistEditor:498`. See `Sources/BANALApp/AppModel.swift:506` + `Sources/BANALCore/NoteStore.swift:169`.
- Board was blank until I-2 files this class (`docs/ROADMAP.md:211`). This card owned the gas station: `FSEvents` + `NSFilePresenter` vs disk — now proven.

## Owns

- `Sources/BANALCore/DirectoryMonitor.swift` (`FSEvents` `kFSEventStreamCreateFlagFileEvents|UseCFTypes|NoDefer` + `NSFilePresenter` `presentedSubitemDidChange/Appear` + `accommodatePresentedSubitemDeletion`, `pending:Set<URL>` debounce `0.15s`)
- `Sources/BANALCore/NoteStore.swift` (`watchesExternalEdits`, `rootMissing`, `applyExternalChange(at:)`, `handleNoteURLChange`, `shouldIgnoreExternalWrite`, `recentlyWritten:1.5s`, `reloadAll`/`refreshFolders`/`collectFolderPaths`, `update(_:debounce)` F-9 guard)
- `Sources/BANALCore/ExternalEdit.swift` (pure `action(selectedStillOnDisk:dirty:loadedFingerprint:diskFingerprint:bufferMatchesDisk:isWritingToolsActive:)`)
- `Sources/BANALCore/Note.swift`/`NoteIO.swift`/`ContentFingerprint` (`contentFingerprint` SHA-256 of bytes)
- `Sources/BANALApp/AppModel.swift` (`loadedForID`/`loadedSessionID`/`editorSessionID`, `editorDirty`/`loadedFingerprint`/`warnedDiskFingerprint`, `applyEditorChanges`/`persistEditor` guards, `reconcileExternalSelection` strip, `isWritingToolsActive`, `store.watchesExternalEdits` binding)
- `Sources/BANALCore/VaultConfiguration.swift`/`Folder.swift` (`FolderTree.build`, `isNoteFile`, `isReservedDirectory`, empty dirs)
- `Sources/BANALApp/Views/MarkdownTextView.swift` (Writing Tools delegate `textViewWritingToolsWillBegin/DidEnd`)
- `Tests/BANALCoreTests/ExternalEditTests.swift`, `Tests/BANALCoreTests/NoteStoreTests.swift` (vanish, `watchesExternalEdits` false, F-9 no-bump)
- `docs/TESTING-WINDOW.md:140` §4 is the gate script

## Do not touch

- Bookmark lifecycle / first-run / vanish-while-open picker (`M13 Casa Grande` `J-13` — `VaultBookmark.swift`, `NotesFolderAccess.swift`, `ContentView.swift:12` `VaultPicker`, `AppModel.swift:144` `$rootMissing`)
- Atomic/crash safety (`M15 Yuma` — `NoteIO.write` `.atomic`, torn frontmatter)
- Latency/5k vault (`M16 El Centro` — `WhisperScan` off caret path, Spotlight throttle)
- Full a11y re-audit (`M17 Niland`), UTType/QuickLook/Print (`M18`), Copy/Help re-sit (`M19`)
- Second DB, sync service, auto-merge, SQLite index

## Why

Disk is truth only if the window never disagrees with Finder, even when Vim, Finder, or iCloud touch the file mid-type at 115 °F. One coalesced monitor, no second index, empty folders still show, dirty keeps your buffer with one sentence, clean reloads, watch-off still sees death, and a stale echo never bumps `updated:`. If this lies, the folder does not outlive the app (`HOPE-CHEST.md:18`).

## Do

### J-14a Monitor coalesce + disk truth + empty folders — no second DB (#TBD)

1. Keep `DirectoryMonitor.start(url:handler:)` (`DirectoryMonitor.swift:38-77`): `FSEventStreamCreate` with `FileEvents|UseCFTypes|NoDefer`, `kFSEventStreamEventIdSinceNow`, `debounceInterval:0.15s`; `NSFileCoordinator.addFilePresenter` `DirectoryMonitor.swift:45`, `stop` removes presenter `DirectoryMonitor.swift:85`. `presentedSubitemDidChange/Appear` `accommodatePresentedSubitemDeletion` + `FSEvents` callback all `enqueue` `DirectoryMonitor.swift:102-151`.
2. Keep `enqueue:120-132` coalesce: `pending:Set<URL>` `standardizedFileURL`, cancels prior `DispatchWorkItem`, `callbackQueue.asyncAfter(0.15s)` `flush:134-142` delivers `[URL]` batch once. `NoteStore.startMonitor:457-465` loops `for url in urls { applyExternalChange }` — batch not single.
3. Keep `applyExternalChange:417-448` disk-truth rules: `isReloading` guard, `!rootExists -> rootMissing=true, notes=[], folderTree=[]` `NoteStore.swift:419-423` even when `watchesExternalEdits==false` (vanish is not an edit); `rootMissing==true -> false` on reappear `NoteStore.swift:425`; reserved `.banal`/`.publish` skip `NoteStore.swift:431-433`; `isNoteFile -> handleNoteURLChange` `NoteStore.swift:435`, else directory -> `reloadAll` `NoteStore.swift:443` then `refreshFolders:662` / `collectFolderPaths:666-690` enumerates **every** directory (including empty), skips hidden/reserved, builds `FolderTree.build`.
4. No SQLite/second index: `recentlyWritten:[String:(fingerprint,until)]` 1.5s `NoteStore.swift:43,525` + `shouldIgnoreExternalWrite:489-497` dedup own echo + identical fingerprint; `ingredientCache` `NoteStore.swift:47` disposable,Validated by `contentFingerprint`. Spotlight `NoteSpotlightIndexer` reindex `NoteStore.swift:621` disposable.
5. Empty folders still show: Finder `mkdir "Empty Sit"` or `mkdir -p A/B/C` externally must appear in sidebar within one beat without restart or `bootstrap()`. Covered by directory -> `reloadAll` path.

### J-14b Dirty keeps buffer / clean reloads + one-sentence status strip (#TBD)

1. Keep `ExternalEdit.action:15-39` pure (`ExternalEditTests.swift:5-112`): `isWritingToolsActive -> .keepBuffer`, `!selectedStillOnDisk -> .noteGone(keepBuffer:dirty)`, `diskFingerprint==loadedFingerprint -> .ignore`, `bufferMatchesDisk==true -> .ignore`, `dirty==true -> .keepBuffer`, else `.reload`. Buffer-matches-disk wins even when dirty (own echo).
2. Keep `AppModel.reconcileExternalSelection:504-535` wired via `store.$notes` sink `AppModel.swift:144`: `.ignore` clears `editorDirty` if `bufferMatches` and updates `loadedFingerprint`; `.reload -> loadEditor(from:disk)`; `.keepBuffer -> statusMessage="This file changed on disk. Your edits were kept."` `AppModel.swift:527` deduped by `warnedDiskFingerprint:66`; `.noteGone(keep=true) -> "This file was moved or deleted. Your edits were kept."` `AppModel.swift:531`, `keep=false -> select(first)`.
3. Clean Vim reloads: open note, do not type, `echo 'FROM VIM' >> file.md` or Vim `:w` -> BANAL reloads, `Title`/`body`/`tags`/`published` from disk, `loadEditor` resets `editorDirty=false`, `loadedFingerprint` updated `AppModel.swift:959`.
4. Dirty Vim keeps buffer: type `DIRTY` (do not save), Vim saves different line -> disk fingerprint differs, `dirty==true` -> `.keepBuffer`, buffer not overwritten, one sentence strip `StatusStripView.swift:40` dismisses `3.5s` `AppModel.swift:804`, `warnedDiskFingerprint` prevents spam on repeated Vim saves.
5. Writing Tools shield `ExternalEdit.swift:23` + `AppModel.swift:41,514` + `MarkdownTextView.swift:265-271` `textViewWritingToolsWillBegin/DidEnd` sets `isWritingToolsActive`; `applyEditorChanges:453` + `persistEditor:484` `guard !isWritingToolsActive else return`.

### J-14c Watch toggle honesty — off still sees vanish (#TBD)

1. Keep `AppPreferences.watchExternalEdits:AppPreferences.swift:16` default `true`, `GeneralSettingsPane` `Toggle("Watch for edits from other apps")` `SettingsRoot.swift:64` -> `AppModel.savePreferences:421-423` `store.watchesExternalEdits = preferences.watchExternalEdits`; bootstrap `AppModel.init:96` + `openVault:819`.
2. Keep `applyExternalChange:428` early return `if !watchesExternalEdits { return }` **after** root check `NoteStore.swift:418-428` so `Tests/BANALCoreTests/NoteStoreTests.swift:163-193` both hold: `testWatchesExternalEditsFalseIgnoresNoteWrites` (new `ignored.md` not indexed, `rootMissing==false`) and `testWatchesExternalEditsFalseStillSeesVanishedFolder`.
3. Gate `TESTING-NOTES-FOLDER.md:137` + `TESTING-WINDOW.md:4` third bullet: turn toggle off, Vim edit open note -> **no** reload (dirty/clean irrelevant), but Trash/rename vault while open still dumps to `This notes folder is missing.` `ContentView.swift:12` even with toggle off. Directory/file creates outside toggle-off remain ignored by design (not vanish).

### J-14d F-9 session guard + identical no-bump — 10/10 byte-identical imports (#TBD)

1. Keep editor write session guard `AppModel.swift:70-71` `loadedForID:String?` / `loadedSessionID:UUID` set in `loadEditor:951-953` (`loadedForID=selectedID`, `loadedSessionID=editorSessionID` fresh `UUID`), checked in `applyEditorChanges:453-456` `selectedID==loadedForID && editorSessionID==loadedSessionID` and `persistEditor:484-487` same + `!isWritingToolsActive`. `select:267-272` `persistEditor(to: old)` then `loadEditor` rotates session so `onChange` echo from previous load cannot write into new note.
2. Keep `NoteStore.update:334-363` F-9 guard: `guard existing.title!=note.title || body!= || tags!= || published!= else return` `NoteStore.swift:351-354` — stale `updated` alone is no-op, file not touched, `extras` also compared (covers unknown frontmatter keys round-trip `Frontmatter.swift:83`). If real change, `next.updated=Date()` `NoteStore.swift:357`, `ingredientCache.remove` `NoteStore.swift:355`, `upsert` + `scheduleWrite`/`writeImmediately`.
3. Keep `NoteIO.write:67-87` `coordinate(.forReplacing)` + `.atomic` so `kill -9` mid-save never leaves truncated fence; caller `persistImmediately:523-526` sets `recentlyWritten[id]=(fingerprint,+1.5s)` `NoteStore.swift:525`, `upsert` sorts by `updated`.
4. Keep `shouldIgnoreExternalWrite:489-497` both `recentlyWritten` fingerprint+until and `existing.contentFingerprint==loaded.contentFingerprint` so own save echo + identical external write are `.ignore`.
5. Gate `NoteStoreTests:53-114` `testIdenticalUpdateDoesNotBumpUpdated`, `testUpdateWithStaleUpdatedButIdenticalFieldsIsNoop` (byte-identical `Data`), `testUpdateWithRealChangeBumpsUpdatedAndPersists` all green; plus `10/10` loop `store.importFile` byte-identical proof (`ContentFingerprint.sha256` `NoteIO.swift:46,84` `Note.swift:60`).
6. Jam fix in this card (before close): `ingredientCache` must not survive deletion — `handleNoteURLChange:469-473` already removes, but `reloadAll:158-173` rebuild after directory events currently does **not** evict cache for vanished ids. Add `ingredientCache = ingredientCache.filter { notes.map(\.id).contains($0.key) }` or remove on reload. And external rename of selected file when clean should follow new path if fingerprint matches — `reconcileExternalSelection` will handle via `noteGone` + new `id` with same fingerprint (defer auto-select only when clean). Ensure `extras` included in guard.

**Tests to keep green:** `ExternalEditTests:*` 8, `NoteStoreTests:testExternalWriteIsPickedUpOnReload` `testIdenticalUpdateDoesNotBumpUpdated` `testUpdateWithStaleUpdatedButIdenticalFieldsIsNoop` `testUpdateWithRealChangeBumpsUpdatedAndPersists` `testApplyExternalChangeSetsRootMissingWhenVaultVanishes` `testWatchesExternalEditsFalse*` `testFilesystemMonitorObservesExternalCreate`, `FolderTests` external change, `WhisperScan` not on caret path.

## Do not

- Add sync service, auto-merge, SQLite index, or OT/CRDT.
- Copy Solipsist `Sources/Compose`/inspector or ship webview preview as editor; Oliver stays subprocess `OliverDebounce`.
- Pretend folders: create/rename/move/trash must be `FileManager` FS ops Finder sees.
- Grow frontmatter beyond `title`/`created`/`updated`/`tags`/`published` (`Frontmatter.knownKeys` `Frontmatter.swift:83`), unknown extras round-trip only.
- Store Cloudflare tokens in vault/git; Keychain only.

## Gate

`docs/TESTING-WINDOW.md:4` verbatim + Stale-bump gate:

1. **Clean** open note, no typing, `echo 'FROM VIM' >> file.md` or Vim `:w` with different line -> BANAL reloads line, `loadEditor` clean, no strip.
2. **Dirty** open note, type `DIRTY`, Vim save *different* line -> BANAL keeps `DIRTY`, `StatusStripView` one sentence `This file changed on disk. Your edits were kept.`, list row not overwritten, `⌘Z` still local.
3. **Watch off** `Settings -> General -> Watch for edits from other apps OFF` -> Vim edit does **not** reload open note; Finder Trash/Rename vault while open **still** dumps to `This notes folder is missing.` within FSEvents beat, list empty, no ghost write `AppModel.flushEditor:477` guards `store.rootMissing`.
4. **F-9** switch notes, type in A, quickly click B then type — `applyEditorChanges` does not write into A (`loadedForID` mismatch) `AppModel.swift:453`; `store.update` stale `updated` alone is no-op; `10/10` `importFile` same file twice -> `draft-2.md` not overwrite, bytes identical `NoteStoreTests:247`.
5. **Empty folders** Finder `mkdir` empty `Empty Sit` externally -> sidebar shows it with no note move/restart; `FolderTree.build` `Folder.swift:66`.
6. `swift test` green; `make smoke` open still `TESTING-NOTES-FOLDER.md:140` vanish while open.

## Failure is silent overwrite

Any branch where a dirty buffer is overwritten by `handleNoteURLChange:476-483` without `ExternalEdit.keepBuffer`, or `NoteStore.update:357` bumps `updated` when `title/body/tags/published/extras` unchanged, or `DirectoryMonitor` delivers without coalesce (double `upsert` or missing `pending` dedup), fails `J-14`. `grep -rn "second.*DB\|SQLite\|autoMerge"` must be zero.
