# Card F-9 — Imported notes can get `updated:` bumped (stale-buffer write race)

**Milestone:** bug follow-up (found during the F-8 gate probe) · **Lane:** editor · **Status:** open — one occurrence, content-safe, race not reproduced under probe; do not start until this write-up is read

## Handoff

- **Found:** 2026-08-19, during the F-8 out-of-container gate probe on this
  machine. Importing the sample `Welcome.md` into a fresh container vault
  produced a `Welcome-2.md` that differed from the source **only** in the
  frontmatter `updated:` field — source `2026-08-18T16:00:00Z`, imported
  `2026-08-19T17:12:07Z` (the import moment). `diff` showed a single line
  (`4c4`). Title, body, tags, and published were all correct.
- **Not this card:** multi-file `open -a` delivery dropping all but the first
  file (separate delivery question, still human-gated), the F-8 feature
  itself (landed), or a rewrite of the editor's flush machinery.
- The F-8 import contract — "disk stays truth", byte-faithful copies — is
  violated only by this race, never by `importFile` itself.

## Reproduction evidence

### The one occurrence

```
vault = fresh container vault; app launched with BANAL_VAULT
open -a dist/BANAL.app Examples/sample-vault/Recipes/risotto.cook
# ~2s later
open -a dist/BANAL.app Examples/sample-vault/Welcome.md
# ~4s later the vault's Welcome-2.md has updated: 2026-08-19T17:12:07Z
```

The write landed ~4s after the import — debounced-writer timing, not the
copy. Checksums of `risotto.cook` were byte-identical in the same run.

### What the probe ruled out

- `NoteStore.importFile` is `copyItem` → `NoteIO.load` → `upsert`. It never
  writes; the copy is byte-faithful.
- `store.update` is the only write entry that bumps `updated = Date()`.
  Instrumenting it with `NSLog` (temporary, removed) and re-running the same
  back-to-back flow **7 times, plus single-open runs: the probe never
  fired**. 6/6 clean runs imported both files byte-identical, including
  `updated:`.
- Conclusion: the write did not come through `store.update` in any
  reproducible run — the one occurrence was a timing race. The import path
  is exonerated; the defect lives in the editor's write-back.

## Mechanism hypothesis (best fit, unproven)

- `openImportedNote` → `select(id)` → `selectedID = id`, then `loadEditor`
  sets four `@Published` fields (`editorTitle`, `editorText`, `editorTags`,
  `editorPublished`) with `suppressEditorSync` toggled around the load.
- `EditorView` runs `.onChange(of: model.editorText)` and
  `.onChange(of: model.editorTitle)` → `applyEditorChanges()`.
- `applyEditorChanges` guards `!suppressEditorSync` and early-returns only
  when the *current* buffer fields all equal the *currently selected* note.
  If SwiftUI delivers the `editorText` change while `editorTitle` still
  holds the previous note's value (the two callbacks can land in different
  view-update batches during rapid switches), the comparison fails and the
  note is written with a stale field; `store.update` then bumps `updated`.
- The same machinery serves every note switch, so the race is not specific
  to imports — rapid ⌘N / list clicking could hit it too. The observed case
  was content-safe (only `updated` changed); a stale title/body write is
  theoretically possible in the same window.

## Do

1. Make `applyEditorChanges` verify the buffer it writes belongs to the note
   it was loaded for — e.g. capture `selectedID` + `editorSessionID` at load
   and require both at write; or route the comparison through
   `loadedFingerprint` instead of live `@Published` reads.
2. As a belt-and-braces option: in `NoteStore.update`, bump `updated` only
   when a persisted field actually changed vs the existing note (compare
   before mutating) — makes the cosmetic harm impossible even if a stale
   write slips through.
3. Reproduce first, fix second. Try: fresh container vault, two `open -a`
   deliveries 1–2s apart with no sleep in between, repeat until the race
   fires; check `diff` on the imported `.md`.

## Do not

- Change `importFile` (it is correct).
- Weaken the `store.update` early-return.
- Break C-1 rules: typing, undo (30s ⌘Z), and caret behavior stay.

## Gate

Back-to-back `open -a` imports are byte-identical across ≥10 runs (including
`updated:`); the race no longer reproduces; normal typing/undo unaffected;
`swift test` green; `make smoke` green.
