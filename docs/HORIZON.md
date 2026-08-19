# Horizon

Looking forward. **Not a board.** Do not pick from this file.

The destination and the wrong exits are [`HOPE-CHEST.md`](HOPE-CHEST.md)
(M99 is Home). This file is the *menu* at the next few stops.

The work is still: sit [C-1](cards/C-1-sit.md), then the [D cards](cards/README.md). If the sit hates the window, this document does not matter. When M8 closes, *cut* a later board from the rows below. Do not grow this into a product. Do not book Japan from the driveway.

AAAA here is not more surfaces. It is the feeling that Apple shipped a small app, and that the folder still opens in ten years if we do not.

Read [`NORTH-STAR.md`](NORTH-STAR.md) and [`cards/B-X-refuse.md`](cards/B-X-refuse.md) first. If a horizon idea needs a tour, a fourth Settings pane, or somebody else’s API to feel finished, it is not AAAA. It is a different app.

## How a future idea earns a place

Four questions. Fail one, stop.

1. **Does the default window change?** Folders · list · page. A new column, a People list, a chat dock, or a dashboard is a no.
2. **Can it be a file?** Prefer a file in the notes folder over a database, an account, or a pane. Finder must still make sense.
3. **Is it Mac furniture or a new product?** Print, Share, Contacts picker, Shortcuts, Spotlight — furniture. “BANAL Social,” “BANAL AI,” “BANAL Kitchen” — product. We do furniture.
4. **Does it still work on a plane, with Cloudflare unset, with Oliver missing, with the subscription cancelled?** Local notes never wait on a network. A nicety that dies when a vendor dies is not ours.

If you have to say “it’s like Obsidian but…” or “it’s like ChatGPT but…”, do not land it.

## Data sources

A source is allowed when it *lands as ordinary bytes* and uses a system picker. It is forbidden when it becomes a place in the sidebar or an identity the app needs.

| Source | AAAA shape | Dies as |
|--------|------------|---------|
| **Contacts** | Edit → Insert Contact… (the system people picker). Writes a name, maybe `mailto:` or a line of tel/email, as text. Optional: drop a `.vcf` in `assets/`. | A People sidebar. Related notes. Birthdays. A CRM. Syncing Apple Contacts into frontmatter. |
| **Photos / Files** | Insert Photo… / drag onto the page. File lands in `assets/` (or `{stem}.assets/` later). The note gets a relative link. | An attachments circus. Media library. Face gallery. |
| **Safari / Share** | Share extension or Services: selection + URL become a new `.md` in Inbox. | A read-later product. A bookmark manager. |
| **Voice / Siri** | System dictation in the page (it is an `NSTextView`). Siri / Shortcuts: “New note in BANAL” and “Take a note…” that creates a file and puts the transcript in the body. Optional Edit → Clean Up Dictation is local, undoable, never on the caret path. | A listen pane. Auto-rewrite when you stop talking. A voice product. Sending the buffer to a model we subscribe to. |
| **Calendar / Reminders** | A file named today’s date is allowed. Insert today’s date is allowed. | A calendar. A planner. Daily-note religion. |
| **Mail / Slack / “apps we subscribe to”** | If they can export a file, Import. If they cannot, we do not scrape them. | Inboxes, sync, OAuth malls. |

### Contacts, specifically

The Mac already has an address book. We should feel as obvious as Mail’s address picker and as dumb as TextEdit: pick a person, get text.

- Entitlement only when the picker ships.
- No index of people. Search still matches the bytes in the note.
- Publishing a name is just publishing a note that contains a name.

### Siri and dictation, specifically

The Mac already takes dictation. We should not invent a microphone.

- **Dictate in the page.** Edit → Start Dictation (and the system shortcut) must work because the editor is TextKit, not a webview. If C-1 finds it broken, that is a sit bug, not a feature.
- **Siri creates a file.** App Intent: New Note / Take a Note. “Hey Siri, take a note in BANAL: two cups of stock, stir, don’t rush the rice.” Lands as `Inbox/….md` or a `.cook` if they said New Recipe. Title from the first line or “Untitled.” The transcript is the body. No listen UI.
- **Schmutz is a menu, not a daemon.** Voice notes arrive as one long spoken paragraph. Edit → Clean Up Dictation may: break paragraphs, strip repeated words, turn “comma / period / new line” leftovers into punctuation, leave the language alone. Local heuristics. Instant. ⌘Z undoes the whole pass. It does **not** run when dictation ends. Silent mutation is how we stopped scaled recipes rewriting the file.
- **Richer markup is not auto.** Turning a spoken blob into headings, lists, emphasis, or Textile phrase modifiers is a rewrite of the user’s file. If we ever do it, it is Edit → Enrich Markup…, it follows the file’s extension (`.md` stays Markdown, `.textile` stays Textile, `.cook` stays Cooklang — no “convert to recipe”), it is undoable, and it is **off** until a human asks after D. It is not a personality filter and not a subscription.

