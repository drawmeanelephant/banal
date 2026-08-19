# Roadmap

Small surface. High finish. Publishing last. Then Close — sit,
honesty, a `.app`. Then Fluency — the file, not a new window.

The long route (Tucson → California → Japan → Home / M99) is
[`HOPE-CHEST.md`](HOPE-CHEST.md). This file is the gas stations
we will actually stop at. Cards in [`cards/README.md`](cards/README.md)
are the turn-by-turn. One card, one branch, one PR.

## M1 — Folders — drawn

The app becomes a notes app instead of a flat list with a sidebar costume.

- Recursive folder tree in the sidebar (real directories)
- New Folder (⇧⌘N), rename, trash, move
- New Note lands in the selected folder
- Drag notes between folders (filesystem move)
- Empty folders remain
- Tests: create/rename/move/external Finder mkdir

## M2 — Preferences — drawn

A real Settings window so Cloudflare can arrive without a redesign.

- General / Editor / Publish panes ([`PREFERENCES.md`](PREFERENCES.md))
- Vault bookmark picker in Settings
- Font, measure, sort
- Publish: site title, base URL, project name, account ID
- Keychain API token (store/replace/delete)
- Deploy enabled when a Keychain token and project name exist

## M3 — Finish — drawn, sit still open

Same features, AAA execution ([`QUALITY.md`](QUALITY.md)).

- Typography and measure
- Empty / dirty-external / missing-vault states
- Full menu bar, find, undo
- Light and dark, narrow and wide
- VoiceOver pass on the three columns + Settings
- Whole-window human pass is C-1, not a new B card

## M4 — Oliver in the basement — drawn

Parse this buffer. Diagnostics. Optional Markdown preview still not
a column. Settings path picker is C-2.

## M5 — Textile and Cooklang as files — drawn

`.textile` and `.cook` in the vault. New Recipe / New Textile. Recipe
**reading** view (ingredients, steps, display scale). No pantry. No
meal plan. Risotto sit is C-1.

## M6 — Publish for real — drawn

- Mixed vault (md / textile / cook): Markdown through Boris when present; Textile/Cooklang via Oliver in the same `.publish/` folder
- Deploy uses Keychain token + saved project/account
- Graph stays in the compiler
- Still no Worker host, no R2 browser, no billing

## M7 — Close — leftovers

The silhouette exists. Sit it and hand it over.

- C-0 Board reset (docs) — landed
- C-1 Sit the window — cooking; GUI still open
- C-2 Honesty in Settings and menus — landed
- C-3 Hand it to someone (signed `.app`, sandbox) — landed, ad-hoc; not notarized

If the sit hates the caret or publish feels like onboarding, that
bug outranks every D card.

## M8 — Fluency — current board

Look simple. Be fluent. Language budget, not chrome.

- D-0 Fluency board (docs)
- D-1 Whisper the source (hints, not a theme)
- D-2 Read a paragraph (Markdown/Textile; source stays king)
- D-3 Walk the sauce (`@./sauces/…` in Read)
- D-4 Find the saffron (⌘F matches Oliver ingredient names)

Do not pick D-1 until C-1 has been sat. Save a scaled recipe copy
is not on this board until a cook asks. Stylesheets and
tags-as-a-place are not M8.

## Beyond M8 — implement or consider

Detail and refuse-reasons live in [`HORIZON.md`](HORIZON.md).
These milestones are **not a board**. Cut cards from an
**Implement** row only after C-1 is sat and M8 is done (or the
row says it may run beside D). **Consider** rows stay named
until a human asks.

