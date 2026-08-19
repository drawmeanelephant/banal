# Card D-4 — Find the saffron

**Milestone:** M8 · **Lane:** list · **Depends:** C-1 sat · **Status:** ready — ⌘F matches names Oliver already knows

## Handoff

- **Not started.** List search matches title and body. A
  `.cook` file already contains `@saffron{}`, so the bytes
  often hit. This card is the typed name — including names
  that only appear after D-3 inlines a sauce — not a food
  database.
- **Not this card:** sauce walking (D-3), tags as a sidebar
  place, All Recipes, pantry.

## Owns

- `AppModel` / `NoteStore` list filter (`notes(matching:query:)`)
- A disposable in-memory cache of Oliver ingredient names
  per `.cook` id
- Tests: query “saffron” hits a recipe; missing Oliver still
  matches the file body

## Do not touch

- Recipe Read layout
- Sidebar chrome (no Ingredients smart list)
- SQLite, Spotlight importers, a second notes database

## Why

Search is already the way you find a note. A cook should
type an ingredient and see the risotto, because Oliver
parsed the name — not because we built an ontology.
Disk stays truth. The cache dies on quit.

## Do

1. For `.cook` notes, ask Oliver `serialize --json` the same
   way Read does (idle, last buffer, skip if no binary).
   Collect `ingredientIndex` names.
2. ⌘F matches those names as well as title and body. Case
   insensitive, same as today.
3. After D-3, the same index may include inlined sauce
   names. Do not wait for D-3 to ship a body-search test
   and a parsed-name test on one file.
4. Cache is memory + note id + file mtime (or the store’s
   existing revision). No sidecar, no SQLite.
5. Missing Oliver: title + body still search. Silent, same
   as B-7.

## Do not

- A Recipes filter in the sidebar unless it is literally
  “this query” and you can delete it in a sentence. Prefer
  the `Recipes/` folder.
- Stemming, aisle sort, or “you might also have cumin.”
- Searching the web, or NYT Cooking.

## Gate

Type “saffron” with the risotto in the vault. The list
finds it. Finder still shows an ordinary `.cook` file.
No new chrome. `swift test` stays green.
