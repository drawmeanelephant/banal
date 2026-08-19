# Card F-9 — Imported notes can get `updated:` bumped (stale-buffer write race)

**Milestone:** bug follow-up (found during the F-8 gate probe) · **Lane:** editor · **Status:** fixed — session-guarded writes in `AppModel`, `updated` only moves on a real change; gate passed 10/10 (see below)

## Handoff

- **Found:** 2026-08-19, during the F-8 out-of-container gate probe on this
  machine. Importing the sample `Welcome.md` into a fresh container vault
  produced a `Welcome-2.md` that differed from the source **only** in the
  frontmatter `updated:` field — source `2026-08-18T16:00:00Z`, imported
  `2026-08-19T17:12:07Z` (the import moment). `diff` showed a single line
  (`4c4`). Title, body, tags, and published were all correct.
- **Not this card:** multi-file `open -a` delivery dropping all but the first
  file (separate delivery question — fixed since via the `openURLs`
  delegate route), the F-8 feature itself (landed), or a rewrite of the
  editor's flush machinery.
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

## Fix landed

- `AppModel`: `loadEditor` now owns the session (`editorSessionID = UUID()`
  moved out of `select`) and captures `loadedForID` + `loadedSessionID`.
  `applyEditorChanges` and `persistEditor` require `selectedID ==
  loadedForID && editorSessionID == loadedSessionID` before writing — an
  `onChange` / `textDidChange` echo from a previous load can never persist
  into a note it was not loaded for.
- `NoteStore.update`: explicit guard — only a real change to `title` /
  `body` / `tags` / `published` may touch the file or bump `updated`; a
  re-persist of identical fields is a no-op even when the caller's note
  carries a different `updated`. The not-in-memory path persists as-is
  instead of inventing a timestamp.
- Tests: `testUpdateWithStaleUpdatedButIdenticalFieldsIsNoop` (file
  byte-identical, `updated` unmoved) and
  `testUpdateWithRealChangeBumpsUpdatedAndPersists` (positive control).

### Gate result

10/10 back-to-back `open -a` imports into fresh container vaults were
byte-identical (risotto.cook and Welcome-2.md vs sources, including
`updated:`) on the fixed build — 0 failures. `swift test` green,
`make smoke` green.

## Do (done — kept as the record of what was asked)

1. ~~Make `applyEditorChanges` verify the buffer it writes belongs to the note~~
   ~~it was loaded for — capture `selectedID` + `editorSessionID` at load~~
   ~~and require both at write.~~ Done via `loadedForID` / `loadedSessionID`.
2. ~~As a belt-and-braces option: in `NoteStore.update`, bump `updated` only~~
   ~~when a persisted field actually changed vs the existing note.~~ Done as
   an explicit guard with a byte-identity test.
3. Reproduce first, fix second. **Recorded:** 7 probe runs before the fix
   never reproduced; the gate after the fix is 10/10 byte-identical.

## Do not

- Change `importFile` (it is correct).
- Weaken the `store.update` early-return.
- Break C-1 rules: typing, undo (30s ⌘Z), and caret behavior stay.

## Gate

~~Back-to-back `open -a` imports are byte-identical across ≥10 runs (including~~
~~`updated:`); the race no longer reproduces; normal typing/undo unaffected;~~
~~`swift test` green; `make smoke` green.~~

**Passed 2026-08-19:** 10/10 byte-identical runs, 0 failures, on the fixed
build; `swift test` and `make smoke` green. If a future sit observes a
bumped `updated` again, reopen this card with the new reproduction — the
session guard and the store no-op are defense in depth, not a proof.
