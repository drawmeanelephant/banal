# Card B-7 — Oliver in the basement

**Milestone:** M4 · **Lane:** engine · **Status:** cooking — client landed; no preview

## Handoff

- **Landed:** `Sources/BANALPublisher/OliverClient.swift`. Locate like Boris (`BANAL_OLIVER_BIN`, PATH, sibling `oliver/zig-out/bin/oliver`). One-shot `oliver render --from markdown` on stdin. Body only — BANAL frontmatter is stripped, `--frontmatter` is never passed. Tests skip if the binary is missing; with Oliver present, `# Hello` renders to `<h1>`. AppModel asks after 400ms idle; never from `textDidChange`. Missing binary is silent. `lastOliverRender` is not `@Published`.
- **Not this card:** preview column, `.cook` / Textile, Settings path picker.

## Owns

- New small seam, e.g. `Sources/BANALPublisher/OliverClient.swift`
  (or `BANALCore` if you must — prefer keeping UI off this)
- Locating `oliver` (`BANAL_OLIVER_BIN`, PATH, sibling checkout)
- Tests that skip when the binary is absent

## Do not touch

- Solipsist `OliverRenderer` / Compose
- A Swift CommonMark
- Preview as a third column
- Running Oliver on every keystroke

## Why

Oliver is markup infrastructure: Markdown / Textile → document,
Cooklang → typed `Recipe`, deterministic HTML. BANAL must never
grow a second parser. This card installs the *question*: “what
are these bytes?” so later cards can show a preview or a recipe
reading view without inventing a grammar.

## Do

1. Locate the `oliver` binary the same way we locate `boris`.
2. One shot: stdin or temp file → parse/render for a known
   frontend (start with Markdown). Capture HTML or a
   machine-readable diagnostic. Exact argv is whatever current
   Oliver documents (`oliver render --from markdown` or the
   equivalent at time of implementation — read Oliver’s CLI, do
   not guess from memory).
3. Debounce at the *call site* (idle after typing), never on the
   caret path.
4. Missing binary: silent for ordinary notes. No modal. Settings
   may later show the path; not required here.
5. Tests: fixture Markdown in, HTML or parse-ok out, when binary
   present; skip otherwise.

## Do not

- Shell out from `textDidChange` without debounce.
- Parse frontmatter with Oliver in a way that fights BANAL’s
  local keys — BANAL still owns local note metadata.
- Bundle a Svelte UI.

## Gate

`oliver` on PATH: a unit test renders a heading to HTML. Binary
absent: tests skip, app still edits. Typing feels the same as
before this card.
