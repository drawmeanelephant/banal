# Hope chest

What we are driving toward. **Not a board.** Cards still win on
what to do *now* ([`cards/README.md`](cards/README.md)).

If we fall asleep, the navigator uses this file. It will not
stop at a dirty gas station. It will not invent a shortcut
across Louisiana. It will not book Japan while we are still
in the driveway.

Read [`NORTH-STAR.md`](NORTH-STAR.md) and
[`cards/B-X-refuse.md`](cards/B-X-refuse.md) first. The North
Star wins when this file gets romantic.

## M99 — Home

Not a feature. A house we can still live in.

A person opens BANAL the way they open Notes. Folders on the
left, a list in the middle, a page on the right. They write a
paragraph. They file it. Thursday they cook risotto from a
`.cook` file that is still a file. Sunday they mark three
notes Published and Export a site. They never made an account.
They never took a tour.

Six months later the same folder opens in Vim. Ten years later
it still does. The app looks like Apple shipped it and then
left it alone. Cloudflare may be unset. Oliver may be missing.
The notes did not notice.

That is M99. If a later idea makes that paragraph longer, it
is probably a wrong exit. If it makes the window busier, turn
around.

## The route

We are not numbering 1–99 as features. The numbers are towns.
Unnamed miles between them stay unnamed until we are hungry.

```text
  driveway          Tucson              California         Japan           Home
  M1–M6 drawn       M9–M12              M20                M50             M99
  M7 sit (now)      Type · System       1.0 you could      luxury that
  M8 fluency        · Files             give a stranger    still looks
                                        and charge for     like Tuesday
```

| Town | Miles | What we are allowed to want |
|------|-------|------------------------------|
| **Driveway** | M1–M8 | The silhouette exists. Sit it. Deepen the *file*. |
| **Tucson** | M9–M12 | Mac manners in the page, the system, the folder. Still the same road. |
| **California** | M20 | Finished enough to hand over. Notarized. Boring on purpose. |
| **Japan** | M50 | A vacation meal. Only after California. Still three columns. |
| **Home** | M99 | The hope chest closes. The app survived. |

Tucson is what we do **before** California. Japan is what we
eat **after** we can fly. Do not fly from the driveway.

## Immediate miles (do not skip)

Tucson is behind us; California is next. Free-tier vs paid:

1. **Release (free-tier)** ([I-1](cards/I-1-release.md)) — **deferred** — ad-hoc or `Apple Development ZQT4XUHVT5` (free team) ships via right-click Open; `Scripts/notarize.sh` no-ops without paid `Developer ID Application`. Notarized + stapled stays the paid step.
2. **Sit the ad-hoc build** ([I-2](cards/I-2-release-sit.md)) —
   the one human pass that closes C-1, D-1/D-2, and F-8. Local light sit may run now; friend full sit (light+dark 720/1100/1400 + VoiceOver) is the gate. Sit bugs fill M13–M19, one card at a time.

If the sit hates the caret or publish feels like onboarding,
that bug is the whole map. We do not reach California with a
broken windshield. Paid notarize does not precede the sit.

## Tucson — before California (M9–M12)

Same desert. Better manners. Detail in
[`ROADMAP.md`](ROADMAP.md).

| Stop | Verdict | We eat | We do not eat |
|------|---------|--------|----------------|
| **M9 Type** | Implement | 30% marker dimming, URL paste, clean paste from Safari, list continue/breakout, smart quotes off in fences | A rendered canvas. Multi-cursor as a product. |
| **M10 System** | Implement | Notarize, Siri / App Intents, Spotlight entities, Print, Share, Translate sheet | A listen pane. A Shortcuts religion. |
| **M11 Files** | Implement | Images land in `assets/`, Copy As, import-as-copy, Contacts picker | Full-bleed, hover zoom, a media library. |
| **M12** | Consider | Typewriter (off), tags *filter*, quiet count, checkbox in source, second window, system Versions | Focus dimming, per-note fonts, scratchpad, karma HUD. |

Cut cards from Tucson only after M8, except M10 may run beside
D if it does not touch the editor.

## California — 1.0 (M20)

The coast. A friend who does not have this checkout double-clicks
an `.app`, picks a folder, writes, files, cooks, optionally
publishes. They do not write us. They do not need a README.

**Free-tier vs paid:** free-tier ships ad-hoc (`make app` `-` or `Apple Development ZQT4XUHVT5`) — friend drags to Applications → right-click Open. Gatekeeper warning is expected until paid `Developer ID Application` + `notarytool` creds are provisioned. Do not block the sit on notarize.

M20 (free-tier) is true when all of this is boring:

- Friend ad-hoc install works (right-click Open), picker → write → file → cook → `⇧⌘P` publish to `.publish/` without token
- C-1 sit plus D-1/D-2/F-8 gates checked (local light + friend full 720/1100/1400)
- Help is one page `Resources/BANAL.help/Contents/Resources/en.lproj/BANAL.html` + About `BANAL is a beautiful, boring…` `Sources/BANALApp/BanalApp.swift:121`
- Empty states are still one sentence `Sources/BANALApp/Views/NoteListView.swift:100`
- Local notes never need a token
- Finder and BANAL still agree
- The window is still folders · list · page

