# Card B-8 — Three languages, one list

**Milestone:** M5 · **Lane:** core + app · **Depends:** B-7 · **Status:** cooking — three extensions in one list

## Handoff

- **Landed:** Vault scan accepts `.md`, `.textile`, `.cook`. File → New Note / New Textile / New Recipe. `Note.id` is the vault-relative path *with* the extension so `hello.md` and `hello.cook` can coexist. `.md`/`.textile` keep BANAL YAML; `.cook` writes `>> title` / `>> tags` / `>> published` and never a `---` fence. Cooklang `>> servings` and user YAML stay in the body. List: quiet `fork.knife` on recipes, no legend, no All Recipes. Oliver is asked `--from` from the extension (still no preview). Sample vault has a Textile page and `Recipes/risotto.cook`.
- **Not this card:** recipe Read view (B-9), Boris staging of mixed extensions (B-10), a Languages pane.

## Owns

- Note identity / scanner to accept `.md`, `.textile`, `.cook`
- New Note / New Textile / New Recipe
- Quiet list affordance (or none)
- Frontmatter / Cooklang metadata boundary (do not fake YAML)

## Do not touch

- Recipe reading view layout (B-9)
- Boris graph
- Language sniffing of file bodies

## Why

The extension is the language. That is how Finder, git, and Oliver
stay aligned. A `.cook` file in `Recipes/Sauces` is a note. It does
not need a Recipes tab.

## Do

1. Vault scan includes `.md`, `.textile`, `.cook`. Reserved dirs
   still skipped.
2. File → New Recipe writes `….cook` with a tiny Cooklang stub
   (one ingredient, one step). New Textile writes `….textile`.
   New Note stays `.md`.
3. Language is the extension. No “convert to recipe” that
   rewrites prose into Cooklang.
4. List: same row chrome. Optional tiny glyph for `.cook` — if it
   needs a legend, delete the glyph.
5. Search still matches title and body. Later B-9 can add
   ingredient names from Oliver’s `Recipe`; not required here.
6. Tests: create each kind, reload, extension preserved.

## Do not

- A Languages settings pane.
- Smart folder “All Recipes” unless it is a one-line filter you
   can delete in a sentence. Prefer `Recipes/` as a real folder.
- Import from Paprika / NYT Cooking.

## Gate

A vault with one essay, one Textile page, one risotto. All three
in All Notes. Finder shows three extensions. Opening each is just
source in the editor.
