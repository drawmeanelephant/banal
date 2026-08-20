# Card J-13 — Casa Grande — bookmark & first-run (Drive triage)

**Milestone:** M13 · **Lane:** core+app · **Status:** board — bookmark & first-run, triaged from I-2 sit · **Branch:** `fix/j13-casa-grande` · **Parent:** #110 · **Subissues:** #117 #118 #119 #120

## Handoff

- **Not started** as code — `VaultBookmark` / `NotesFolderAccess` / `BanalApp` / `NoteStore.rootMissing` exists but J-13a-d split the sit into slices. Parent #110 gate: stale bookmark → `This notes folder is missing.` + old path, two buttons, no recreate, no crash.
- Subissues cut: #117 bookmark stale/move/rename/reboot (`VaultBookmark.swift:8`), #118 first-run vs missing-at-launch never mkdir (`ContentView.swift:49`, `VaultBookmark.swift:139`), #119 vanish-while-open → missing picker (`NoteStore.swift:417`, `AppModel.swift:144`), #120 Settings Reveal after Finder rename (`SettingsRoot.swift:45`, `AppModel.swift:900`).
- Stash of intent lives in `chore/i1-free-tier` docs edits (ROADMAP/HOPE-CHEST naming Casa Grande→Quartzsite) — not yet on `main`; J-13 is the first named exit off the blank drive (`ROADMAP.md:211`).
- Next step after this card: close J-13a-d gates via `docs/TESTING-NOTES-FOLDER.md:1` script (steps 1–6), `swift test` `VaultBookmarkTests`/`NotesFolderAccessTests`, and `make app` + `make smoke` on ad-hoc build. Do not pull M14–M19 work into this branch.

## Owns

- `Sources/BANALCore/VaultBookmark.swift` (`SecurityScope`, `save`/`restore`/`realHomeDirectory`/`createFolderIfAllowed`)
- `Sources/BANALCore/NotesFolderAccess.swift` (`firstRun`/`ready`/`missing`, `resolveRemembered` never mkdir)
- `Sources/BANALApp/BanalApp.swift` (`init` remembered→access, `applicationWillTerminate` `stopAll`)
- `Sources/BANALApp/AppModel.swift` (`needsVault`/`missingNotesFolder`, `$rootMissing` sink, `openVault`/`revealVault`/`flushEditor` guard)
- `Sources/BANALApp/Views/ContentView.swift` (`VaultPicker` copy + two buttons)
- `Sources/BANALApp/Views/SettingsRoot.swift` (`Reveal in Finder`, `Choose…` → `NotesFolderPicker.run`)
- `Sources/BANALApp/NotesFolderPicker.swift`
- `Sources/BANALCore/NoteStore.swift` (`rootMissing`, `applyExternalChange`, `open`/`bootstrap`)
- `Tests/BANALCoreTests/VaultBookmarkTests.swift`, `Tests/BANALCoreTests/NotesFolderAccessTests.swift`
- `docs/TESTING-NOTES-FOLDER.md` (the sit)

## Do not touch

- `FSEvents` dirty/clean reload logic (M14 Gila Bend), atomic write/crash (`M15 Yuma`), latency/5k vault (`M16 El Centro`), a11y full audit (`M17 Niland`), UTType/QLPreviewPanel (`M18 Desert Center`), Copy As/Help re-sit (`M19 Quartzsite`) — one card per town, one concern per branch.
- Second DB, sync service, fourth Settings pane, graph/backlinks, inspector, Solipsist Compose, webview preview, per-note database.

## Why

Disk is truth only if Finder and BANAL agree after a move, rename, or reboot. The first 30 miles after Tucson are a bookmark. A stale bookmark that crashes, a missing folder that gets silently recreated, or a Reveal that points at the app bundle breaks the “folder outlives the app” promise (`HOPE-CHEST.md:18`, `ROADMAP.md:220`). Casa Grande is the gas station that proves the AC works at 115 °F — the vault bookmark survives, the picker tells the truth, and the window dumps to that truth the moment the folder vanishes.

## Do

