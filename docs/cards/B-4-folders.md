# Card B-4 — Folders are directories

**Milestone:** M1 · **Lane:** core + sidebar · **Status:** cooking — New Note Here, rename rewrite, Finder rename tested

## Handoff

- **Landed:** Nested tree, empty folders, reserved names hidden, ⇧⌘N in the selected folder, unique sibling names, drag note → folder / All Notes, context menu, Inbox on demand, external mkdir.
- **This session:** New Note Here writes into that directory even when new notes default to Inbox. Folder rename remaps the open note id. Finder rename of a folder rescans ids. Tests cover reserved dirs, nested Essays/Drafts → Published, and external rename.
- **Sit (this session):** New Note in Drafts wrote `Essays/Drafts/….md`. Finder `mv Drafts Published` updated the sidebar. Filter pointed at the old path until a rescan fallback to All Notes landed. Untitled Folder created under Essays via ⇧⌘N. Trash-to-Trash.app not walked in the GUI this sit.

The scaffold already creates, renames, moves, and trashes folders
and can drop a note onto a folder. This card is the *finish* of
that idea, not a rewrite.

## Owns

- `Sources/BANALCore/Folder.swift`
- `NoteStore` folder APIs
- `SidebarView` tree, alerts, drop
- Tests in `Tests/BANALCoreTests/FolderTests.swift`

## Do not touch

- Type, Settings panes, Oliver, Publish
- Virtual notebooks, tag folders, smart playlists

## Why

This is the structural joke that has to land: Finder and BANAL
show the same tree. When that is true, iCloud Drive, syncthing,
and git all work without us. When it is false, we become a
database with an export button.

## Do

1. Nested `OutlineGroup`. Empty folders remain. Reserved names
   (`assets`, `.banal`, `.publish`, `.git`) never appear.
2. ⇧⌘N creates in the selected folder (or vault root). Unique
   sibling names (`Inbox`, `Inbox 2`).
3. ⌘N creates a note *in* the selected folder (or Inbox / root
   per Settings).
4. Drag note → folder moves the file. Drag note → All Notes moves
   to vault root. Rename folder rewrites in-memory ids to match
   disk.
5. External `mkdir` / Finder rename: FSEvents rescans; the tree
   updates without a lecture.
6. Context menu: New Note Here, New Folder, Rename, Move to Trash.
7. Tests: create, empty folder survives, rename moves notes,
   move+trash, sanitize rejects `..` / `assets` / slashes.

## Do not

- Store folder order in JSON. Sort A–Z. Do not invent `.order`.
- Move a folder by rewriting every file in Swift if `FileManager.moveItem`
   on the directory will do.
- Show `assets/` as a notes folder.

## Gate

`swift test` folder suite green. In the running app: create
`Essays/Drafts`, put a note in it, rename `Drafts` → `Published`,
confirm Finder agrees. Trash the folder; Trash.app has the
directory, not a BANAL limbo.