Local cleanup is furniture (step 3). Enrich Markup is the same shape as the user-supplied Oliver-like binary in the AI section below: one shot, this buffer, silent if missing, never a pane, mission amendment required. Do not wire *our* model. Do not pretty-print on save.

### AI subscriptions, specifically

North Star: the app must not depend on somebody else’s API continuing to exist. Thesis failure test: AI complete / chat with notes. That is not a taste difference. That is the product.

**Import is AAAA.** A ChatGPT, Claude, or Grok export is a pile of prose. We already know what to do with prose: it becomes notes in a folder. The subscription stays in the other app.

**A model inside the window is not.** It would force a fourth Settings personality (keys, models, usage), a network path on the typing loop, and an explanation. It would make dinner and a paragraph feel like two different products.

The only shape that would even *rhyme* with Oliver and Boris is a user-supplied binary on a path, asked one question about *this buffer* after idle, silent if missing, never a pane. On Apple Intelligence Macs, the on-device Foundation Models framework is that binary — still a menu, still undoable, still silent if unavailable. That still needs a mission amendment and a human asking after D. Do not invent it from this file. Do not put our (or anyone’s) subscription in Keychain next to the Cloudflare token.

## Platform (macOS 15–27 SDK)

Pluck furniture. Leave the costume. Deployment stays **macOS 14**; new APIs are `#available`, never a raised floor to chase a keynote.

`NSTextView` is already the right bet. Most “essential game changers” are either free if we do not break them, or they want a second database we refuse.

### Adopt early (this year, some of it is a sit)

| API | Why it is ours | How, without a product |
|-----|----------------|------------------------|
| **Writing Tools on `NSTextView`** | Proofread / rewrite / summarize is system furniture, like dictation. Apple: stock `NSTextView` participates automatically. `NSWritingToolsCoordinator` is for a *custom* canvas we must never become. | C-1 sit §3b. Set `writingToolsBehavior = .complete` if the default is shy. Guard `isWritingToolsActive` so idle style / save / D-1 whisper does not clobber an inline rewrite. TextKit 2 is required for the inline experience — do not force TextKit 1. |
| **System dictation** | Same text view. | Sit it. Siri *creating* a file is step 3 (App Intents), not a microphone UI. |
| **Instruments Hang Tracing** | QUALITY: typing never waits. D-1 highlighting and Oliver idle are the stalls we will invent. | Use the lane in C-1 and D-1. Not a feature. |
| **Swift Testing (`@Test`, `@Suite`)** | Our tests are XCTest. New files may be Swift Testing. Migrate when you touch a suite. | Chore, any PR that already edits tests. Do not stop `swift test`. Do not rewrite Oliver in Swift so the macros have something clever to do. |

### Slightly not obvious (cut next board from here)

| API | Why it is ours | Trap |
|-----|----------------|------|
| **App Intents + `IndexedEntity`** | This is how Spotlight and Siri find a *note*, not a string dump. Donate title, path, body (or snippet). Open the file. Disk stays truth; the index is disposable. | Semantic *backlinks* and “related notes.” Indexing headings only after Oliver already parsed them — do not grow a Swift Markdown. |
| **`TranslationSession`** | Edit → Translate… is the system sheet. On-device. No third-party key. | A languages product. Auto-translate on open. |
| **Foundation Models (`@Generable`, `@Guide`)** | On-device, no Keychain, silent if the Mac has no Apple Intelligence. The honest engine for Suggest Title or Enrich Markup *if* those menus ever exist. | Auto-tag, auto-title on save, smart backlinking, key-point sidebars, a chat. Marketing copy will dare you. Say no. |
| **TextKit 2 viewport** | Only if D-1 whisper or a huge file stalls the main thread. Viewport layout is a fix, not a rewrite. | Custom fragment drawing that becomes Compose. |

### Never (even though the slide says “notes app”)

