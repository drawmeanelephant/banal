# Card H-4 — New window on same folder

**Milestone:** M12 · **Lane:** chrome · **Depends:** M7 Close landed · **Status:** consider — second window on notes folder

## Handoff

- **Not started.** BANAL currently supports a single primary window. File → New Window is disabled or not present.
- **Not this card:** multi-vault workspaces, tabbed IDE windows.

## Owns

- `Sources/BANALApp/BANALApp.swift` (`WindowGroup` configuration)
- `Sources/BANALApp/Commands/FileCommands.swift` (File → New Window)

## Do not touch

- Single active vault configuration
- Multi-vault simultaneous stores

## Why

Comparing two notes side-by-side or referencing a recipe in one window while drafting a letter in another is standard Mac behavior (like TextEdit or Notes).

## Do

1. Enable `WindowGroup` or standard multi-window support on macOS for the same notes folder.
2. Both windows observe the same `NoteStore` / FSEvents changes.
3. Editing note A in window 1 updates note A in window 2 seamlessly via the existing file coordination / dirty checking.

## Do not

- Turn BANAL into an IDE with split multi-vault workspace tabs.

## Gate

Press ⌘N (New Window). Second window appears showing the same notes folder. Edit a note in window 1; window 2 reflects updates immediately. `swift test` stays green.
