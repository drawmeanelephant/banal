# Tester brief: System Furniture, Manners & Accessibility (F-7)

This document is the testing brief and audit script for BANAL system furniture, keyboard navigation, VoiceOver accessibility, Reduce Motion, Increase Contrast, and window resize boundaries.

BANAL is a native macOS application that respects standard system conventions. Accessibility is not an ornamental badge or separate mode; it is the built-in system manners of AppKit and SwiftUI.

---

## 1. System Manners Checklist

| Manner | System Setting | BANAL Expected Behavior |
| --- | --- | --- |
| **VoiceOver** | ⌘F5 or System Settings → Accessibility → VoiceOver | All columns, rows, buttons, inputs, and status messages announce clear, descriptive semantic roles and labels. |
| **Reduce Motion** | System Settings → Accessibility → Display → Reduce Motion | All motion transitions (status strip slide, view transitions) are disabled or simplified to clean opacity fades. |
| **Increase Contrast** | System Settings → Accessibility → Display → Increase Contrast | Column boundaries, search dividers, and status strips render high-contrast 1pt border separators. |
| **Keyboard Navigation** | System Settings → Keyboard → Keyboard Navigation | ⌘1/⌘2/⌘3, Tab, Shift-Tab, Enter, Space, and Arrow keys allow full navigation without mouse interaction or focus traps. |
| **Window Resizing** | Drag window frame from 720×520 to 1400×900+ | At 720×520, list and editor remain fully readable; at 1400×900+, editor body honors centered measure width (680pt). |

---

## 2. Keyboard Navigation Reference

BANAL supports full keyboard navigation across the entire product surface:

### Column Focus
- **⌘1**: Focus Sidebar (Folder tree & filters)
- **⌘2**: Focus Note List
- **⌘3**: Focus Editor (switches to Edit mode and focuses text)
- **Tab**: Cycle forward between columns (Sidebar → Note List → Editor → Sidebar)
- **Shift-Tab**: Cycle backward between columns (Editor → Note List → Sidebar → Editor)

### Note List & Navigation
- **↑ / ↓**: Move selection up/down in Note List or Sidebar
- **Enter / Return**:
  - In Sidebar: Focus Note List on the selected folder/filter
  - In Note List: Focus Editor on the selected note
- **Space**: Quick Look the selected note (when focused in Note List)
- **⌘F**: Focus Search field in Note List
- **Esc**: Clear active search query or return focus to Note List

### File & Action Shortcuts
- **⌘N**: New Markdown Note
- **⇧⌘N**: New Folder
- **⇧⌘U**: Toggle Published state for current note
- **⇧⌘P**: Publish Site
- **⌘P**: Print current note or recipe
- **⌘Y**: Quick Look selected note
- **⌘,**: Open Settings window
- **⌘⌫**: Move selected note or selected folder to Trash
- **⌘Z / ⇧⌘Z**: Undo / Redo in active note editor

---

## 3. VoiceOver Step-by-Step Audit Script

Turn on VoiceOver (**⌘F5** or triple-touch ID). Follow these steps in sequence:

### A. Notes Folder Picker (First-run / Missing state)
1. Launch BANAL without a saved notes folder:
   - VoiceOver speaks: *"Choose a notes folder."*
   - Button 1: *"Documents/BANAL Notes"*
   - Button 2: *"Choose…"*
2. Launch with a missing folder:
   - VoiceOver speaks: *"This notes folder is missing."* followed by the missing path.

### B. Sidebar
1. Press **⌘1** to focus the Sidebar.
2. Navigate to **All Notes**:
   - Spoken: *"All Notes, [N] notes, Shows all notes in the vault"*.
3. Navigate to **Published**:
   - Spoken: *"Published, [N] published notes, Shows notes marked for publishing"*.
4. Navigate through Folder items:
   - Spoken: *"[Folder Name], [N] notes, Folder"*.
5. Context menu on folder (VO+Shift+M):
   - Spoken options: *"New Note Here"*, *"New Folder"*, *"Rename…"*, *"Move to Trash"*.

### C. Note List
1. Press **⌘2** to focus the Note List.
2. Focus the **Search** field (or press **⌘F**):
   - Spoken: *"Search notes, Filter notes by title, body, tags, or ingredients, text field"*.
3. Arrow down into the notes list:
   - Each note row combines metadata cleanly into a single spoken phrase:
   - Spoken format: *"[Note Title], [Folder: Name if in folder], [Recipe if .cook], [Published if published], [Relative date, e.g. today / 2 hours ago], [Snippet preview]"*.
   - Accessibility hint: *"Select note to view or edit"*.