### J-13a Bookmark lifecycle — survive move/rename/reboot, stale→missing not crash (#117)
1. Keep `VaultBookmark.save` (`VaultBookmark.swift:66`) writing both `bookmarkKey` (`.withSecurityScope`) and `pathKey`; `restore` (`VaultBookmark.swift:86`) tries bookmark data with `.withSecurityScope,.withoutUI`, `stale`→`save(url)` rewrites, fallback to `pathKey` (`VaultBookmark.swift:108`) on resolve failure/corrupted data — never throws.
2. Keep `SecurityScope` single-key `notes-folder` start/stop contract (`VaultBookmark.swift:8`): `save`/`restore` `start`, `endAccess()`/`stopAll()` on `openVault` (`AppModel.swift:814`) and `applicationWillTerminate` (`BanalApp.swift:291`). `start` dedupes same URL (`VaultBookmark.swift:21`).
3. `BANAL_VAULT` override `→ restored` without writing (`VaultBookmark.swift:71`, `Tests/VaultBookmarkTests.swift:75`); `realHomeDirectory()` (`VaultBookmark.swift:121`) not sandbox container for `defaultVaultURL` `~/Documents/BANAL Notes` (`VaultBookmark.swift:131`).
4. Rename/move vault in Finder while quit → relaunch lands `ready` at new inode path; trash/delete → `missing`; corrupted bookmark bytes → `missing` with `pathKey` path, no crash. Probe coverage in `VaultBookmarkTests`.

### J-13b First-run vs missing-at-launch — never silently recreate (#118)
1. `NotesFolderAccess.resolve(remembered:)` (`NotesFolderAccess.swift:9`): `nil→.firstRun`, `exists+isDirectory→.ready`, else `file` or `missing→.missing`; `resolve`/`resolveRemembered` never `createDirectory` (`NotesFolderAccessTests.swift:30`).
2. `BanalApp.init` (`BanalApp.swift:13`) wires remembered→access: `ready` gets real root, `missing` gets dead root + `needsVault+missing=true`, `firstRun` gets `defaultVaultURL` + `needsVault` but no `mkdir`; `ContentView.onAppear` only `bootstrap()` when `!needsVault` (`ContentView.swift:40`).
3. `VaultPicker` copy (`ContentView.swift:49`): firstRun `Choose a notes folder.` no path; missing `This notes folder is missing.` + one-line truncated `store.configuration.rootURL.path` (`ContentView.swift:57`), two buttons `Documents/BANAL Notes` + `Choose…` (`ContentView.swift:66`), keyboard `.defaultAction` on `Choose…`, VoiceOver labels `ContentView.swift:88`, same words as `TESTING-NOTES-FOLDER.md:151`.
4. `Documents/BANAL Notes` button probes `createFolderIfAllowed` (`VaultBookmark.swift:139`) write+delete probe; if not allowed, falls back to `NotesFolderPicker.run(startingAt: Documents)` powerbox (`ContentView.swift:68`). First-run screen itself never calls `VaultBootstrap.prepare` or `createDirectory` — sit step 3 (`TESTING-NOTES-FOLDER.md:87`) passes.

### J-13c Vanish-while-open — dump to missing picker, no ghost writes (#119)
1. `NoteStore.applyExternalChange(at:)` (`NoteStore.swift:417`): if `!rootExists()` set `rootMissing=true, notes=[], folderTree=[]` regardless of `watchesExternalEdits` (`TESTING-NOTES-FOLDER.md:137` — vanish is not an edit; watch-off still catches vanish). Conversely, watch-off keeps file-change reloads off.
2. `AppModel.bindStore` (`AppModel.swift:144`) `$rootMissing→needsVault=true,missingNotesFolder=true` → `ContentView.swift:12` swaps `NavigationSplitView` for `VaultPicker`, list empties. While `needsVault` all edit/file commands `disabled` (`Commands/*:needsVault`) and `flushEditor()` guards `store.rootMissing` (`AppModel.swift:478`) — no write recreates ghost folder at old path.
3. The only exit is `openVault(url)` (`AppModel.swift:810`): `flushEditor`+`flush`+`monitorStopForReplacement`+`VaultBookmark.endAccess`+`VaultBookmark.save`+`bootstrap`+`drainPendingImports`. `revealVault` not reachable while missing.

