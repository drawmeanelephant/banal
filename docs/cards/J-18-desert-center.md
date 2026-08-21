# Card J-18 — Desert Center — system furniture (Drive triage)

**Milestone:** M18 · **Lane:** system · **Status:** landed — `e8d9031` board verified · **Branch:** `fix/j18-desert-center` · **Parent:** #115 · **Subissues:** #143 J-18a, #144 J-18b, #145 J-18c — verified

## Handoff

- `main` at `4378a6a` + `J-16` board+snack, `J-17` board cut `c453073`. `swift test` 265 green, `make smoke` passed. `J-18` is CA-177 & I-10 — nothing but a post office and your Quick Look. Mac furniture must be standard, not a costume.
- `UTType` for `.md`/`.textile`/`.cook` already deduped in `Supporting/Info.plist`; `.onOpenURL` + `application(_:open:)` `openURLs:` already deduped in `BanalApp.swift:145`; `NotePreviewGenerator` RTF no WebView, `NSPrintOperation`/`NSSharingServicePicker`/`newNoteService` all landed (F-4/F-5/F-8) — this card verifies, not invents.

## Owns

- `Supporting/Info.plist` (`CFBundleDocumentTypes` `md`/`textile`/`cook` `UTType`, `LSTypeIsPackage`, Help `CFBundleHelpBook*`)
- `Sources/BANALApp/BanalApp.swift` (`BanalHelp`, `BanalAbout`, `BanalAppDelegate` `application(_:open:)` / `openURLs:` / `onOpenURL` dedup, `pendingOpenURLs`, `AppModel.openExternalNote` byte-identical import)
- `Sources/BANALApp/Views/ContentView.swift` + `NoteListView` (Space `QLPreviewPanel`)
- `Sources/BANALCore/QuickLook/NotePreviewGenerator.swift` (RTF `NSAttributedString` `SF Pro` headings/bold/lists/code, recipe ingredients/steps — no WebView)
- `Sources/BANALApp/Coordinators/NotePrintCoordinator.swift` + `NoteShareCoordinator.swift` + `ServicesPasteboardParser.swift`
- `Sources/BANALCore/CopyAsConverter.swift` (used by Print pipeline)
- `Tests/BANALCoreTests/QuickLookPreviewTests.swift`, `PrintShareTests.swift`, `NoteSpotlightTests.swift`

## Do not touch

- Bookmark (M13), Gila Bend (M14), Yuma (M15), El Centro (M16), Niland (M17), Quartzsite copy/help (M19)
- Webview preview, media library, sharing dashboard, fourth pane

## Why

If double-click drops a file, the folder outlives nothing. Furniture is standard AppKit, not a costume.

## Do

### J-18a UTType + Open With dedup — double-click / Open With / Dock drag byte-identical once (#TBD)

1. Keep `Supporting/Info.plist` `CFBundleDocumentTypes` for `.md`/`.textile`/`.cook` deduped (one `UTType` per extension, `LSHandlerRank=Owner` or `Editor`, no duplicate `public.plain-text`), `CFBundleHelpBook*` intact.
2. Keep `BanalApp.swift:175` `application(_:open:)` + `application(_:openFiles:)` queue `pendingOpenURLs` + `ContentView.swift:108` `.onOpenURL` first URL + delegate hook rest `openURLs:` → `AppModel.openExternalNote:183` dedup via `lastHandledOpenURL:84` 2s window + `pendingImports` queue until `bootstrap()`; `store.importFile:543` `uniqueRelativePath` `-2` suffix so multi-select Open With 3 files never overwrites and source untouched. Proof: `make smoke` `BANAL_VAULT` + `BANAL_SMOKE_OPEN_FILE` `risotto.cook,a-page.textile` in one `open -a` call lands byte-identical once.
3. Gate: Finder double-click `.md` in vault → selects note; outside vault → copy into vault + select; multi-select 3 files → 3 imports, no drop.

### J-18b Quick Look RTF no WebView — Space in list opens QLPreviewPanel (#TBD)

1. Keep `NotePreviewGenerator` `NSAttributedString` RTF via `NSRTFWriter` — Markdown headings/bold/italic/lists/code, Textile same, Cooklang title/`>>` metadata + ingredient list + cookware + numbered steps. No `WKWebView`, no Oliver subprocess for preview.
2. Keep `NoteListView` Space → `QLPreviewPanel` `FocusToken` `quickLook` (`AppModel.quickLook:54`), `NotePreviewGenerator` data source for `QLPreviewPanelDataSource` — panel shows RTF, not file icon.

### J-18c Print + Share + Services — ⌘P + Share + newNoteService one sentence on failure (#TBD)

1. Keep `NotePrintCoordinator.printNote:588` `NSPrintOperation` `⌘P` (Edit source or Recipe Read `scale`/`oliverRecipe`) via `NSPrintOperation` `printNote` — one sentence on failure, no sheet stack; `NoteShareCoordinator.shareNote:601` `NSSharingServicePicker` from `view`/`window`; `BanalAppDelegate.newNoteFromService:206` `ServicesPasteboardParser` `newNoteService` → `Inbox/` `createNoteFromService:607`.
2. Keep `F-5` `PrintShareTests` pass.

**Tests to keep green:** `QuickLookPreviewTests`, `PrintShareTests`, `NoteSpotlightTests`, `VaultImporterTests`, `make smoke` open-event byte-identical.

## Do not

- Ship a `WKWebView` preview, media library, or sharing dashboard (`B-X-refuse`).
- Add a Sync service or fourth pane.

## Gate

On a real Mac `dist/BANAL.app` `1100×720`:
1. Double-click vault `.md` → opens in BANAL and selects; double-click outside → copy into vault byte-identical;
2. Multi-select 3 files Open With → 3 imports, no loss (`make smoke` proof);
3. Space in list → `QLPreviewPanel` RTF; `⌘P` Print sheet + `Share` picker + Services `New BANAL Note` → `Inbox` file.

## Failure is a dropped file

If a multi-select Open With drops `n-1` files, or Quick Look is a WebView, or Print is a sheet stack, fails `J-18`.
