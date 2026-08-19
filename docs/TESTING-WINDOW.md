# Tester brief: the window (the whole sit)

This is how BANAL should feel after five minutes with no explanation. Folders on the left, notes in the middle, a page on the right. You write, you file, you cook a risotto, you export the ones you marked. Publish is Export, not onboarding.

If you are still explaining the chrome, the sit failed. Please try to hate it.

Copy in the UI says **notes folder**, not “vault.” Docs still say vault. Same thing.

The notes-folder picker (first run, missing, vanish while open) has its own brief: [`TESTING-NOTES-FOLDER.md`](TESTING-NOTES-FOLDER.md). Do those rows first. Do not treat this file as a replacement.

---

## What you are reviewing

One sitting of the silhouette:

| Surface | What you should see |
| --- | --- |
| **Picker** | First run: “Choose a notes folder.” Missing: “This notes folder is missing.” plus the old path. Same two buttons. |
| **Window** | Folders · notes · page. Default about 1100×720. At 720 the sidebar may collapse; list + editor stay. |
| **Type** | SF Pro, 16pt, a page not a lawn. Light and dark both look like the system, not a brand. |
| **Caret** | Type. Switch notes. ⌘Z undoes *this* note, not the last one. Dirty Vim keeps your buffer. |
| **Empty** | One sentence each: empty folder, empty search, nothing published, no selection. |
| **Languages** | File → New Textile / New Recipe. Finder shows `.md`, `.textile`, `.cook`. |
| **Risotto** | Open `Recipes/risotto.cook`. Read. 2×. The file on disk does not change. |
| **Publish** | Mark two Markdown notes and the risotto. ⇧⌘P writes `.publish/` and reveals it. |

`swift test` is required after Swift changes. It is **not** this sit.

---

## Build

From this repo:

```bash
swift test
swift run BANAL
```

Sandboxed `.app` (C-3): `make app` then `open dist/BANAL.app`. Notes-folder sit: [`TESTING-NOTES-FOLDER.md`](TESTING-NOTES-FOLDER.md).

**`BANAL_VAULT`:** if set to an existing directory, launch opens that folder **without writing the bookmark**. Use it for a disposable tree (or the sample vault) while leaving a remembered notes folder alone.

```bash
BANAL_VAULT="$HOME/Desktop/BANAL-sit-vault" swift run BANAL
```

Sample risotto lives at `Examples/sample-vault/Recipes/risotto.cook`. Easiest window sit:

```bash
BANAL_VAULT="$(pwd)/Examples/sample-vault" swift run BANAL
```

Do **not** commit `Examples/sample-vault/.banal/` if publish writes one.

Default first-run destination if they click the left button: `~/Documents/BANAL Notes`.

---

## Script (do these in order)

### 1. Notes folder (the other brief)

**Do.** [`TESTING-NOTES-FOLDER.md`](TESTING-NOTES-FOLDER.md) sections 1–5: first run, Choose…, Documents/BANAL Notes, missing at launch, missing while open.

**Expect.** The picker copy difference holds. The folder is not silently recreated.

**Fail if.** Anything that brief calls a fail. Then stop — the window sit is a liar on top of a liar.

### 2. Light + dark at 720, 1100, 1400

**Do.** Open a vault with a few notes (the sample vault is enough). System Settings → Appearance → Light. Resize the window to about **720×520**, **1100×720**, and **1400×800**. Repeat in Dark.

**Expect.**

| Width | Expect |
| --- | --- |
| 720 | List + editor visible. Sidebar may collapse. No horizontal scramble. Title and body still read as a page. |
| 1100 | Three columns. Default size. Nothing looks lost. |
| 1400 | Body stays a measure (about 680pt, centered) when **Limit line length** is on. Not a lawn of text. |

Chrome uses system materials. Selection is the system accent. Separators are hairlines.

**Fail if.** Dark mode is a branded purple. 720 hides the editor behind a back button you have to explain. 1400 stretches the body full width with the measure toggle on. A column vanishes and does not come back.

### 3. Type thirty seconds, switch notes, ⌘Z

**Do.**

1. Open Welcome (or ⌘N). Click the body.
2. Type for thirty seconds. Real sentences, not `asdf`. ⌘Z once or twice while you are still in the note — the last words should go away, then ⇧⌘Z should bring them back.
3. Click another note. Type a word.
4. ⌘Z. That word should go. Welcome’s paragraph should **not** appear in this note.
5. Switch back to Welcome. The thirty-second text is still there. ⌘Z should not replay the other note.

**Expect.** The caret does not jump while you type. Switching notes flushes the previous file and resets undo. Style / Oliver idle work does not eat ⌘Z.

**Fail if.** Undo is dead after a few sentences. Switching notes pastes the previous body. The caret leaps to the start on its own. Saving hitch — typing waits on disk.

This row is the hand. If you did not sit it in the running app, it is not done.

### 4. Dirty Vim keeps the buffer; clean Vim reloads

**Do.** Settings → General → **Watch for edits from other apps** is on (default).

1. **Clean.** Open a note. Do not type. In Terminal: `echo 'FROM VIM' >> that-file.md`. BANAL should reload. The line is there.
2. **Dirty.** Open a note. Type `DIRTY` in BANAL (do not wait around for a long idle if you can help it). In Vim/VS Code, save a *different* line into that file. BANAL keeps `DIRTY`. Status strip, one sentence: file changed on disk.
3. **Watch off.** Turn the toggle off. Vim should not reload the open note. **Vanishing the notes folder should still** dump you on the missing picker (that is [`TESTING-NOTES-FOLDER.md`](TESTING-NOTES-FOLDER.md) §7).