M20 (paid) adds: Gatekeeper happy without right-click (`Developer ID Application`, notarized, stapled, `spctl --assess` `Notarized`), same sit on paid build.

M20 is **not** iPhone, iCloud we operate, a theme store, or
version 2.0 energy. If we want to charge money, this is the
first honest day — not because we added surfaces, because we
stopped.

Miles M13–M19 stay **active triage** — blank until I-2 friend sit files them. If the sit surfaces a bug, that is the next exit. Cut one card at a time. Do not pre-build rest stops.

## Japan — vacation (M50)

Book this after California. Luxury that still looks like
Tuesday. Mission amendment if it would change the sentence.

Allowed to *consider* on the plane:

- Enrich Markup… / Suggest Title — on-device Foundation Models
  or a user binary, menu, undo, never auto
- One stylesheet pairing that still feels like the system
- Save a scaled recipe copy, if a cook has asked
- Localization, after the English sentences are ones we would say
- A second window on the *same* folder that feels like TextEdit
- Recipe Read so kind a skeptical cook never asks where the
  recipe app went (that kindness started in B-9)

Still not dinner in Japan:

- Chat with notes, a model in Keychain, “ask your vault”
- Graph, backlinks, wikilinks, daily-note religion
- Pantry, meal plan, shopping list
- A rendered canvas (Mermaid, live LaTeX, outline gutter)
- Menu-bar extra app, Inspector, fourth Settings pane

If we are hungry for those, we are not in Japan. We took the
wrong I-10.

## Home — M99

We already wrote it. The test is time, not a launch.

- A writer uses it for a month and never opens Settings
- A cook keeps `.cook` next to letters
- Someone who loves Textile does not feel like a legacy user
- A skeptical friend understands the Finder window instantly
- We could delete the app tomorrow and the folder would be fine

When that is true, stop adding towns. Polish what is there.
Delete what shouts. Go to sleep.

## The small moments

Features are loud. Charm is quiet. The app earns trust in the
gaps between features — the half-second after launch, the empty
search, the window at 720 wide on a Tuesday afternoon.

**First open.** A folder picker and one sentence. No tour, no
sample vault, no five-step onboarding wizard. They chose to
open a notes app. Respect that by letting them start.

**Empty.** One line of text, never an illustration. Not "Get
started by creating your first note!" The folder is empty
because it is new, and new things are allowed to be empty.

**Nothing found.** The list goes blank. That is the answer.
Do not suggest they try different keywords.

**Small window.** The sidebar collapses. The page is still a
page. Nothing breaks, nothing hides behind a tooltip, nothing
whispers "try full screen." A 13″ Air on a train is a real
desk.

**Left open for a week.** No badge. No "welcome back." The
caret is where they left it and the file is what Finder says
it is.

**Sound.** None. The keyboard already makes sounds.

**Animation.** Selection and collapse may move. Nothing
bounces, celebrates, or waits for applause. Reduce Motion
means nothing moves at all.

The app should feel like a well-made kitchen knife: it does
not introduce itself. You just start cutting.

## Navigator — so we do not wake up in Louisiana

Wrong exits look busy, helpful, and “what a notes app should
have.” They are how independent software dies.

**You are in Louisiana if**

- The default window grew a column, a chat dock, or a People list
- Someone has to explain the chrome
- Dinner and a paragraph feel like two products
- Notes need the network, a token, or a subscription to exist
- Disk and the UI can disagree
- There is a second notes database
- The editor is a webview or a live preview costume
- Settings grew a fourth pane
- The pitch is “it’s like Obsidian / Paprika / ChatGPT but…”
- We raised the macOS floor to chase a keynote
- We booked Japan from the driveway

**Turn around. Use the last sit. Open the last card. Do not
add a gas station to justify the detour.**

The refuse list in full is [`cards/B-X-refuse.md`](cards/B-X-refuse.md).
How a future idea earns a place is
[`HORIZON.md`](HORIZON.md). What to pick *today* is
[`cards/README.md`](cards/README.md).

## How to use this chest

- **Asleep / new session:** Board I free-tier — I-1 deferred (ad-hoc), then sit (I-2 — you light, friend full), M13–M19 bugs one at a time, then paid notarize when Program available, then `copy` is already landed. Do not open Japan yet.
- **Planning:** cut a board from the next *town*, not from M99. Next board after free-tier is the **M13–M19 drive** (sit bugs), not Japan.
- **Tempted:** read the Louisiana list out loud. If you are
  defending the idea, it is already a detour.
- **Done with a town:** one line in [`STATUS.md`](STATUS.md)
  and [`CHANGELOG.md`](../CHANGELOG.md). Do not celebrate by
  inventing the next continent.
