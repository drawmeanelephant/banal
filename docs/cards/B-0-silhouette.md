# Card B-0 — Silhouette

**Milestone:** M3 · **Lane:** chrome · **Status:** cooking — three-column window, two-line rows, metadata row

## Handoff

- **Landed:** `NavigationSplitView` ~200 / ~280 / rest. Two-line snippets, globe if published, title + quiet metadata row. No toolbar icons. Transient status strip (no capsule). 1100×720 default; 720×520 still shows list + editor. Light + dark + 900×560 exercised.
- **Sit (this session):** Default 1100×720, 1400×800, 720×520 in light and dark. Three columns, no toolbar icons, two-line rows, globe on published, title + quiet metadata. Sidebar stayed up at 720 (allowed). VoiceOver still not done. List selection via Accessibility is flaky (not a product bug).

## Owns

- `Sources/BANALApp/Views/ContentView.swift`
- `Sources/BANALApp/Views/SidebarView.swift`
- `Sources/BANALApp/Views/NoteListView.swift`
- `Sources/BANALApp/Views/EditorView.swift`
- Window sizing in `BanalApp.swift`

## Do not touch

- Publish / Boris / Oliver
- Folder filesystem semantics (B-4)
- Settings panes (B-5) except as they affect window chrome
- Adding a fourth column, inspector, or toolbar junk drawer

## Why

People decide in two seconds whether this is a real Mac app or a
SwiftUI demo. The silhouette is the product: folders · list · page.
Everything else is a file format or a menu item. If the window looks
busy, Textile and Cooklang will never feel like a treat — they will
feel like more UI coming.

## Do

1. Three columns via `NavigationSplitView`. Sidebar ~200pt, list
   ~280pt, editor takes the rest. Minimum width still shows list +
   editor; sidebar may collapse.
2. No toolbar icons for New / Publish / AI / Preview. Those live in
   the menu bar (B-6).
3. List rows: title, two-line snippet, relative date, optional globe
   if published. No cards, no hero images, no unread dots.
4. Editor chrome is title + one quiet metadata row. Body is a page,
   not a panel.
5. Light and dark both look intentional (semantic colors only).
6. A 1100×720 default that does not look lost on a studio display
   (measure is B-1) and does not crush at 900×560.

## Do not

- Add a preview column in this card.
- Add a status bar that is always visible. Transient status only.
- Imitate Solipsist mail chrome (accounts, mailboxes, inspector).
- Use materials as decoration.

## Gate

A screenshot of the default window, light and dark, with three
notes and two folders, that you would show someone who hates
Electron. No unexplained controls. Human pass in the running app.
