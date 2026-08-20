# Card F-3 — Spotlight indexing (`IndexedEntity`)

**Milestone:** M10 · **Lane:** system · **Depends:** M7 Close landed · **Status:** landed — system search finds notes

## Handoff

- **Landed.** Spotlight indexes notes with `CSSearchableItem` and `NoteEntity` metadata (titles, snippets, tags, language extensions, Cooklang recipe ingredients).
- Indexing is completely non-blocking via background tasks and fully disposable.
- Clicking a Spotlight search result deep-links into BANAL, selecting the note and focusing the editor via `NSUserActivity` (`CSSearchableItemActionType`).
- 184 unit tests pass in ~0.5s; `make smoke` passes 100%.
- **Not this card:** a second local database, vector databases, RAG.

## Owns

- `Sources/BANALApp/Spotlight/` (New directory)
- `NoteSpotlightIndexer.swift` (CoreSpotlight `CSSearchableItem` and `AppIntents.IndexedEntity`)
- Integration with `NoteStore` save, rename, and delete lifecycle

## Do not touch

- Disk as sole truth (the Spotlight index is completely disposable and rebuilt from disk files)
- SQLite database creation (NO local SQLite index)

## Why

Pressing `⌘Space` (Spotlight) to type an ingredient or a draft title should surface the note with its proper title, relative folder path, and tags, opening directly into BANAL.

## Do

1. When a note is created or saved, donate a `CSSearchableItem`:
   - Title: note title (or first line)
   - Content description: 2-line snippet / excerpt
   - Keywords: tags + extension (`markdown`, `cooklang`, `textile`)
   - Unique identifier: relative path within notes folder
2. When a note is deleted or renamed, delete the old index identifier.
3. On vault switch or re-index, refresh the donations.
4. Support opening the app via `NSUserActivity` (`CSSearchableItemActionType`) to select the matched note.

## Do not

- Maintain a separate persistent index file that can get out of sync with disk.
- Block note save operations on Spotlight indexing calls (keep indexing asynchronous).

## Gate

Create a note titled "Tucson Planning", save it. Open Spotlight (`⌘Space`), type "Tucson Planning". Note appears with BANAL icon and selecting it opens the note in the editor. `swift test` stays green.
