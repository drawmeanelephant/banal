# Card E-4 — Punctuation discipline in fences

**Milestone:** M9 · **Lane:** editor · **Depends:** M8 done · **Status:** landed — code blocks stay code

## Handoff

- **Landed.** Dynamic punctuation substitution suppression (`isAutomaticQuoteSubstitutionEnabled`, `isAutomaticDashSubstitutionEnabled`, `isAutomaticTextReplacementEnabled`, `isContinuousSpellCheckingEnabled`, `isAutomaticSpellingCorrectionEnabled`) active in code fences (`` ``` `` / `~~~`), inline backtick spans (`` `...` ``), and Cooklang metadata lines (`>>`). Plain ASCII quotes and dashes are preserved when typing and pasting into code. Normal prose retains user preference settings.
- **Not this card:** syntax whisper (D-1), custom code editor theme.

## Owns

- `Sources/BANALApp/Views/MarkdownTextView.swift`
- `automaticQuoteSubstitutionEnabled`, `automaticDashSubstitutionEnabled`, `automaticTextReplacementEnabled` dynamic checking or delegate handlers

## Do not touch

- Global editor settings defaults for prose (smart quotes remain enabled by default for standard writing)
- Monospace font overrides for the entire document

## Why

There is nothing worse in a note than copying a command or shell snippet with curly quotes (`“` / `”`) or em-dashes (`—`) that break when pasted into a terminal. Inside code fences and backticks, punctuation must stay literal ASCII.

## Do

1. Detect when the cursor / insertion point is inside:
   - Fenced code blocks (between opening ` ``` ` and closing ` ``` `)
   - Inline code spans (between opening `` ` `` and closing `` ` ``)
   - Cooklang metadata blocks (`>>`)
2. In those regions, dynamically disable:
   - Smart quotes (keep `"` and `'` straight)
   - Smart dashes (keep `--` and `---` literal)
   - Automatic text replacements / spells
3. Outside code fences and backticks, restore standard user preference settings for prose.
4. Ensure pasting into code blocks preserves literal ASCII characters.

## Do not

- Turn BANAL into an IDE with autocomplete popups.
- Permanently disable smart quotes in standard prose paragraphs.

## Gate

Type ` ``` ` on a new line, hit return, type `"quoted -- flag"`. Quotes remain straight ASCII `"` and dashes remain `--`. Type below the closing ` ``` `: quotes become curly `“` and `”`. `swift test` stays green.
