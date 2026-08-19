# Quality bar

Aspirational, but not decorative. New UI is measured against this file. If a change makes the app louder, busier, or slower, it does not ship.

BANAL should feel like a finished Mac app that happens to be small — not a scaffold that happens to have a window.

## North stars (use as references, do not clone)

| App | Steal this | Leave this |
| --- | --- | --- |
| Apple Notes | Folder list, instant open, system materials | Attachments circus, locked notes crypto |
| iA Writer | Type, measure, calm chrome | Focus modes as a product religion |
| Things | Spacing, sidebar discipline, empty states | GTD ontology |
| TextEdit / BBEdit | Honest text, real undo, real find | Developer clutter |

## Layout

- Three columns on a wide window: **folders · notes · editor**. Collapse gracefully; never become a dashboard.
- Sidebar is for places (folders) plus two smart lists: All Notes, Published. Tags, if shown, are a filter section — secondary.
- List is one note per row: title, one-line snippet, relative date. No cards, no hero images, no unread dots.
- Editor is a title field and a page of text. Metadata (tags, published) is quiet, one row, not a property inspector.
- Default window ~1100×720. Minimum width must still show list + editor. Sidebar may collapse.

## Typography

- System sans (SF Pro) for chrome, lists, title, and body. No serif. Stylesheets later.
- Body ~15–17 pt, line height ~1.45–1.55, measure capped (about 66 characters) so a huge window does not become a lawn of text.
- Title is larger and heavier, same family as the body.
- No rainbow syntax theme in the editor. If Markdown highlighting exists later, it is *whispered* (headings, emphasis) and never a code-editor skin.
- Dynamic Type is not required on Mac, but respect the user’s sidebar/icon size and increase-contrast settings.

## Color and materials

- Follow the system appearance. No branded dark-mode palette.
- Use semantic colors (`textColor`, `secondaryLabelColor`, `windowBackgroundColor`, `controlBackgroundColor`, `separatorColor`).
- Chrome is quiet. One accent: the system accent, used for selection and the published check — not for decoration.
- Separators are hairline, not cards in cards.
- Avoid custom gradients, glass stacks, and “AI purple.”

## Motion and latency

- Typing must never wait on disk, publish, or FSEvents.
- Saves are debounced and atomic; the caret does not jump.
- Folder and note selection is immediate. No progress spinners for opening a Markdown file.
- Sidebar disclosure and window resize do not jitter the editor measure more than a standard `NavigationSplitView`.
- If something is slow (first publish, first vault scan of thousands of files), say so once in the status bar. Do not block the editor.

## Keyboard and menus

If it is not in the menu bar, it is not a feature.

Required, with standard or documented shortcuts:

| Action | Shortcut |
| --- | --- |
| New note | ⌘N |
| New folder | ⇧⌘N |
| Move to Trash | ⌘⌫ |
| Find notes | ⌘F |
| Find in note | ⇧⌘F |
| Publish site | ⇧⌘P |
| Settings | ⌘, |
| Undo / Redo | ⌘Z / ⇧⌘Z |
| Close window | ⌘W |

Arrow keys move the list when the list is focused. Tab moves between title and body. Esc clears search.

## Folders (first-class)

AAA folder support is the next product milestone. It is not a filter pretending to be a tree.

- Nested directories, unlimited depth in principle; the UI should stay comfortable to ~3–4 levels.
- Create, rename, move, trash folders from the sidebar and the menu bar.
- Drag notes onto folders; drag folders to reorder among siblings if cheap, otherwise sort A–Z and do not fake order files.
- Moving a note is a filesystem move. Update relative asset links only if we already own that rewrite; do not invent a database id.
- Empty folders remain visible (they are still directories).
- Reserved names stay reserved: `assets`, `.banal`, `.publish`, `.git`.

## Empty, error, and edge states

- Empty vault: one welcome note or a single sentence and a New Note button — not a marketing page.
- Empty folder: “No notes in this folder.” ⌘N still works and creates *in this folder*.
- Search with no hits: “No notes match,” keep the query.
- External edit (Vim/Finder): the open note reloads if it is not dirty; if dirty, do not clobber — say so.
- Missing vault / revoked bookmark: Settings / open-folder, not a crash.
- Publish with nothing marked: one sentence, no sheet stack.

## Settings quality

- One Settings window, standard `Settings` scene, toolbar or sidebar tabs.
- Tabs: **General**, **Editor**, **Publish**. That is enough. See [`PREFERENCES.md`](PREFERENCES.md).
- Every control has a plain-language label. No internal codenames (`BANALPublisher`, `entity id`) in the UI.
- Defaults are correct. A user who never opens Settings still has a good app.
- Publish tab is fully laid out *before* deploy is implemented: disabled or “not connected” states are designed, not omitted.

## Accessibility

- Full VoiceOver on sidebar, list, editor, and Settings.
- Hit targets in chrome ≥ 20 pt.
- Do not convey published-only-by-color; keep the globe (or equivalent) plus the checkbox.
- Reduce Motion honored (no decorative animation).

## What “done” means for a UI change

1. It matches this file’s layout and type rules.
2. Light and dark both look intentional.
3. Narrow and wide window both work.
4. Keyboard path works without the mouse.
5. The running app was exercised — compile is not QA.

The current SwiftUI shell is an MVP. It is allowed to be incomplete. It is not allowed to set a lower permanent bar than this document.
