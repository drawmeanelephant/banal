# Card F-6 — Translation session

**Milestone:** M10 · **Lane:** system · **Depends:** M7 Close landed · **Status:** ready — on-device translation sheet

## Handoff

- **Not started.** Edit → Translate… is not exposed in menus or context menus.
- **Not this card:** multi-language CMS, automatic full-vault translation, third-party translation APIs.

## Owns

- `Sources/BANALApp/Commands/EditCommands.swift`
- `Sources/BANALApp/Views/MarkdownTextView.swift`
- `#available(macOS 15.0, *)` `TranslationSession` sheet integration

## Do not touch

- macOS 14 compatibility floor (`#available` guards required)
- No API keys in Settings or Keychain for translation

## Why

macOS 15 includes system on-device translation. When reading or writing notes in another language, selecting text and choosing Edit → Translate… should invoke the system sheet and offer inline replacement or copying without sending data to third-party translation clouds.

## Do

1. Add Edit → Translate… menu item (active when text is selected in the editor).
2. Use native `NSTextView` translation contextual menu or `TranslationSession` system presentation.
3. Guard cleanly with `#available(macOS 15.0, *)` while maintaining full functionality on macOS 14.

## Do not

- Connect to cloud translation APIs requiring API tokens.
- Add translation indicators or language flags to the UI chrome.

## Gate

Select Spanish text in a note, choose Edit → Translate…: macOS native translation sheet appears with English translation. `swift test` stays green.
