# Card J-17 — Niland — a11y & keyboard (Drive triage)

**Milestone:** M17 · **Lane:** chrome · **Status:** landed — `ee0af6c` board verified · **Branch:** `fix/j17-niland` · **Parent:** #114 · **Subissues:** #139 J-17a, #140 J-17b, #141 J-17c — verified

## Handoff

- `main` at `4378a6a` (El Centro board + snack `hiutil` + `5k`). `swift test` 265 green, `make smoke` + `make app` ad-hoc pass. I-2 light smoke passed; friend full dark + VoiceOver still deferred.
- Niland is Bombay Beach — the window must work at `720` wide with VoiceOver + keyboard only, no color-only Published, no tour.

## Owns

- `Sources/BANALApp/Views/ContentView.swift` (`NavigationSplitView`, `.balanced`, `VaultPicker`, `StatusStripView` a11y)
- `Sources/BANALApp/Views/SidebarView.swift` (Folders tree, OutlineGroup, disclosure, note count)
- `Sources/BANALApp/Views/NoteListView.swift` (rows: title + `Published` globe + `Recipe` + relative date + snippet, empty states `No notes…`)
- `Sources/BANALApp/Views/EditorView.swift` + `MarkdownTextView.swift` (title field, metadata row, `NSViewRepresentable` `NSTextView` `.textArea`, selection, Translation)
- `Sources/BANALApp/Views/RecipeReadView.swift` + `ProseReadView` (ingredients/cookware/steps, scale)
- `Sources/BANALApp/Views/SettingsRoot.swift` (General/Editor/Publish panes, toggles, pickers)
- `Sources/BANALApp/AppModel.swift` (`FocusToken` sidebar/list/editor, `ViewMode`, `isWritingToolsActive` shield)
- `Sources/BANALApp/Commands/*` + `Sources/BANALCore/AccessibilityFormatting.swift`
- `docs/TESTING-WINDOW.md:199` + `docs/TESTING-SYSTEM.md` is the gate script

## Do not touch

- Bookmark (M13), Gila Bend dirty-clean (M14), Yuma atomic (M15), El Centro latency (M16), UTType/QL (M18), Copy/Help (M19)
- Second DB, sync, or fourth pane / tour / carousel to explain chrome

## Why

If a person can’t file a note with VoiceOver at `720` on a 13" Air, the “Apple shipped it” bar is a lie (`NORTH-STAR.md:1`, `docs/QUALITY.md:1`).

## Do

### J-17a VoiceOver on the three columns — sidebar/list/editor/Read/Settings/picker/status (#TBD)

1. Keep `ContentView.swift:17-27` `SidebarView` → `accessibilityLabel("Folders")`, `NoteListView` → `accessibilityLabel("Notes")`, `EditorView` → `accessibilityLabel("Note")` (`View` `contain` children), plus `VaultPicker` sentence not “group/empty” `ContentView.swift:88`.
2. Keep `NoteListView.swift:120-150` rows: `Title` (publish `globe` + `Published` label not color-only), `Recipe` badge for `.cook`, relative date `updated: Date`, preview `snippet` truncation, `AccessibilityFormatting` `noteRowDescription` includes all when VoiceOver walks; `RecipeReadView` `accessibilityElement(children: combine)` for ingredients/cookware/numbered steps + `RecipeScale` `1×/2×`.
3. Keep `SettingsRoot.swift:20-80` explicit `accessibilityLabel`/`Hint` for toggles, `Choose…`/`Reveal in Finder`, `Editor` font/line-height; `StatusStripView.swift:40` `statusMessage` speaks one sentence then `dismissStatusLater:800`.
4. Keep Help `Resources/BANAL.help`anchors + `BanalHelp.swift:145` `bookName` searchable via `hiutil` index (`Makefile:45`) — Help itself is a11y land.

### J-17b Full keyboard — ⌘1/⌘2/⌘3 + Tab + arrows + Return/Esc + ⌘F/⇧⌘F + per-note ⌘Z (#TBD)

