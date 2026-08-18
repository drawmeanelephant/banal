# How BANAL wins

A dissertation on staying dead simple on the outside while being
dangerously good at Markdown, Textile, and Cooklang — notes and
recipes, same folder, same joy.

This file is the long picture. The **North Star** is
[`NORTH-STAR.md`](NORTH-STAR.md) — shorter, and it wins when the two
disagree. Build from [`cards/`](cards/README.md). Do not grow this
file.

---

## 0. The bet

Most notes apps fail in one of two ways.

They stay simple and go dumb: a text box, no craft, no recipes, no
way to grow a public site without emigrating to another tool.

Or they get smart and go ugly: graphs, plugins, daily-note
religions, a chrome budget that looks like an IDE, a recipe app
bolted on as a tab.

BANAL takes the third door.

**The window looks like a finished Mac notes app.** Folders.
A list. A page of text. That is what you see on a Tuesday.

**The file is allowed to be a real document.** CommonMark when you
are thinking. Textile when you want phrase-level craft. Cooklang
when dinner is the note. Oliver understands all three. Boris
publishes the ones you mark.

The joke in the name is real. The finish is not. Superhappyfuntimes
is the *feeling after dinner and a paragraph*, not a mascot, not a
mode called Fun, not a purple gradient.

If the app ever needs a tour to explain itself, this dissertation
has failed.

---

## 1. What success looks like

A person opens BANAL the way they open Notes.

They have a notes folder in iCloud Drive or on a disk they own.
`Inbox/`, `Essays/`, `Recipes/Sauces/`. Finder shows the same
tree. They write a thought in Markdown. They file it. They search.
They do not think about engines.

On Thursday they open `Recipes/Mains/risotto.cook` and the file is
still a file: ingredients with quantities, steps, a timer, a note
about stock. They scale the reading view to dinner-for-six. They
do not get a meal-planning SaaS. They get a recipe that parsed.

On Sunday they flip **Published** on three essays and a sauce.
File → Publish Site… runs Boris. A quiet static site appears.
Cloudflare is a Settings pane they filled in once, or not at all.

Six months later the same folder opens in Vim. Nothing is trapped.
Nothing nagged them into an account. The app is still the same
shape.

That is winning. Feature depth that never changes the silhouette.

---

## 2. The paradox we have to hold

**Look simple. Be fluent.**

Simple-looking is a visual and interaction budget:

- Three columns. Folders · notes · page.
- One type family pairing. Quiet chrome. System accent only.
- No mode switcher that looks like a DAW.
- No graph. No calendar. No shopping-list sidebar.
- If it is not in the menu bar, it is not a feature.

Fluent is a *language* budget, not a chrome budget:

- Markdown is the default prose: CommonMark, the boring excellence.
- Textile is first-class for people who think in `h2.` and phrase
  modifiers — not a compatibility stunt.
- Cooklang is first-class for recipes — a typed recipe, not
  Markdown with `@ingredient` stickers glued on.

Oliver already treats these honestly. Markdown and Textile
converge on one document model. Cooklang keeps its own `Recipe`
because quantities, cookware, and timers are not emphasis. BANAL
must not flatten that distinction in the UI *or* hide it behind
three different apps.

The test: a stranger sits down, writes a note, files it, and never
learns the word Oliver. A cook opens a `.cook` file and feels
taken seriously. Both are the same window.

---

## 3. One app, three languages, zero costumes

### How a file chooses its language

The extension is the language. Disk is truth.

| Extension | Language | What it is |
| --- | --- | --- |
| `.md` | Markdown | Default note. Thinking, essays, lists, links. |
| `.textile` | Textile | Prose with Textile’s phrase and block vocabulary. |
| `.cook` | Cooklang | A recipe. Ingredients, steps, cookware, timers. |

No content-sniffing carnival. No “this `.md` is secretly a recipe.”
If it is a recipe, it is a `.cook` file in a folder named whatever
the human wants (`Recipes/` is a convention, not a schema).

A New menu can say **Note**, **Textile**, **Recipe**. That is
three items, not a platform.

### What the editor is

The editor is always **source**. AppKit `NSTextView`. Undo. Find.
Plain text with whispered highlighting if we ever do it — headings
and Cooklang sigils as *hints*, never a code-editor skin.