**Fail if.** Dirty Vim throws your typing away. Clean Vim does nothing. Watch-off means a deleted folder leaves you editing ghosts.

### 5. Empty folder, empty search, missing folder

**Do.**

1. ⇧⌘N → name it `Empty Sit` → Create. List says **No notes in this folder.** ⌘N still works and creates *here*.
2. All Notes. ⌘F. Type `zzqx`. List says **No notes match.** The query stays. Esc clears it.
3. Published with nothing marked: **Nothing published.**
4. Missing folder: the other brief, not a third picker.

**Expect.** One sentence each. No illustrations. No “tips for your first week.”

**Fail if.** Empty looks like a landing page. Search clears itself. ⌘N from an empty folder creates in the wrong place.

### 6. New Textile, New Recipe

**Do.** File → **New Textile**. File → **New Recipe**. Reveal in Finder (or open the notes folder).

**Expect.** Three extensions on disk: `.md` (Welcome or the new Markdown), `.textile`, `.cook`. The recipe file is Cooklang (`>> title`, an ingredient, a step) — not a YAML fence. Opening each is source.

**Fail if.** New Recipe writes `---`. Finder only shows Markdown. The list hides `.cook` / `.textile`.

### 7. Risotto: Read, 2×, disk unchanged

**Do.**

1. Open `Examples/sample-vault/Recipes/risotto.cook` (sample vault, or copy that file into your sit folder).
2. Hit **Read** (segmented control in the metadata row, or View → Read Recipe).
3. Ingredients are a list a human can cook from. Cookware. Numbered steps. The block quote is a note.
4. Flip **2×**. Rice should read 600 g, stock 2 l.
5. In Terminal: `shasum` / `diff` the `.cook` file against what it was before Read. **Unchanged.**
6. Flip **Edit**. You are in the `.cook` text.

If Oliver is missing or too old (`serialize --json` absent), Read is one sentence (`This recipe didn’t parse.`). Edit still works. That is honest — not a crash. File a note, do not invent a second parser.

**Fail if.** 2× rewrites `risotto.cook`. Read is a webview you can type in. The ingredient list is raw `@arborio rice{300%g}` fences. A skeptical cook asks where the recipe app is.

### 8. Mark two Markdown notes and the risotto; ⇧⌘P

**Do.**

1. Welcome (or any `.md`) → File → **Publish** (⇧⌘U), or the list context menu. Same for a second Markdown note. Same for the risotto. The metadata row shows a globe / Published. The list row does too.
2. File → **Publish Site…** (⇧⌘P).

**Expect.** Finder selects `.publish/`. Status strip is one sentence (e.g. Published 3 notes with builtin.). Unpublished notes are not in the artifact. `risotto.cook` **on disk** is still Cooklang — no YAML fence, quantities still 1×. Open `.publish/index.html`. Open `.publish/Recipes/risotto.html`. Nav from the risotto page gets you **back** to the index (`../index.html`, not a 404).

Deploy to Cloudflare is optional and stays disabled without a Keychain token + project name. Do not turn this sit into an account signup.

**Fail if.** Drafts leak into `.publish/`. The risotto file on disk grows `---`. ⇧⌘P opens a SaaS wizard. The risotto HTML cannot walk back to the index. The strip says “Published 1 notes”.

### 9. VoiceOver on the three columns

**Do.** VoiceOver on. Walk the window.

**Expect.** Columns read as **Folders**, **Notes**, **Note**. List rows speak title, Recipe if `.cook`, Published if marked, relative date. Title field is Title. Recipe Read is Recipe; scale is Scale. Picker (if you are on it) speaks the missing/first-run sentence. Status strip speaks the sentence.

**Fail if.** The whole window is “group” / “empty.” Published is color-only. The status strip is silent.

---

## What this is not (so you do not file those bugs)

- Not iCloud Drive sync. Prefer a local Desktop folder, or `BANAL_VAULT`.
- Not sandbox-on for `swift run`. Permissions are looser than a signed `.app` (C-3).
- Not Oliver / Boris path pickers or an About panel (C-2).
- Not a Markdown/Textile preview column. Read is for `.cook` only.
- Not pantry, meal plan, or a grocery list.
- Not “BANAL Notes” as a special database. Trash in Finder is Trash.
- Not a claim that `swift test` sat the window.

---

## Pass / fail for the person who sat

You pass this feature when:

1. Five minutes in, nobody had to explain the three columns.
2. Light and dark at 720 / 1100 / 1400 look like one product.
3. Thirty seconds of typing, a note switch, and ⌘Z still make sense **in the hand**.
4. Dirty Vim keeps the buffer; clean Vim reloads.
5. Empty folder / empty search / missing folder are one sentence each.
6. Finder shows `.md`, `.textile`, and `.cook`.
7. Risotto is cookable at 2× and the file on disk did not change.
8. Two essays and the sauce go through ⇧⌘P; disk notes stay yours; publish felt like Export.
9. VoiceOver can name the three columns.

You fail if you are still narrating the window, if risotto is a source fence you would not cook from, or if publish feels like onboarding a SaaS.