| API | Why it dies |
|-----|-------------|
| **SwiftData History & CloudKit sync** | Second notes database. The folder is the sync. Tombstones are Finder’s Trash. |
| **DocumentGroup + Inspector sidebar** | We are a vault window, not a document package. Inspector is Solipsist. Tabbed *second window on the same folder* is step 12, not a Document architecture. |
| **Metal canvas / Pencil sketching** | Not a board. Not a page. |
| **Image Playground / Genmoji** | `isRichText` stays false. No decorative journaling. |
| **Xcode agentic skills as a product surface** | Fine for *us* in the IDE. Not a BANAL feature. Do not ship an in-app coding assistant. |
| **DocC snippet previews** | We do not vendor a Swift CommonMark package. |

### What “as early as we can” actually means

1. **This week (sit):** Writing Tools + dictation in [`TESTING-WINDOW.md`](TESTING-WINDOW.md) §3b. If TextEdit has them and BANAL does not, that bug outranks D-1.
2. **Next Swift touch:** do not replace `string` while `isWritingToolsActive`. New tests may use `@Test`.
3. **After C-1, beside D if paths stay clean:** App Intents + `IndexedEntity` (steps 3–4). Translation menu (step 9 family).
4. **After M8, if a human asks:** Foundation Models behind Enrich Markup / Suggest Title — menu, undo, `#available`, no pane.
5. **Never raise the macOS 14 floor** for any of the above.

## Twelve steps after Close + Fluency

These are a sequence, not issues. Names are for talking. They become cards only when M8 is done and C-1 is sat.

| # | Name | What AAAA looks like | What we refuse while doing it |
|---|------|----------------------|-------------------------------|
| 1 | **Gatekeeper** | Developer ID + notarized `.app`. A friend double-clicks without a terminal. Re-sit first-run under sandbox. | Sparkle as a Settings pane. An account to download. Recreating a vanished folder “because Gatekeeper is hard.” |
| 2 | **Print and Share** | File → Print the page (source or recipe Read). Share sheet. Services: “New BANAL Note from Selection.” | PDF-as-a-product. Letterheads. A share dashboard. |
| 3 | **Shortcuts and Siri** | App Intents: New Note, New Recipe, Take a Note (dictation → file), Search, Open Notes Folder, Publish Site. One intent each. System dictation already works in the page. | A Shortcuts marketplace. A listen pane. Auto-rewrite when speech ends. |
| 4 | **Spotlight and Quick Look** | The system finds titles and bodies. Spacebar on a `.cook` shows a quiet preview. | A second search UI. A Quick Look editor. |
| 5 | **Furniture sit** | VoiceOver, Reduce Motion, Increase Contrast, full keyboard, light/dark, 720 and 1400 — again, after D. Help is one page in the Help menu, not a site. | Onboarding carousel. Telemetry. In-app chat support. |
| 6 | **Stylesheets** | One written pairing beyond raw SF if we must — still system-honest, still not a store. QUALITY already named this. | Themes named after cities. A marketplace. Serif coming back as a personality. |
| 7 | **Tags as filter** | Tags stay on the note. A filter section in the sidebar, secondary, deleteable in a sentence. Folders remain the place. | Tags as structure. Nested tag graphs. A Tags pane. |
| 8 | **Images that file themselves** | Drag a picture onto the page → `assets/` + a relative link. Publish grows `{stem}.assets/` when Boris wants it. | Attachment inspector. Image CDN. “Library.” |
| 9 | **System pickers** | Insert Contact…, Insert Photo…, Insert File…. Menus, not chrome. | People / Photos / Files as sidebar places. |
| 10 | **Import is copy** | Import a folder of Markdown, a Bear/Notes export *if it is files*, a chat export. Copy into the notes folder. Disk is truth. | Live sync from another app. Importers as a platform. Notion OAuth. |
| 11 | **Publish, still Export** | `published_at` / `summary` when Boris has them. Custom domain is a sentence in Settings, not a wizard. Builtin HTML less embarrassing for machines without Boris. | A hosting dashboard. Worker/R2 host. Auto-publish on save. |
| 12 | **Same folder, more Mac** | File → New Window on the *same* notes folder. Browse previous versions if macOS Versions is cheap. Save a scaled recipe copy if a cook has asked. | Multi-vault IDE. Split-library windows. A Versions product. Pantry. |

Step 1 is support. Steps 2–5 are why it feels expensive. Steps 6–12 are refinement that still looks like the same Tuesday.

The implement/consider cut of those steps is [`ROADMAP.md`](ROADMAP.md) M9–M12. Do not pick them until M8 has cards.

## Scored: editor-suite wish list

A third list of “notes app” niceties. Scored so it cannot sneak in as polish.

### Implement (source stays source)

