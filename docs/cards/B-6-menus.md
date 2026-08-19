# Card B-6 — If it isn’t in the menu bar, it isn’t a feature

**Milestone:** M3 · **Lane:** app · **Status:** landed — File complete, one Find menu; About is C-2

## Handoff

- **Landed:** File: New Note, New Folder, Trash (note or folder), Open/Reveal notes folder, Publish / Publish Site. One **Find** menu (not Edit → Find — this SDK has no `CommandGroupPlacement.textFinding`). Create/trash/find/publish disable when there is no folder.
- **Sit (this session):** File and Find menus match the card (AX dump). Keyboard New Note, New Folder, Find Notes, Settings (⌘,). Find Notes focus is a token so a second press still works. New Recipe / New Textile stay omitted until B-8.

## Owns

- `BanalApp.swift` `.commands`
- Any missing File / Edit / View / Find items
- About (later, tiny)

## Do not touch

- Adding toolbar buttons “because menus are hidden”
- Command palettes, Spotlight clones

## Why

Mac users hunt the menu to learn the app. A notes app with secret
gestures and an empty File menu feels like a toy. This is also
how we stop feature creep: if you cannot name the menu item, you
do not get the feature.

## Do

Required, working, with these shortcuts:

| Menu | Item | Key |
|------|------|-----|
| File | New Note | ⌘N |
| File | New Folder | ⇧⌘N |
| File | New Recipe | (M5 — leave disabled or omitted until B-8) |
| File | New Textile | (M5 — same) |
| File | Move to Trash | ⌘⌫ |
| File | Open Notes Folder… | — |
| File | Reveal Notes Folder in Finder | — |
| File | Publish Site… | ⇧⌘P |
| BANAL | Settings… | ⌘, |
| Edit | Undo / Redo / Cut / Copy / Paste | system |
| Find | Find Notes | ⌘F |
| Find | Find in Note | ⇧⌘F |
| Window | Close | ⌘W |

Trash targets the selected note, or the selected folder if no note.

## Do not

- Duplicate Find under both Edit and a custom menu in a confusing
  way. One obvious place is enough; Edit → Find is more native if
  you can hook the text view. Do not ship two competing Find menus
  that both claim ⌘F.

## Gate

A user who never reads the README can discover every feature from
the menu bar. Keyboard-only create note, create folder, search,
trash, settings, publish.
