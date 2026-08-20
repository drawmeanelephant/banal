# Card F-4 — Quick Look preview provider

**Milestone:** M10 · **Lane:** system · **Depends:** M7 Close landed · **Status:** landed

## Handoff

- **Not started.** Pressing Spacebar on `.cook` or `.textile` files in Finder shows a raw generic file icon or unformatted plain text.
- **Not this card:** a rich webview editor, full standalone viewer app.

## Owns

- Quick Look preview extension target or bundled QuickLook preview generator
- Support for `.md`, `.textile`, `.cook` UTIs

## Do not touch

- App bundle compactness
- WebKit heavy renderer dependencies (keep preview clean and fast)

## Why

Hitting Spacebar in Finder on any file inside the notes folder should display a clean, quietly formatted preview in SF Pro. Cooklang recipes show ingredients and steps; Markdown shows formatted prose.

## Do

1. Implement a Quick Look Preview Extension (`QLPreviewProvider` / `NSExtensionPrincipalClass`).
2. Declare Document Types and Exported Type Identifiers for:
   - `net.daringfireball.markdown` / `.md`
   - `com.cooklang.recipe` / `.cook`
   - `org.textile.markup` / `.textile`
3. Render a clean text-based or lightweight view matching BANAL's type metrics.

## Do not

- Spawn long-running background processes or webview engines.
- Add editing controls or toolbar buttons to the Quick Look window.

## Gate

Select `risotto.cook` in Finder, hit Spacebar. Quick Look displays clean recipe ingredients and instructions.