Oliver does not sit in the text view. Oliver is asked questions:

- What language is this? (we already know: the extension)
- Does it parse? Where are the diagnostics?
- What HTML would this be?
- What is the typed `Recipe`?

The caret never waits on a Zig process.

### What the reading view is

Prose (Markdown, Textile) may have an optional preview. It is
secondary. Source stays king. A webview must never become the
editor. A preview is a *reading* surface for Oliver’s HTML, or —
better, if we can keep it small — native drawing of the document
model.

A recipe deserves a reading view more than an essay does. Cooking
from source fences is possible and a little macho; cooking from a
clean ingredient list and numbered steps is kind. So:

- **Edit** is the `.cook` source. Always real. Always the file.
- **Read** is Oliver’s recipe model: ingredients, cookware, steps,
  notes, a scale control (2×, ½) that is *display math*, not a
  rewrite of the file unless the user asks to save a scaled copy.

Scaling is application logic. Oliver parses quantities; it does
not cook. BANAL may scale the reading view. Boris may scale at
publish. Neither silently mutates the source.

### What we refuse to add because recipes exist

Cooklang’s own ecosystem conventions include shopping lists,
pantry, aisles, meal plans, `.menu` as a planner. Oliver
correctly parses `.menu` as Cooklang and refuses to become a meal
app.

BANAL follows Oliver:

- No pantry.
- No weekly meal calendar.
- No aisle-sorted grocery subscription.
- No “import from NYT Cooking.”
- Recipe references (`@./sauces/Hollandaise{150%g}`) are stored
  as written. Resolving them for *reading* can walk the vault
  folder. Resolving them for *publishing* is Boris’s job. We do
  not invent a second graph of recipes in Swift.

A recipe is a note that happens to be dinner. File it next to
essays. That is the bit that is actually sexy.

---

## 4. Notes plus recipes is one silhouette

The fear is that recipes fork the product: a Notes tab and a
Recipes tab, two inspectors, two identity crises.

The rule: **recipes do not get their own chrome.**

They get:

- A different extension and New item.
- A reading view that understands a `Recipe`.
- Search that can match ingredient names because Oliver told us
  the names, not because we built a food ontology.

They do not get:

- A different sidebar.
- A different Settings app.
- A “kitchen mode” with wood grain.
- A social layer.

Folders already solve organization. `Recipes/Mains`,
`Recipes/Desserts`, `Notes/Travel`. The human’s taste, not our
taxonomy.

If a feature would only make sense if we were Paprika or
Obsidian, it does not ship.

---

## 5. The three engines, and who is allowed to speak

```text
        ┌─────────────────────────────────────┐
        │  BANAL  (Mac window, folders, I/O)  │
        │  disk is truth · TextKit is truth   │
        └───────────┬─────────────┬───────────┘
                    │             │
                    ▼             ▼
              ┌─────────┐   ┌──────────┐
              │ Oliver  │   │  Boris   │
              │ markup  │   │  site    │
              └─────────┘   └──────────┘
```

### BANAL

Owns the human loop. Vault, folders, list, editor, menus,
Settings, bookmarks, Keychain. Decides nothing about CommonMark
edge cases and nothing about Trunk/Satellite validity.

### Oliver

Owns **what the bytes mean**. Clean-room CommonMark, Textile,
Cooklang. Typed documents and typed recipes. Deterministic HTML.
No filesystem, no templates, no Cloudflare, no plugins.

BANAL calls Oliver as a **subprocess or linked library**. It does
not reimplement Oliver in Swift. It does not copy Solipsist’s
Compose highlighter and call it a day.

### Boris

Owns **the site**. Discovery, closed publish grammar, validated
graph, layouts, `dist/`, RSS, the path to Cloudflare Pages.

The graph is a compile artifact. It is how a site does not lie
about parents, drafts, and links. It is **not** a pane in BANAL.
No inspector. No backlinks map. No trunk-and-satellite tutor.

When the user publishes, BANAL stages files (including `.cook`
and `.textile` as Boris/Oliver already understand them), runs
Boris, writes the artifact, optionally deploys. Local notes never
wait on that.

### Solipsist

