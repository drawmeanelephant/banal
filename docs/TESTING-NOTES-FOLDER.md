# Tester brief: the notes folder (the “sit vault”)

This is how BANAL decides **which folder on disk is your notes**, and what happens when that folder is missing, moved, or deleted. It is not iCloud. It is not a database. It is a directory you picked, remembered as a security-scoped bookmark, and treated as the source of truth.

If this is wrong, the app is a liar. Please try to make it lie.

Copy in the UI says **notes folder**, not “vault.” Docs still say vault. Same thing.

---

## What you are reviewing

Three states at launch (`NotesFolderAccess`):

| State | When | What you should see |
| --- | --- | --- |
| **First run** | No bookmark in UserDefaults | “Choose a notes folder.” Two buttons. No path. |
| **Ready** | Bookmark points at a real directory | The three-column app opens into that folder. No picker. |
| **Missing** | Bookmark exists but that path is gone (or is a file, not a folder) | “This notes folder is missing.” The **old path** is shown, truncated. Same two buttons. The folder is **not** silently recreated. |

While the app is **already open**, if the notes folder vanishes (you renamed it, moved it, or deleted it in Finder), the window should dump you onto that same missing picker. Notes list goes empty. We do not keep writing into a ghost path.

Settings → General still lets you **Choose…** and **Reveal in Finder** when the folder is healthy.

---

## Build

From this repo:

```bash
swift test
swift run BANAL
```

`swift test` covers `NotesFolderAccess` (nil / ready / missing / file-not-folder) and store tests for a vanished root. It does **not** replace sitting in the GUI. You have to do the Finder bits by hand.

**`BANAL_VAULT`:** if set to an existing directory, launch opens that folder **without writing the bookmark**. Use it to sit a disposable tree while leaving your real notes folder remembered.

```bash
BANAL_VAULT="$HOME/Desktop/BANAL-sit-vault" swift run BANAL
```

Default first-run destination if they click the left button: `~/Documents/BANAL Notes`.

---

## Script (do these in order)

### 1. First run (no memory)

**Setup.** If you have already used BANAL on this Mac, the bookmark is in UserDefaults. For a clean first run, either:

- Use a throwaway macOS user, or
- Quit BANAL and:

```bash
defaults delete dev.drawmeanelephant.banal 2>/dev/null
defaults delete BANAL 2>/dev/null
# SPM `swift run BANAL` often stores under the bundle id the package generated.
# If the picker does not appear, check:
defaults domains | rg -i banal
```

If you cannot find the domain, just use a **new folder** for the rest of the script and treat step 1 as “first launch after wipe.”

**Expect.** Window is empty of notes chrome. Copy: **Choose a notes folder.** No lecture. Two buttons: **Documents/BANAL Notes** and **Choose…**. ⌘-default is Choose….

**Fail if.** A vault is created without asking. Marketing copy. A third button. The missing-path line showing for first run.

### 2. Choose an explicit folder

**Do.** Choose… → make a folder like `~/Desktop/BANAL-sit-vault` → Use Folder.

**Expect.** Three columns. A Welcome note (if the folder was empty). Finder shows the same files. Quit and reopen: **no picker**, same folder.

**Fail if.** Next launch asks again. Next launch opens `Documents/BANAL Notes` instead. Files appear somewhere else.

### 3. Documents/BANAL Notes

**Do.** Wipe bookmark again (or first run). Click **Documents/BANAL Notes**.

**Expect.** `~/Documents/BANAL Notes` is created if needed and opened. Quit/reopen stays there.

**Fail if.** It creates the folder on first *launch* before you click anything. Missing-folder copy on a folder it just created.

### 4. Missing at launch (the sit)

This is the one that was easy to miss: the sit vault was still on disk, so testers never saw the picker.

**Do.**

1. Open BANAL on `~/Desktop/BANAL-sit-vault` so it is remembered.
2. **Quit BANAL.**
3. In Finder, **rename** that folder to `BANAL-sit-vault-GONE` (or move it to Trash).
4. Launch BANAL.

