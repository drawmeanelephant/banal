# Card B-2 — The caret never waits

**Milestone:** M3 · **Lane:** editor · **Status:** cooking — dirty-only flush, caret keyed by note id

## Handoff

- **Landed (earlier):** `ExternalEdit` policy + tests. Debounced write 400ms, atomic `NoteIO.write`, ignore our own FSEvents via fingerprint window. Select path calls `persistEditor` then load.
- **This session:** stop rewriting a clean note on every select (that was bumping `updated` and feeding FSEvents). Clear dirty when the buffer matches disk. Text view keyed by note id so switch resets undo/caret; clean external reload keeps the offset if it still fits. Find bar actually opens.
- **Sit (this session):** Selecting notes was rewriting clean files (`updated` bump). Fixed: identical `update` is a no-op; `applyEditorChanges` returns when the buffer matches; text view ignores programmatic `string` sets. After the fix, four selects left mtimes unchanged. Clean Vim edit of Scratch reloaded. Still open: 30s type / ⌘Z in the hand, dirty-Vim keep-buffer, huge-vault `open()` on the main thread.

## Owns

- `MarkdownTextView.swift`
- `AppModel` editor flush / select path
- `NoteStore` debounce only as it affects caret jumps

## Do not touch

- Publish
- Oliver (parsing must not sit on the keystroke)
- Folder moves mid-edit except the existing flush-on-select

## Why

Every “smart” notes app eventually hitches on save, preview, or
sync. That hitch is how you can tell it was built by someone who
does not write. Superhappyfuntimes is a caret that feels like
TextEdit and a file that is always on disk two beats later.

## Do

1. `NSTextView`: undo, find bar (⇧⌘F), smart quotes and spelling
   from preferences, no rich text.
2. Switching notes flushes the previous file *before* loading the
   next. Never write note A’s body onto note B (regression: the
   first scaffold had this bug in an earlier select path).
3. Debounced save (~400ms). Atomic replace. FSEvents of our own
   write must not reset the selection or scroll.
4. Dirty external edit (Vim changed the file we have unsaved): do
   not clobber. One sentence. Keep the buffer.
5. Clean external edit: reload. Caret to a sane place (start, or
   preserve offset if still in range).
6. Opening a 200KB note is instant. If it is not, you did I/O on
   the main thread wrong — fix that, do not add a spinner.

## Do not

- Bind the text view to a webview “for performance.”
- Run Oliver on every keystroke in this card.
- Animate the caret.

## Gate

Type for thirty seconds, switch notes, switch back, ⌘Z still makes
sense. Edit the same file in Vim while BANAL is open: dirty does
not eat your buffer; clean reloads. `swift test` still green.