### J-13d Settings Reveal in Finder after Finder rename (#120)
1. While `ready`, Settings → General `Location` shows `store.configuration.rootURL.path` (`SettingsRoot.swift:33`) and `Reveal in Finder` / `Choose…` (`SettingsRoot.swift:45`). After quitting, renaming vault in Finder, and relaunching, bookmark re-resolves to new path — `restore` returns new URL, `BanalApp` opens `ready` there, `Location` shows new path.
2. Audit/fix `revealVault` (`AppModel.swift:900`): currently `activateFileViewerSelecting([store.configuration.rootURL])`. After rename, `store.configuration.rootURL` is the resolved new URL (because `BanalApp.init` used `remembered` which re-resolved) — but if Reveal is invoked after an in-place drift, prefer `VaultBookmark.restore()` live value over stale snapshot; fall back only for firstRun. Keep behavior covered by `TESTING-NOTES-FOLDER.md:146-149`.
3. `Choose… → NotesFolderPicker.run() → openVault` (`SettingsRoot.swift:75`, `NotesFolderPicker.swift:6`) must replace scoped access, persist bookmark, rebuild `NoteStore` with new `VaultConfiguration(rootURL:)` and `bootstrap`; next launch stays at chosen folder. Do not add silent retarget daemon — vanish-while-open stays J-13c.

**Tests to keep green:** `VaultBookmarkTests:testSaveAndRestoreRoundTripsURL` `testVanishedFolderRestoreKeepsPathAndDoesNotCreate` `testOverrideDoesNotWriteBookmark` `testCreateFolderIfAllowedThenEndAccessLeavesFolder` `testRestoredFolderStillAcceptsPublishDirectory`; `NotesFolderAccessTests:testNilIsFirstRun` `testMissingDirectoryIsMissing` `testFileIsMissingNotReady` `testMissingResolveDoesNotCreateTheFolder`.

## Do not

- Add a fourth pane, a sync service, a second DB/`SQLite` index that can disagree with disk, or a folder-watch auto-retarget that hides the missing truth.
- Copy Solipsist `Sources/Compose`/inspector or ship a webview preview as the editor; Oliver stays subprocess.
- Pretend folders: create/rename/move/trash must be filesystem operations Finder sees.
- Grow frontmatter beyond `title`/`created`/`updated`/`tags`/`published` or store Cloudflare tokens in the vault.

## Gate

`docs/TESTING-NOTES-FOLDER.md:179` pass/fail + stale-bookmark gate from #110:

1. First run asks — `Choose a notes folder.` no path, two buttons (`ContentView.swift:54`).
2. Remembered live folder → no picker on quit/reopen.
3. Remembered **dead** folder (quit → Finder rename→GONE / trash) → `This notes folder is missing.` + **old** path truncated, two buttons, **folder not recreated** on disk.
4. Vanish while open (rename/trash with app open) → within FSEvents beat same missing UI, list empty, no ghost write.
5. `Choose…` / `Documents/BANAL Notes` out of the hole lands in chosen folder and persists across reboot; `Settings → Reveal in Finder` selects real folder even after Finder rename-while-quit.
6. `swift test` green; `make app` ad-hoc build + `make smoke` proof; VoiceOver reads picker sentence not “group / empty”.

No data loss. One card per bug — if I-2 files a class outside J-13 (FSEvents dirty, crash, latency, a11y, UTType, copy/help), that bug gets its own J-14…J-19 card, not this branch.

## Failure is silent mkdir

Any code path that does `createDirectory(at: remembered.path)` when `access == .missing` or `.firstRun` before an explicit user choice fails the card. Search `grep -rn "createDirectory" Sources/BANALApp Sources/BANALCore` — only `VaultBootstrap.prepare` (called from `NoteStore.open` when `ready`) and `VaultBookmark.createFolderIfAllowed` (probe after button) and folder-ops `NoteStore.createFolder/ensureFolderExists` are allowed.
