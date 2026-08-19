# Card H-3 — Tags as secondary filter

**Milestone:** M12 · **Lane:** list · **Depends:** M8 done · **Status:** consider — tags filter, not a notebook structure

## Handoff

- **Not started.** Tags exist in note frontmatter / metadata row, but cannot be filtered from the sidebar.
- **Not this card:** nested tag hierarchies, tag management databases, replacing folders with tags.

## Owns

- `Sources/BANALApp/Views/SidebarView.swift` (Tags filter list below folders)
- `Sources/BANALApp/Models/AppModel.swift` (active tag filtering)

## Do not touch

- Real folders as primary filesystem structure
- Disallow virtual notebooks or tag-based folder systems

## Why

Tags are metadata on notes. A small list of tags in the sidebar can filter the current note list without pretending tags are physical folders on disk.

## Do

1. Collect unique tags from notes in memory.
2. Display a quiet "Tags" section below the folder hierarchy in the sidebar.
3. Clicking a tag filters the note list to notes containing that tag.
4. Clicking again clears the filter.

## Do not

- Add tag renaming engines across the entire filesystem.
- Create virtual tag notebooks.

## Gate

Click `#draft` in the sidebar tags list. Note list filters immediately to notes with the `draft` tag. Deselect; list returns to normal. `swift test` stays green.
