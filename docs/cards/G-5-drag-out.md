# Card G-5 — Drag note out to system

**Milestone:** M11 · **Lane:** list · **Depends:** M8 done · **Status:** landed — notes travel like files

## Handoff

- **Landed.** Dragging a note row from the list provides `NSItemProvider` configured with `.fileURL` pointing to the note on disk and `public.utf8-plain-text` formatted note body/text via `NoteDragProvider`.
- Finder copies the real `.md`, `.cook`, or `.textile` file directly.
- Mail and Messages attach the file or insert plain text.
- Internal folder drag-to-move in `SidebarView` is maintained.

## Owns

- `Sources/BANALApp/Views/NoteListView.swift` (item provider / `NSFilePromiseProvider` or `NSPasteboardItem` file URL provider)
- Pasteboard types: `.fileURL`, `public.utf8-plain-text`

## Do not touch

- Existing internal folder drag-to-move logic
- Direct file paths on disk

## Why

A note in BANAL is a real file on disk. When you drag a note row out of BANAL and drop it onto your Desktop, into an email draft in Mail.app, or into a chat in Messages, macOS should copy the `.md` or `.cook` file directly.

## Do

1. Configure `NSItemProvider` on note list rows with:
   - File URL representation pointing to the note file on disk.
   - Plain text representation (note body).
2. When dropped on Finder: creates a copy of the `.md` / `.cook` file.
3. When dropped on Mail or Messages: attaches the file or inserts the note text.
4. Maintain internal dragging: dragging onto a folder in the sidebar still executes a folder move.

## Do not

- Export proprietary bundle wrappers or locked archives.
- Break internal note moving.

## Gate

Drag a note from the note list to the macOS Desktop in Finder. An identical `.md` file appears on the Desktop. `swift test` stays green.
