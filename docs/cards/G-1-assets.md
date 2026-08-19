# Card G-1 — Images land in `assets/`

**Milestone:** M11 · **Lane:** files · **Depends:** M8 done · **Status:** ready — drop photos into markdown notes

## Handoff

- **Not started.** Dragging an image onto `MarkdownTextView` inserts a file path or raw data URL without copying the file to the notes folder.
- **Not this card:** image editing, hover zoom, attachment database, cloud media hosting.

## Owns

- `Sources/BANALApp/Views/MarkdownTextView.swift` (drag/drop handling for image types)
- `Sources/BANALCore/AssetManager.swift` (or helper to copy images into `assets/`)
- Relative link generation: `![](assets/image-name.png)`

## Do not touch

- Rich text or embedded image attachments in `NSTextStorage` (`isRichText` stays `false`)
- Modifying image data (no compression, resizing, or metadata stripping)

## Why

Notes have diagrams, screenshots, and recipe photos. When you drag an image onto the page or use Insert Photo…, the image should copy into an ordinary `assets/` folder alongside the note and insert `![](assets/photo.png)`. Finder still makes total sense.

## Do

1. Handle dropped image files (PNG, JPEG, GIF, WebP, HEIC):
   - Copy file into `<notes-folder>/assets/<sanitized-filename>`.
   - If collision occurs, append unique suffix (e.g. `screenshot-1.png`).
   - Insert Markdown image tag `![](assets/<filename>)` at the drop insertion point.
2. Edit → Insert Photo…:
   - Opens macOS system photo / file picker.
   - Copies chosen image to `assets/` and inserts relative Markdown tag.
3. Keep undo intact (`⌘Z` deletes the inserted markdown tag; disk file remains in `assets/`).

## Do not

- Turn BANAL into a media library or DAM.
- Store images in a hidden sqlite database or base64 blob in the markdown text.

## Gate

Drag `diagram.png` from Finder into a note in BANAL. Note body gains `![](assets/diagram.png)`. Finder shows `assets/diagram.png` created on disk. `swift test` stays green.
