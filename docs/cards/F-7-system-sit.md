# Card F-7 — System furniture sit

**Milestone:** M10 · **Lane:** chrome · **Depends:** F-1 through F-6 · **Status:** ready — accessibility & system manners audit

## Handoff

- **Not started.** Follow-up audit to C-1 testing window for macOS system furniture.
- **Not this card:** adding new features or views.

## Owns

- `docs/TESTING-SYSTEM.md` (System testing checklist & script)
- Minor accessibility adjustments, VoiceOver labels, and contrast tweaks across all views

## Do not touch

- Feature scope or visual density
- macOS standard control appearances

## Why

A Mac app is not finished when it compiles; it is finished when VoiceOver navigates it effortlessly, Reduce Motion stops all transition artifacts, Increase Contrast maintains readable boundaries, and full keyboard navigation never drops focus into a black hole.

## Do

1. **VoiceOver Pass:**
   - Verify sidebar folder tree, note list rows, and editor page announce semantic roles, note titles, and folder nesting accurately.
2. **Accessibility Settings:**
   - Verify Reduce Motion disables split view and sheet animations.
   - Verify Increase Contrast maintains clear separators between columns.
3. **Window Resizing:**
   - Audit at 720×520 (compact 13" laptop screen) and 1400×900 (Studio Display).
   - Ensure no truncated labels or unreadable text.

## Do not

- Add custom accessibility overlays or visual inspection badges.

## Gate

Navigate the entire app with VoiceOver enabled: all controls and list rows have clear spoken descriptions. `swift test` stays green.