A cousin. A documentation IDE. We do not take Compose, the
inspector, companions, or the mail-as-publication chrome. Shared
grandparents (Oliver, Boris) are not a license to share a face.

---

## 6. How the simple window stays simple

This is the part that usually dies in committee. Write it on the
glass.

1. **One sidebar.** Folders, All, Published. Tags remain a filter,
   not a place. No “Recipes” smart library unless it is literally
   “all `.cook` files,” and even that is a maybe.
2. **One list row.** Title, snippet, date, a quiet mark if
   published. A `.cook` file may show a tiny bowl or nothing. If
   the icon needs a legend, delete the icon.
3. **One editor chrome.** Title. A thin metadata row (published,
   tags, language is the extension). Body. For recipes, a
   **Read / Edit** segmented control *in the detail pane*, not a
   new column.
4. **Diagnostics are polite.** A failed Cooklang parse is a
   sentence under the title or a mark in the list, not a problem
   inspector cloned from Solipsist.
5. **Publish is Export.** ⇧⌘P. Settings already know the site
   name and the Cloudflare project. Success is a folder of HTML
   and maybe a deploy. Failure is one sentence.
6. **Preferences stay three panes.** General, Editor, Publish.
   Language support is not a fourth pane of toggles. If Markdown
   extensions need a switch (wikilinks, task lists), it is one
   Editor subsection, default on for the friendly ones, never a
   plugin mall.

Dead sexy is mostly deletion.

---

## 7. Superhappyfuntimes, operationalized

Fun is not a feature. Fun is what is left when nothing fights you.

- Typing is instant. Always.
- Folders are Finder. Always.
- A recipe scales in the reading view without a lecture.
- Textile does not apologize and does not get a wizard.
- Publish is a little thrill the first time and boring forever
  after.
- The app looks expensive and costs the user no conceptual rent.

The anti-fun list, so we do not accidentally ship it:

- Onboarding carousels.
- Streaks, karma, “you wrote 3 notes this week.”
- AI that finishes your risotto.
- Themes named after cities.
- A graph that makes your sauce collection look like CIA.
- Any UI that requires the word “pipeline.”

---

## 8. How we know we are succeeding

Not Product Hunt. Not feature matrix bingo.

**Feel tests**

- A writer uses it for a month and never opens Settings.
- A cook keeps `.cook` files in the same vault as letters and
  does not ask “where did the recipe app go.”
- Someone who loves Textile does not feel like a legacy user.
- A Finder window on the vault makes instant sense to a skeptical
  friend.

**Engineering tests**

- Disk and UI never disagree about folders or filenames.
- Oliver is the only parser. Swift does not grow a second
  CommonMark.
- Boris is the only publisher. BANAL does not grow a second SSG
  except the tiny builtin fallback for machines without Boris.
- No graph UI lands “just for debugging” and stays.

**Failure tests — stop and rewrite the picture if any of these
become true**

- The default window has more than three columns of product
  chrome.
- Recipes require a separate onboarding.
- Users keep a second app for “real notes.”
- Publishing is required to feel like the app works.
- Someone has to say “it’s like Obsidian but…” as the explanation.

---

## 9. Sequence (so the dream does not eat the notes app)

The silhouette ships first. Languages deepen second. Publish
gets real last.

1. **Folders + Settings + finish** — already the roadmap. A
   beautiful Markdown notes app. This is not a placeholder. This
   *is* the product, usable forever.
2. **Oliver in the basement** — version, parse this buffer,
   diagnostics, optional preview for Markdown. Still one
   silhouette.
3. **`.textile` and `.cook` as files** — New Recipe, New Textile,
   icons whispered, reading view for Cooklang, scale display.
4. **Boris publish of the mixed vault** — marked notes and
   recipes become a site. Graph stays in the compiler.
5. **Cloudflare deploy** — the button already drawn in Settings.

Do not start at 3 because it is more exciting. A gorgeous empty
recipe tab is how this gets ugly.

---

## 10. The sentence we keep

BANAL is a dead-simple Mac notes app whose files are allowed to
be excellent: Markdown, Textile, and Cooklang, published with
Boris when you ask.

If a change makes that sentence longer, it is probably wrong.
If a change makes the window busier, it is definitely wrong.
If a change makes dinner and a paragraph feel like the same
kind of easy — that is the work.