**Expect.** Not the editor. Copy: **This notes folder is missing.** Under it, the **old** path (the name before you renamed, still pointing at the dead location). Buttons still work. **The old path is not recreated.** Finder should **not** grow a new empty `BANAL-sit-vault` while you stare at the picker.

Then click **Choose…** and pick `BANAL-sit-vault-GONE` (or the trash restore). App should open that tree.

Or click **Documents/BANAL Notes** and land in Documents instead. That is also valid — you picked a live folder.

**Fail if.**

- App opens an empty editor in a newly created folder at the old path (silent recreate).
- Crash.
- First-run copy (“Choose a notes folder.”) with no path, as if it forgot it ever had a bookmark.
- Path shown is the *new* name you renamed to (it cannot know that; the bookmark is the old URL).

### 5. Missing while open (this branch)

**Do.**

1. Open BANAL on a live sit folder. Confirm notes are visible.
2. **Do not quit.**
3. In Finder, rename or Trash that folder.

**Expect.** Within a beat (FSEvents), the three columns go away and you get **This notes folder is missing.** plus the old path. Status might flash; the picker is the product.

**Fail if.** The app keeps showing notes and lets you type. A save writes a new directory at the old path. Crash. Hang.

### 6. File where a folder should be

**Do.** Point a bookmark at a path, quit, replace that directory with a **file** of the same name (or pick a `.txt` somehow). Launch.

**Expect.** Missing picker, not “ready.” `NotesFolderAccess` treats a file as missing.

### 7. Watch for external edits vs vanish

Settings → General → **Watch for edits from other apps**.

- **On (default):** edit a `.md` in Vim/VS Code/TextEdit while BANAL is open. Clean buffer → reload. Dirty buffer (you typed in BANAL first) → your edits stay; one sentence: file changed on disk.
- **Off:** Vim edits should **not** reload the open note. **Vanishing the folder should still** take you to the missing picker (vanish is not “an edit,” it is “the world is gone”).

**Fail if.** Turning the watch off means a deleted folder leaves you editing ghosts. Or dirty Vim clobber: you type, Vim saves the old file, BANAL throws your typing away.

### 8. Reveal / Choose from Settings

With a healthy folder: Settings → General → **Reveal in Finder** selects the notes folder. **Choose…** switches bookmark. Reopen app: new folder.

**Fail if.** Reveal opens the app bundle or home. Choose does not persist.

### 9. First-run vs missing: the copy difference

Sit testers kept using an existing sit vault, so they only ever saw the happy path.

| Copy | Meaning |
| --- | --- |
| Choose a notes folder. | We have never been told a folder. |
| This notes folder is missing. | We remember one. It is not there. Here is the path. |

If those two screens are identical, the feature is broken even if both “work.”

---

## What this is not (so you do not file those bugs)

- Not iCloud Drive sync. If the folder is in iCloud and the file is a placeholder, macOS may look “missing” until it downloads. Prefer a local Desktop folder for this sit.
- Not sandbox-on for `swift run`. Bookmarks still exist; permissions are looser than a signed `.app`.
- Not “BANAL Notes” as a special database. Trash in Finder is Trash. Rename in Finder is rename.
- Not auto-migrating notes from the missing path into Documents.
- Not a list of recent vaults. One remembered folder.

---

## VoiceOver (same sit, while you are here)

Columns should read as **Folders**, **Notes**, **Note**. Picker should read the missing sentence, not a blank window. Status strip (if any) should speak the sentence. If VoiceOver says “group” / “empty” for the whole window, file it.

---

## Pass / fail for the person who sat

You pass this feature when:

1. First run asks.
2. A remembered live folder opens with no ask.
3. A remembered **dead** folder asks, **shows the dead path**, and **does not recreate it**.
4. Killing the folder **while the app is open** gets you the same missing UI.
5. You can Choose… out of the hole.

You fail if the app ever quietly builds an empty directory just to avoid the picker. That is the whole point of the sit.
