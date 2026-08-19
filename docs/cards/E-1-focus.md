# Card E-1 — Column focus & keyboard navigation

**Milestone:** M9 · **Lane:** chrome · **Depends:** M8 done (or runs beside) · **Status:** landed — keyboard-first fluency

## Handoff

- **Landed.** ⌘1 / ⌘2 / ⌘3 column focus, Tab / ⇧Tab cycling across Sidebar -> Note List -> Editor, arrow navigation and folder expand/collapse in sidebar, Return to focus editor from note list, Escape in editor to return to note list, and code fence indentation protection are wired and verified with tests and `make smoke`.
- **Next:** text editing manners inside the page (E-2–E-5), mouse drag-out (G-5).

## Owns

- `Sources/BANALApp/Views/ContentView.swift`
- `Sources/BANALApp/Views/SidebarView.swift`
- `Sources/BANALApp/Views/NoteListView.swift`
- `Sources/BANALApp/Views/MarkdownTextView.swift`
- Menu bar items: View → Focus Sidebar (⌘1), Focus Note List (⌘2), Focus Editor (⌘3)

## Do not touch

- Split view layout metrics (200 / 280 / rest)
- TextKit layout or text attributes
- Custom focus border circus or glowing halos

## Why

A person who never touches the trackpad should be able to open BANAL, navigate folders with arrows, jump to the note list, pick a note, jump to the editor, write, and file it — completely hands-on-keyboard.

## Do

1. Wire standard Mac shortcuts:
   - `⌘1`: Focus sidebar folder outline / selection.
   - `⌘2`: Focus note list table/collection.
   - `⌘3`: Focus editor text view / caret.
   - `Tab` / `⇧Tab`: Cycles forward / backward between the three columns when not captured by a list indent.
2. Arrow keys in sidebar navigate folder tree (expand/collapse with `→` / `←`).
3. Arrow keys in list navigate notes up/down. `Return` or `⌘3` moves focus to the editor caret.
4. `Escape` in editor drops focus back to the note list selection.
5. Menu bar View menu gains the 3 Focus items with standard key equivalents.

## Do not

- Invent glowing custom focus rings — use macOS native `NSTextView` / `NSOutlineView` / `NSTableView` first responder focus.
- Interfere with `Tab` behavior when actively indenting source inside fences.
- Break full keyboard access / VoiceOver navigation.

## Gate

Launch app with keyboard only: ⌘1 arrow to Recipes, ⌘2 arrow to risotto, ⌘3 start typing. Caret responds immediately. `swift test` stays green.
