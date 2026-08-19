# Card D-3 — Walk the sauce

**Milestone:** M8 · **Lane:** detail · **Depends:** C-1 sat · **Status:** ready — `@./sauces/…` cooks; the file stays written as written

## Handoff

- **Not started.** Oliver’s `serialize --json` leaves recipe
  references as text (`@./sauces/Hollandaise{150%g}`). Read
  shows that string. B-9 forbade a recipe graph.
- **Not this card:** prose Read (D-2), save a scaled copy
  (named on B-X until a cook asks), pantry, shopping list.

## Owns

- `Sources/BANALApp/Views/RecipeReadView.swift`
- `Sources/BANALPublisher/OliverRecipe.swift` if refs become a
  typed part
- A small vault walk next to the recipe file (BANALCore or
  Publisher — keep UI off the walker)
- Tests: fixture risotto + sauce, missing sauce, cycle

## Do not touch

- The TextKit editor
- `EditorView` switcher chrome (already exists for `.cook`)
- Publish / Boris graph
- A Swift Cooklang

## Why

A risotto that includes a sauce is still one note. Cooking
from Read should see the sauce’s ingredients, scaled if the
reference says `{150%g}`. The source stays `@./sauces/…`.
Finder still shows two files. We do not grow a recipe
ontology.

## Do

1. Read Oliver’s current serialize. If references are now a
   typed part, decode them. If they are still text, walk
   `@./…` from the `.cook` source — not a grammar, a path.
2. Resolve relative to the recipe’s directory. Load the
   target `.cook`. Ask Oliver to serialize (and scale when
   the reference carries a quantity). Inline those
   ingredients and cookware into *this* Read.
3. Bound the walk (one hop, or at most three). A cycle or a
   missing file is one sentence. Edit still works.
4. The open `.cook` is never rewritten. Scale on the risotto
   still scales the view, including inlined sauce amounts if
   Oliver will do that math — do not invent quantity code.
5. Publish stays Boris’s job. Do not resolve refs in
   `.publish/` from this card.

## Do not

- A backlinks pane, a sauce inspector, or “included by.”
- Fetching recipes off the network.
- Flattening two files into one on disk.
- Checkboxes, pantry, or a shopping list of the union.

## Gate

`Recipes/risotto.cook` references `./sauces/Hollandaise.cook`.
Read shows butter and yolks as ingredients you can cook.
The risotto file on disk still says `@./sauces/…`. Flip
Edit: caret in the source. `swift test` stays green.
