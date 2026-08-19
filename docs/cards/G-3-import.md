# Card G-3 — Import as copy

**Milestone:** M11 · **Lane:** files · **Depends:** M8 done · **Status:** ready — files in folders, never a sync database

## Handoff

- **Not started.** File → Import… does not exist. Users can copy files in Finder, but an in-app file/folder importer makes onboarding painless.
- **Not this card:** live cloud sync with Bear/Notion, scraping proprietary APIs.

## Owns

- `Sources/BANALApp/Commands/FileCommands.swift` (File → Import…)
- `Sources/BANALCore/VaultImporter.swift` (copies `.md`, `.textile`, `.cook`, and images into notes folder)

## Do not touch

- Direct filesystem truth: import is literally copying files into the user's directory on disk
- No conversion of proprietary tags into virtual structures

## Why

Importing from another notes app (Bear markdown export, Obsidian vault, ChatGPT text export) is just copying a tree of files and images into the notes directory. Disk is truth; FSEvents picks it up immediately.

## Do

1. Add File → Import… menu command:
   - Opens macOS open panel allowing multi-file and folder selection.
2. Filter for supported note extensions (`.md`, `.textile`, `.cook`, `.txt`) and assets (`assets/` images).
3. Copy chosen files and folders into the selected notes folder location.
4. Auto-rename collisions (e.g. `Note (Imported).md`).
5. `NoteStore` rescans and highlights the imported notes in the list.

## Do not

- Create a complex import wizard with migration steps.
- Attempt to parse or convert proprietary markdown flavor annotations.

## Gate

Choose File → Import…, select an Obsidian folder containing 10 markdown notes and 2 images. Files land in BANAL notes folder on disk and show up immediately in the note list. `swift test` stays green.
