# Card G-4 — System pickers (Contacts & Files)

**Milestone:** M11 · **Lane:** editor · **Depends:** M8 done · **Status:** landed — system pickers, not a CRM

## Handoff

- **Landed.** Edit → Insert Contact… and Edit → Insert File… integrated with native `CNContactPicker` and `NSOpenPanel`, copying files to `assets/` and inserting Markdown links preserving undo.
- **Not this card:** contacts CRM sidebar, syncing Apple Contacts into frontmatter.

## Owns

- `Sources/BANALApp/Commands/EditCommands.swift`
- `Sources/BANALApp/Views/MarkdownTextView.swift`
- `CNContactPicker` integration (when entitlement enabled) or plain file link picker

## Do not touch

- Contact databases or local contact caching
- Network requests to contact sync servers

## Why

The Mac already has an address book. Inserting a contact's name and email should feel as simple and obvious as Mail: pick a contact, insert their name and `mailto:` link as text. Finder and notes stay clean.

## Do

1. Add Edit → Insert Contact… menu command:
   - Presents native macOS Contact Picker (`CNContactPicker`).
   - Inserts selected contact as plain text: `Name <email>` or `[Name](mailto:email)`.
2. Add Edit → Insert File… menu command:
   - Presents file open panel.
   - Copies file to `assets/` and inserts relative link `[filename](assets/filename)`.
3. Keep undo intact (`⌘Z` cleanly removes inserted text).

## Do not

- Create a "People" section in the sidebar.
- Index birthdays or turn BANAL into a personal CRM.

## Gate

Choose Edit → Insert Contact…, pick John Appleseed. Note text receives `[John Appleseed](mailto:john@apple.com)`. `swift test` stays green.