4. Empty states:
   - Empty folder: *"No notes in this folder."*
   - Empty search: *"No notes match."*
   - Nothing published: *"Nothing published."*
   - Empty vault: *"Create a note with ⌘N."*

### D. Editor & Text Area
1. Press **⌘3** to focus the Editor.
2. Title field:
   - Spoken: *"Note title, Edit note title, text field"*.
3. Metadata row:
   - Relative update date: *"Updated [relative timestamp]"*.
   - Published indicator: *"Published note"*.
   - Tags: *"Tags: [tag list]"*.
   - View switcher: *"Note view mode, Switch between edit and read modes, segmented control"*.
4. Body text area:
   - Spoken: *"Note body editor, main text editor for note content, text area"*.
   - Text editing, dictation, and macOS Writing Tools operate seamlessly without obstruction.

### E. Recipe Read Mode
1. Open a `.cook` recipe note (e.g. `Recipes/risotto.cook`).
2. Switch to **Read** mode (via switcher or View menu).
3. Scale picker:
   - Spoken: *"Recipe scale, Adjust ingredient quantities, segmented control"*.
4. Ingredients section:
   - Section heading: *"Ingredients"*, header trait.
   - Items: *"[Amount unit] [Ingredient name] ([Preparation])"*.
5. Cookware section:
   - Section heading: *"Cookware"*, header trait.
   - Items: *"[Cookware name]"*.
6. Steps / Method:
   - Headings: *"Section: [Section Name]"*, header trait.
   - Steps: *"Step [N]: [Step instructions]"*.
   - Notes: *"Note: [Note text]"*.

### F. Settings Window (⌘,)
1. Press **⌘,** to open Settings.
2. Tabs:
   - *"General, tab"*, *"Editor, tab"*, *"Publish, tab"*.
3. Verify every control:
   - General: *"Notes folder location"*, *"Choose notes folder"*, *"Reveal notes folder in Finder"*, *"Open this folder when BANAL launches"*, *"Sort notes by"*, *"New notes default location"*, *"Watch for edits from other apps"*.
   - Editor: *"Font size, [N] points"*, *"Line height"*, *"Limit line length"*, *"Check spelling"*, *"Smart quotes and dashes"*.
   - Publish: *"Site title"*, *"Site base URL"*, *"Site author"*, *"Boris binary path"*, *"Oliver binary path"*, *"Cloudflare Pages project name"*, *"Cloudflare Account ID"*, *"Custom domain"*, *"Cloudflare API token"*, *"Save API token in Keychain"*, *"Deploy to Cloudflare Pages"*.

### G. Status Strip Notifications
1. Trigger a status action (e.g. ⇧⌘P Publish Site or folder creation).
2. Status bar at the bottom announces the outcome (marked with `.updatesFrequently`).

---

## 4. System Preferences Verification

### Reduce Motion Verification
1. Enable **Reduce Motion** in macOS System Settings → Accessibility → Display.
2. In BANAL, trigger status messages and switch views.
3. **Verify:** No sliding animations occur; transitions use immediate cuts or quiet opacity fades.

### Increase Contrast Verification
1. Enable **Increase Contrast** in macOS System Settings → Accessibility → Display.
2. **Verify:** Column split dividers between Sidebar, Note List, and Editor display sharp, crisp 1pt separator borders (`.separatorColor`).
3. **Verify:** Search field divider and status bar top border render high-contrast boundaries.

---

## 5. Window Resize Boundaries

Test the application window across display scales:

- **720×520 (Minimum Size)**:
  - Sidebar may collapse into navigation split view toggle; Note List and Editor remain accessible.
  - Title and body do not clip or wrap awkwardly.
  - Buttons in toolbar and metadata row fit without truncation.
- **1100×720 (Default Size)**:
  - Three distinct columns (Sidebar 200pt, Note List 280pt, Editor flex).
- **1400×900+ (Studio Display / Ultrawide)**:
  - When **Limit line length** is enabled in Settings, the editor text column stays centered at ~680pt measure.
  - When **Limit line length** is disabled, text fills available width cleanly.

---

## Pass / Fail Criteria

You pass the F-7 System Sit when:
1. VoiceOver navigates Sidebar, Note List, Editor, Recipe Read, and Settings effortlessly.
2. Full keyboard navigation operates smoothly with ⌘1/⌘2/⌘3, Tab, and Enter.
3. Reduce Motion eliminates all sliding animation artifacts.
4. Increase Contrast produces crisp, clear visual boundaries between columns and controls.
5. Window resizes cleanly from 720×520 to ultrawide without UI clipping.
6. `swift test` and `make smoke` pass 100%.