| Wish | Where |
|------|--------|
| Syntax dimming, not hiding (~30% markers, same metrics, no cursor jump) | **D-1 / M9.** This is whisper. If markers disappear, you hid syntax. |
| Heading hugs the paragraph it introduces | **D-1 / M9** as paragraph metrics on the heading *line*. Not a rendered preview. |
| Paste URL over a selection → `[text](url)` | **M9** |
| Paste rich text from Safari/PDF → clean Markdown | **M9.** Ask Oliver. Strip spans and colors. |
| Return continues a list; empty bullet breakout | **M9** |
| Smart quotes / dashes / auto-cap off in fences and backticks | **M9** |
| Writing Tools + dictation in the stock text view | **C-1 sit**, harden in M9 |
| Zero-lock-in folder of files | **Already M1.** Not a feature. A constraint. |
| Drop image → file + relative link | **M11** (horizon step 8) |
| Copy as Markdown / RTF / HTML | **M11** |
| Siri / Spotlight / Print / Translate | **M10** |

### Consider (named, not scheduled)

| Wish | Shape if we ever cut a card |
|------|-----------------------------|
| Typewriter scrolling | Pref already exists, default off. M12. |
| Click checkbox | Toggle `- [ ]` in source. Not a rendered animation. M12. |
| Word / character count | Existing status strip, one quiet number. No read-time, no expandable HUD. M12. |
| Tags filter | Sidebar *filter*, not a place. M12 / horizon step 7. |
| One stylesheet | Global pairing. Not per-note. M12 / step 6. |
| Second window | Same notes folder. M12 / step 12. |
| Local history | macOS Versions if cheap. Not a built-in scrubber. |
| Multi-cursor / Option-drag | Only if the text view gives it for free. Easy to become BBEdit. |
| Clean Up Dictation / Enrich Markup | Menu, undo, never auto. Horizon leftovers. |

### Never (a second editor)

| Wish | Why it dies |
|------|-------------|
| Swap to rendered rich text in the editor | Cursor jumps. Source is king. That is D-2 Read, a *second* surface. |
| Collapsible outline gutter | Chrome in the page. An outliner. |
| Live LaTeX / Mermaid in the editor | Preview thread, often a webview. Oliver does not become Graphviz. |
| Tinted `> [!NOTE]` callouts | A flavor of Markdown we do not own. Render in D-2 only if Oliver already emits it — no Swift dialect. |
| Click rendered checklist with animation | File mutation from a costume. |
| Image snap-resize, full-bleed, hover zoom | Attachments circus. QUALITY left this at Apple Notes. |
| Focus / paragraph dimming | iA Writer as a religion. QUALITY left it there. |
| Per-note or per-folder font pairings | One pairing. Serif-as-personality already died in B-1. |
| Menu-bar scratchpad / Daily Scratch | Extra app + daily-note ritual. Services / New Note in Inbox is enough. |
| Word-count karma HUD | Thesis anti-fun list. |
| Home-grown time-machine scrubber | A Versions product. Use the system or git in Finder. |

## Support, without becoming a company that needs a dashboard

- **Crash reports** go to the system. We do not operate analytics.
- **About** already has the mission sentence. A mailto or a discussions URL is enough. No in-app ticket form.
- **Updates** are a new `.app` the human chose, until someone is actually shipping builds weekly. Then Sparkle may be a *menu item*, never a fourth pane, never an account.
- **Privacy** is the folder. No cloud of ours. Contacts/Photos entitlements are used only for the picker that just shipped.
- **Localization** is later, and only after the English empty states are sentences we would say out loud.

## Named leftovers (still not a pane)

Already spoken for, still waiting for a human to ask or for M8 to close:

- Save a scaled recipe copy — [B-X](cards/B-X-refuse.md)
- Stylesheets — step 6
- `{stem}.assets/`, `published_at`, `summary` — step 8 / 11
- Tags as filter — step 7
- Clean Up Dictation (local, menu, undoable) — step 3
- Enrich Markup… / Suggest Title — not a card until someone asks after D; on-device Foundation Models or a user binary; never auto
- Writing Tools + dictation sit — C-1 / [`TESTING-WINDOW.md`](TESTING-WINDOW.md) §3b
- App Intents `IndexedEntity` — steps 3–4
- `TranslationSession` — system sheet, after C-1

## Never, even later

Copied here so this file cannot be used as a wedge:

Graph, backlinks, inspector, Solipsist Compose, pantry / meal plan / shopping list, AI chat, daily-notes ritual, plugin mall, Electron, webview as editor, fourth Settings pane, streaks, themes store, sync we operate, Worker host, wikilinks, All Recipes as a costume, multi-vault windows-as-IDE.

If one of those becomes real, it needs a mission amendment. It does not sneak in as a nicety.