1. Keep `ViewCommands` + `AppModel.FocusToken` (`AppModel.swift:51` sidebar/list/editor `FocusToken`) — `⌘1` sidebar, `⌘2` list, `⌘3` editor (`Sources/BANALApp/Commands/ViewCommands.swift:1`), `Tab` cycles columns forward, `Shift-Tab` back; sidebar `OutlineGroup` arrows expand/collapse + `selection` follows folder filter, `Return` on list row focuses editor caret, `Esc` in editor `MarkdownTextView.swift:55` `onEscape → focusNoteList()`.
2. Keep `FindCommands` `⌘F` titles/bodies/tags/ingredients (`NoteStore.notes(matching:)`) in-memory instant + `⇧⌘F` Find in Note `MarkdownTextView.findToken` `TextFinder`; both panes stay `NSTextView` not a webview so `isIncrementalSearchingEnabled` works.
3. Keep per-note `⌘Z`/`⇧⌘Z`: `MarkdownTextView.updateNSView:164` `undoManager.removeAllActions()` on `documentID` change (`AppModel.editorSessionID:39`), so switching notes resets undo stack; `NSUndoManager` group is `NSTextView` native, not a custom manager.

### J-17c Reduce Motion + Increase Contrast + light/dark 720/1100/1400 (#TBD)

1. Keep `@Environment(\.accessibilityReduceMotion)` `ContentView.swift:7` / `EditorView.swift:9` — `reduceMotion ? nil : .easeOut(0.18)` `ContentView.swift:36` for `statusMessage` slide; `@Environment(\.colorSchemeContrast)` `ContentView.swift:8` → `1pt` hairline separators `SidebarView`/`NoteListView` increaseContrast border, not color wash.
2. Keep `EditorTypography.swift:6` `measureWidth:680` + `horizontalInset:32` centered `EditorView.swift:104` `measure(availableWidth)` — at `720` sidebar may collapse (`NavigationSplitView` `.balanced`) but list + editor stay readable; at `1400` body stays measure not lawn when `limitLineLength` on. Re-sit light+dark `720/1100/1400` per `docs/TESTING-WINDOW.md:96` — dark is system materials not branded purple.
3. Gate pairs with J-17a/b — motion off means no fly-in, contrast means separators survive.

**Tests to keep green:** `AccessibilityFormattingTests` (F-7), `CaretPlacementTests`, `ExternalEditTests` isWritingToolsActive, `NoteStoreTests` filter/sort, `swift test` 265. VoiceOver pair is manual `docs/TESTING-WINDOW.md:199`.

## Do not

- Add a tour, carousel, onboarding overlay, or fourth Settings pane to explain chrome (`docs/QUALITY.md:1` — delete UI before adding).
- Make `Published` color-only — `NoteListView` globe + label + VoiceOver speak `Published`.

## Gate

Walk `dist/BANAL.app` `1100×720` with **VoiceOver + keyboard only** (no mouse/trackpad) `docs/TESTING-WINDOW.md:199`:
1. `⌘1` → sidebar folders announce `Folders` + disclosure, arrows `Expand/Collapse`, count; `⌘2` → list rows speak `Title · Recipe if .cook · Published if true · relative date · preview`; `⌘3` → editor title field `Title` + body `textArea`, `Esc` returns to list, `Return` on list goes to editor caret.
2. `⌘F`/`⇧⌘F` + per-note `⌘Z`/`⇧⌘Z` sane after 30s type + switch (J-15a).
3. `Reduce Motion` on → no slide on `statusMessage`; `Increase Contrast` on → hairline separators visible at `720/1100/1400` light + dark.
4. No tour, no “group/empty” when VoiceOver lands on `VaultPicker`/`StatusStripView`.

## Failure is “group / empty”

If VoiceOver says `group` for the whole window, or `Published` is a dot with no label/speak, or `⌘1/⌘2/⌘3` + `Tab` cannot reach all three columns at `720`, fails `J-17`.