| Milestone | Verdict | One line |
|-----------|---------|----------|
| [M7 Close leftovers](#m7--close--leftovers) | **Implement now** | Sit the window. Notarize is later. |
| [M8 Fluency](#m8--fluency--current-board) | **Implement next** | Whisper, prose Read, sauce, find. |
| [M9 Type in the page](#m9--type-in-the-page--implement) | **Implement** | Source stays source. Paste and lists get Mac manners. |
| [M10 System](#m10--system--implement) | **Implement** | Siri, Spotlight, Print, Translate, Writing Tools stay system. |
| [M11 Files](#m11--files--implement) | **Implement** | Images, copy-as, import, pickers. Disk is still truth. |
| [M12 Consider](#m12--consider--not-a-board) | **Consider** | Typewriter, tags filter, quiet count, checkbox click. |

Zero-lock-in (human-readable `.md` / `.textile` / `.cook` on
disk) is not a future milestone. It is M1. If we ever need an
export wizard, we have failed.

## M9 — Type in the page — implement

After D-1, or folded into D-1 when the path is the same
(`MarkdownTextView`). The caret never jumps because we swapped
to a rich-text preview.

- Syntax *dimming*: Markdown / Textile / Cooklang markers stay
  visible at ~30% opacity, same metrics as the text (this *is*
  D-1; 30% is the recipe)
- Heading lines may take a little space-after so the title hugs
  the paragraph it introduces — still source, still one font
- Paste a URL over a selection → `[selection](url)`
- Paste from Safari / PDF → clean Markdown (headings, emphasis,
  links). Strip `span` / background / proprietary HTML. Prefer
  asking Oliver; do not grow a Swift CommonMark
- Return continues a list; Return on an empty bullet becomes a
  normal paragraph
- Smart quotes, dashes, and auto-cap **off** inside fences and
  inline backticks
- Writing Tools / dictation: do not clobber `string` while
  `isWritingToolsActive` (C-1 sit §3b)
- Column focus: ⌘1 sidebar, ⌘2 list, ⌘3 editor. Tab cycles
  forward. A person who never touches the trackpad writes and
  files notes with their hands on the keyboard

Not M9: multi-cursor, a canvas, rendered callouts, math, Mermaid.

## M10 — System — implement

Mac furniture. May start beside D if it does not touch the
editor. `#available`; do not raise the macOS 14 floor.

- Notarized `.app` (Gatekeeper)
- App Intents: New Note, New Recipe, Take a Note, Search, Open
  Notes Folder, Publish Site
- `IndexedEntity` so Spotlight / Siri open a file
- Quick Look for `.md` / `.textile` / `.cook`
- File → Print, Share, Services: New BANAL Note from Selection
- Edit → Translate… (`TranslationSession` system sheet)
- Furniture sit (VoiceOver, contrast, keyboard) after the above

## M11 — Files — implement

- Drop / Insert Photo → `assets/` + a relative link
- Copy As: Markdown / RTF / HTML (Oliver for HTML)
- Import a folder or a chat export = copy into the notes folder
- Insert Contact… / Insert File… (system pickers)
- Drag a note from the list into Mail, Messages, or Finder —
  it is a file; let it travel like one

Not M11: image snap-resize, full-bleed, hover zoom, a media library.

## M12 — Consider — not a board

Named. Not scheduled. Cut a card only if a sit asks.

- Typewriter scrolling (already a pref, off, easy to make tacky)
- Tags as a *filter*, not a place
- One stylesheet pairing (not per-note, not per-folder)
- Click `- [ ]` in *source* to toggle. Not a rendered HUD
- Quiet word/character count in the *existing* status strip.
  No read-time. No expandable statistics pill
- File → New Window on the same folder
- Browse previous versions if **macOS Versions** is cheap
- Clean Up Dictation (local, menu, undoable)
- Enrich Markup… / Suggest Title (on-device Foundation Models
  or a user binary; mission amendment; never auto)
- Option-drag column select if it is free from the text view
  and does not turn the page into an IDE

## Explicitly not on the roadmap

Daily notes, wikilinks, graph, backlinks, plugins, Electron, AI
chat, multi-vault windows-as-IDE, Solipsist Compose, hosted
accounts, a rendered canvas in the editor (outline gutter,
Mermaid/LaTeX live preview, tinted admonitions, image
full-bleed), focus/paragraph dimming, per-note typography,
menu-bar scratchpad, word-count karma HUD, a home-grown
time-machine scrubber, SwiftData/CloudKit as the store.

If one of those becomes real, it gets a new milestone and a
mission amendment — it does not sneak into M1–M12.

## Later towns (not a board)

Named in [`HOPE-CHEST.md`](HOPE-CHEST.md). Do not cut cards
from here until Tucson is behind us.

| Milestone | Town | Verdict |
|-----------|------|---------|
| M13–M19 | the drive | Blank on purpose. Sit bugs fill them. |
| **M20** | California | **1.0** — notarized `.app` a stranger can keep. Still three columns. |
| **M50** | Japan | Vacation luxury (Enrich Markup, one stylesheet, scaled recipe if asked). After M20 only. |
| **M99** | Home | The folder outlives us. Stop adding towns. |

## The quiet test

When the roadmap is done, one question:

Does a person who opens a folder, writes a paragraph, files it,
and once in a while cooks a risotto from a `.cook` file that is
still a file — does that person feel like the app was made for
exactly this Tuesday?

If yes, stop. If no, delete something.
