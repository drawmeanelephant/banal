# Card J-16 — El Centro — latency & large vault (Drive triage)

**Milestone:** M16 · **Lane:** app · **Status:** landed — `4378a6a` + `f0580eb` snack · **Branch:** `fix/j16-el-centro` · **Parent:** #113 · **Subissues:** #134 J-16a, #135 J-16b, #136 J-16c — verified

## Handoff

- `main` at `b522866` (J-16 board cut `56170ae`). `swift test` 265 green, `make smoke` passed. I-2 light sit still the human gate; El Centro is flat and hot — 5k notes must not stall the caret.
- Snacks landed on this branch: `Scripts/gen-5k-vault.sh` (El Centro 5k) + `hiutil` `BANAL.cshelpindex` (Help first-class) — `Makefile:45` already runs `hiutil -I corespotlight -Caf` into `$(HELP_BOOK_LOCALE)/BANAL.cshelpindex` on every `make app`; `Resources/BANAL.help/Contents/Resources/en.lproj/BANAL.cshelpindex` is **generated**, not checked in, so Help search stays live. `Scripts/gen-5k-vault.sh /tmp/banal-5k 5000` now writes `5000 notes, 10 folders` + `Empty Sit` for the `cold open <400ms` gate.
- Current `NoteStore.open:158` + `FolderTree.build:66` is O(n) file enumeration; search `NoteStore.notes(matching:)` is in-memory `Set` filter; Whisper `0.4s` idle, Oliver `OliverDebounce`, Spotlight `Task.detached(.utility)` all off caret path already.

## Owns

- `Sources/BANALCore/NoteStore.swift` (`open`/`reloadAll`/`collectNoteURLs`, `notes(matching:query:sort)` in-memory, `watchesExternalEdits`, `reindexSpotlight`)
- `Sources/BANALApp/AppModel.swift` (`scheduleOliverQuestion`, `lastOliverRender`, `EditorView` glue)
- `Sources/BANALApp/Views/MarkdownTextView.swift` (`Coordinator.scheduleWhisper` 0.4s, `applyWhisper` temporary attrs + paragraph style, `documentID` caret)
- `Sources/BANALCore/CaretPlacement.swift` + `Sources/BANALCore/WhisperScan.swift`
- `Sources/BANALCore/Spotlight/NoteSpotlightIndexer.swift` (`Task.detached(.utility)` `index`/`deindex`/`reindexAll`, disposable domain)
- `Tests/BANALCoreTests` — `FolderTests`, `IngredientSearchTests`, `NoteSpotlightTests`

## Do not touch

- Bookmark/Casa Grande, Gila Bend dirty-clean, Yuma atomic/crash
- a11y full audit (`M17`), UTType/QL (`M18`), copy/help (`M19`)
- Second index, virtualized card UI, or prefetch that stalls caret

## Why

If the caret hitches at 5k notes, the file is not fluent (`HOPE-CHEST.md:18`). TextKit must stay TextKit.

## Do

### J-16a Typing never waits — Whisper/Oliver/Spotlight off caret (#TBD)

1. Keep `MarkdownTextView.Coordinator.scheduleWhisper:278` `0.4s` `DispatchQueue.main.asyncAfter` + `applyWhisper:289` (`layoutManager.addTemporaryAttributes` + `textStorage paragraphStyle`) gated by `isWritingToolsActive` `MarkdownTextView.swift:291`; `AppModel.scheduleOliverQuestion:980` via `OliverDebounce` on `recipeQueue` `AppModel.swift:77` (userInitiated), not main. Verify with Instruments Hang trace: 30s type never blocks on `NoteStore.scheduleWrite` (400ms) or `NoteSpotlightIndexer.index` (`Task.detached utility` `NoteSpotlightIndexer.swift:176`).
2. Keep `EditorView` `onChange(editorText)` → `applyEditorChanges` debounce only; no sync `reloadAll` or `reindex` on caret path.

### J-16b Cold open 5k → first keystroke <400ms + ⌘F instant (#TBD)

1. Keep `NoteStore.reloadAll:158` sorted `updated` + `FolderTree.build:66` single enumerator pass; cold open measured on Air with synthetic 5k-file vault (script `Scripts/gen-5k-vault.sh` — to be added if I-2 files latency). Gate: `Notes` filter `store.notes(matching:)` in-memory; `⌘F` `Note.matches(query:)` `Note.swift:115` + `ingredients(for:)` cache `NoteStore.swift:91` instant; Tags filter `SidebarFilter.tag` secondary, not a place.
2. Document current 100-note open <50ms; file the hard 5k gate as `J-16b` repro if sit measures >400ms — do not add virtualized `LazyVStack` that hides the file.

### J-16c Spotlight throttled disposable + Tags secondary (#TBD)

1. Keep `NoteSpotlightIndexer:147` `shared` + `domainIdentifier` `dev.drawmeanelephant.banal.notes` disposable (`reindexAll:197` `deleteSearchableItems(withDomainIdentifiers:)` then `indexSearchableItems`), all `Task.detached(.utility)` not `userInitiated`. Deep-link via `NSUserActivity` `CSSearchableItemActionType` → `AppModel` `select` (already `BanalApp.swift:1` `onContinueUserActivity`). No second DB.
2. Keep `Sidebar` Tags section as filter not place — tags `Set(notes.flatMap(\.tags))` `NoteStore.swift:68` sorted, selection toggles `SidebarFilter.tag`.

**Tests to keep green:** `FolderTests:testExternalMkdirAppearsInTree` `testBuildNestsAndKeepsEmptyLeaves`, `IngredientSearchTests`, `NoteSpotlightTests` reindex/disposable, `CaretPlacementTests`, `WhisperScanTests`.

## Do not

- Add SQLite second index, card virtualization, or prefetch that stalls caret (`isWritingToolsActive` guard must stay).
- Make Tags a place (folders are `FileManager` truth).
- Ship a webview preview as editor.

## Gate

1. 30s type + switch notes + ⌘Z `TESTING-WINDOW.md:112` still sane with synthetic 5k vault; Instruments Time Profiler no hang on `NoteStore.write`/`NoteSpotlightIndexer`.
2. Cold open 5k-file vault → first keystroke <400ms on Air; `⌘F` titles/bodies/tags/ingredients instant (`NoteStore.notes(matching:)` in-memory).
3. Spotlight: new note appears in Spotlight within utility delay, trash removes it, `reindexAll` disposable; click deep-links to note and focuses editor.
4. `swift test` green; `grep -rn "SQLite\|CoreData" Sources` zero.

## Failure is a spinner

Any path where `applyWhisper`/`scheduleOliverQuestion`/`reindexSpotlight` runs on caret path, or `NoteStore.reloadAll` blocks main >400ms at 5k, or `Tags` becomes a virtual notebook, fails `J-16`.
