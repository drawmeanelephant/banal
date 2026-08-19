# Card B-9 — Cook from the reading view

**Milestone:** M5 · **Lane:** detail · **Depends:** B-7, B-8 · **Status:** cooking — Edit | Read, view-only scale

## Handoff

- **Landed:** `.cook` gets Edit | Read in the metadata row (View → Edit Recipe / Read Recipe). Read is a native list: ingredients, cookware, steps, notes. Scale is ½ 1× 2× 3× via `oliver scale` then `serialize --json`; the file is never rewritten. Session remembers Edit/Read; new recipes open in Edit; scale resets per note. Parse failure is one sentence. Markdown/Textile have no switcher. Sample `Recipes/risotto.cook` is cookable.
- **Not this card:** Markdown/Textile preview, save a scaled copy, resolving `@./sauces/…`, Oliver path in Settings.

## Owns

- Detail pane for `.cook` only: Edit / Read
- Reading view driven by Oliver’s typed `Recipe` (or its HTML
  policy if that is the honest short path)
- Display-only scale (½, 1×, 2×, 3×)

## Do not touch

- The TextKit editor for source
- Pantry, shopping list, meal calendar, `.menu` planner logic
- Silently rewriting the `.cook` file when the user scales

## Why

Cooking from source fences is a flex. Cooking from a clean
ingredient list and numbered steps is kindness. The window stays
one silhouette: a segmented control *in the detail pane*, not a
new column, not a Kitchen Mode.

Oliver parses; it does not cook. Quantities are typed. Scaling
the *view* is application logic. Saving a scaled copy is a later
card if anyone asks.

Recipe references (`@./sauces/Hollandaise{150%g}`) stay as written.
Resolving them for reading may walk the vault. Do not build a
recipe graph UI.

## Do

1. `.cook` selected → Edit | Read in the metadata row. Default
   **Edit** for a new file, **Read** if you must pick one for
   cooking — prefer remembering the last choice per session.
2. Edit is the existing source editor. Nothing special except
   maybe whispered sigils later (not this card).
3. Read shows: title, ingredient list with quantities/units,
   cookware, steps, notes. Type matches B-1 (SF, measure).
4. Scale control: ½ 1× 2× 3×. Numbers update in the view only.
5. Parse error: one sentence, switcher still offers Edit.
6. Markdown/Textile do **not** gain this switcher in this card.
   Optional prose preview is a different, later card.

## Do not

- WKWebView as the only path if a small native list+stack is
  enough. If you use a webview, it is read-only Oliver HTML,
  sandboxed, not the editor.
- Checkboxes that persist “done” steps into a sidecar database.
- Nutrition, timers that hijack Notification Center as a product.
  A displayed timer value from Cooklang is fine.

## Gate

Open `risotto.cook`. Hit Read. Ingredients are a list a human
can cook from. Flip 2×. Source file on disk is unchanged. Flip
Edit: the caret is in the `.cook` text. A skeptical cook does
not ask where the recipe app is.
