# Card F-5 — Print, Share, and Services

**Milestone:** M10 · **Lane:** system · **Depends:** M7 Close landed · **Status:** landed — File → Print (⌘P), Share sheet, and Services menu integration

## Handoff

- **Landed.** File → Print (`⌘P`) uses `NSPrintOperation` with clean SF Pro typography (formatted note in Edit mode, ingredients/cookware/steps in Recipe Read mode). File → Share invokes `NSSharingServicePicker` with file URL and plain text payload. Services menu ("New BANAL Note") captures plain text selection into `Inbox/`.
- **Not this card:** export wizard, PDF layout builder, social sharing hub.

## Owns

- `Sources/BANALApp/Commands/FileCommands.swift`
- `Sources/BANALApp/Views/EditorView.swift` (printing coordinator / `NSPrintOperation`)
- System Share Sheet invocation (`NSSharingServicePicker`)
- macOS Services provider (`NSServices` dictionary in Info.plist)

## Do not touch

- Three-column layout
- Adding toolbar clutter or share buttons to the window header (keep in File menu / context menu)

## Why

People print recipes to stick on the fridge and share drafts with colleagues. In standard Mac apps, File → Print and File → Share are assumed. Selecting text anywhere in macOS and right-clicking Services → "New BANAL Note" should just work.

## Do

1. **File → Print (⌘P):**
   - In Editor mode: prints formatted note with title and clean typography.
   - In Recipe Read mode: prints formatted ingredient list and numbered steps.
   - Standard `NSPrintOperation` with page setup.
2. **File → Share:**
   - Standard `NSSharingServicePicker` with note text or file URL.
3. **Services Menu:**
   - Register `NewBANALNoteService`: receives plain text selection from any app and writes a new note into `Inbox/`.

## Do not

- Add social media icons, custom PDF engines, or watermarks.
- Complicate the File menu with submenus for each share service.

## Gate

Press ⌘P on `risotto.cook` in Read mode: print dialog shows cleanly laid out ingredients and steps. Highlight text in Safari, select Services → "New BANAL Note": new note appears in BANAL. `swift test` stays green.
