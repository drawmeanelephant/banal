# Card F-2 — App Intents and Siri

**Milestone:** M10 · **Lane:** system · **Depends:** M7 Close landed · **Status:** ready — Siri & Shortcuts furniture

## Handoff

- **Not started.** BANAL does not declare App Intents. System Shortcuts and Siri cannot create or search notes.
- **Not this card:** microphone UI (system dictation works directly in the editor), listening pane.

## Owns

- `Sources/BANALApp/Intents/` (New directory for App Intents)
- `NewNoteIntent.swift`, `NewRecipeIntent.swift`, `TakeNoteIntent.swift`, `SearchNotesIntent.swift`, `OpenNotesFolderIntent.swift`, `PublishSiteIntent.swift`
- `BANALShortcutsProvider.swift` (AppShortcutsProvider)

## Do not touch

- File-based store truth: intents write real `.md` and `.cook` files to the configured notes folder
- macOS 14 deployment floor (`AppIntents` framework is supported on macOS 13+)

## Why

"Hey Siri, take a note in BANAL" and Shortcuts automation should feel like built-in Mac furniture. Dictated voice notes land as ordinary text files in `Inbox/` without needing a custom microphone UI or cloud service.

## Do

1. Implement core App Intents:
   - `NewNoteIntent`: creates a `.md` note with optional title/body in the configured folder.
   - `NewRecipeIntent`: creates a `.cook` note with `>>` metadata.
   - `TakeNoteIntent`: takes a spoken transcript or input text and creates an inbox note.
   - `SearchNotesIntent`: searches note titles and bodies and returns matching note references.
   - `OpenNotesFolderIntent`: reveals the active notes folder in Finder.
   - `PublishSiteIntent`: runs publish export (⇧⌘P).
2. Register AppShortcuts so Siri recognizes phrases like "Take a note in BANAL".
3. Write files directly using `BANALCore.NoteStore` atomic write methods.

## Do not

- Create a custom voice-recording UI, waveform visualizer, or listening sheet.
- Depend on external proprietary speech-to-text APIs.

## Gate

Run `shortcuts run "Take a note in BANAL"` from terminal; a new note file appears in the notes folder. `swift test` stays green.
