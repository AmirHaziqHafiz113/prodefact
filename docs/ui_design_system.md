# ProDefact UI Design System (Navigation & Visual Consolidation Pass)

This document supersedes `docs/design_system.md` (Phase 9's original
design system writeup) as the authoritative reference for ProDefact's
visual language, after the full navigation/visual consolidation pass
that redesigned Home, Inspections, the New Inspection wizard (Property
Type, Property Details, Configure Areas, Choose AI Plan, Review Setup),
Inspection Overview, Area Detail, Wallet, and Profile against a set of
supplied reference mockups. `docs/design_system.md` is kept for
history but should not be treated as current.

**What this pass changed and did not change:** this was a UI/UX and
navigation consolidation pass. The inspection architecture, wallet/
commercial logic, controlled defect catalogue, AI pricing, and House
Pass business rules are unchanged — see `docs/commercial_model.md` and
`docs/ai_provider_architecture.md` for those. Every number, status, and
progress value shown anywhere in the app comes from real application
state; nothing here hardcodes a mockup's illustrative sample data (see
"Real data only" below).

## Colors (`lib/app/theme/app_colors.dart`)

| Token | Hex | Use |
|---|---|---|
| `primary` | `#0F5C57` | Deep green — brand, primary actions, hero surfaces |
| `primaryDark` | `#0A3F3C` | Hero gradient's dark end |
| `primaryLight` | `#3D8F89` | Secondary teal accent, fallback thumbnail icon tint |
| `accent` | `#DB8B2A` | Warm amber — reserved for highlight/CTA use |
| `surface` | `#FFFFFF` | Cards |
| `surfaceAlt` | `#F4F6F6` | Scaffold background — the "light mint canvas" |
| `surfaceMuted` | `#EAEFEE` | Input fill, progress track, skeleton blocks |
| `outline` | `#D7DEDD` | Card/input borders |
| `textPrimary` / `textSecondary` / `textMuted` | `#14201F` / `#576765` / `#8A9896` | Type hierarchy |
| `success`/`successBg`, `warning`/`warningBg`, `danger`/`dangerBg`, `info`/`infoBg` | — | Status pairs — always icon + label, never color alone |
| `plumbing`/`plumbingBg` | `#1F7A8C`/`#E1F1F3` | "Plumbing-first" is a category, not a status — kept visually distinct from the semantic set |

Amber is reserved for future highlight use — status semantics
(in-progress/warning) currently use `warning`, matching the existing
semantic-color convention; nothing in this pass repurposed `accent` for
status.

## Typography (`lib/app/theme/app_theme.dart`)

`displaySmall` (30/w700) → `headlineMedium` (24/w700, page
greeting/title) → `headlineSmall` (20/w700) → `titleLarge` (18/w700,
card titles) → `titleMedium` (16/w600) → `titleSmall` (14/w600) →
`bodyLarge` (16) → `bodyMedium` (14, secondary) → `bodySmall` (12.5,
muted) → `labelLarge` (14/w600). No status/critical text uses a size
below `bodySmall`.

## Spacing & radius (`lib/app/theme/app_metrics.dart`)

`AppSpacing`: xs=4, sm=8, md=12, lg=16, xl=24, xxl=32 — the only
spacing values used; no ad hoc magic numbers.
`AppRadius`: sm=8 (chips/thumbnails), md=12 (inputs/buttons), lg=16
(cards), xl=20 (hero cards/bottom sheets), pill=999 (pills/segmented
progress).

## Reusable components (`lib/app/theme/widgets/`)

New this pass, alongside the pre-existing `StatusPill`/
`SyncStatusPill`/`AppProgressBar`/`AppSectionHeader`/`AppLoadingView`/
`AppEmptyView`/`AppErrorView`/`AppInlineErrorBanner`/
`AppInlineWarningBanner`/`AppRingProgress`/`AppBarChart`:

- **`AppAvatar`** — generated-initials avatar (never a stock photo);
  deterministic background color from a small palette keyed off the
  display name/email's first character.
- **`ProDefactBrandMark`** — the wordmark (icon + "Pro"/"Defact" in two
  weights), drawn from `Icon`/`Text` primitives — no bundled image
  asset.
- **`AppTopBar`** — the shared identity row (brand mark, a real-data
  "needs attention" bell with a badge only when the count is genuinely
  > 0, and the inspector's avatar). Composed differently per screen
  (Home/Wallet show brand+bell+avatar; Inspections shows bell+avatar
  under its own title; Profile shows just brand) rather than one rigid
  layout. **Must always be wrapped in `Expanded`** when placed inside
  another `Row` — it contains an internal `Spacer`, and nesting a
  `Spacer`-bearing `Row` inside another `Row` without `Expanded` throws
  `RenderFlex` unbounded-width assertions (a real bug this pass hit and
  fixed in `InspectionSessionsScreen`).
- **`AppMetricCard`** — the one icon + value + label + caption stat
  tile, replacing four screens' near-identical private `_StatTile`
  copies (Home, Wallet, Inspections, Configure Areas all use this now).
- **`AppHeroCard`** — the dark-green gradient treatment for the single
  most important panel on a screen (Home's active-inspection hero,
  Inspection Overview's progress hero, Wallet's balance card) — used
  sparingly so it keeps reading as "the important thing."
- **`AppFallbackThumbnail`** — an icon-on-gradient tile standing in for
  a property/area photo the app has no real image for (see "Image
  fallbacks" below).
- **`AppSkeletonBox` / `AppSkeletonCardList`** — static (not animated)
  loading placeholders. Deliberately **not** animated: an earlier draft
  used a repeating `AnimationController`, which kept a ticker alive
  forever and made `tester.pumpAndSettle()` hang in any widget test
  that happened to build the widget even briefly — a real regression
  this pass hit and fixed by removing the animation entirely.
- **`AppWizardStepper`** — the New Inspection wizard's one step
  indicator ("Step X of N" + a segmented progress bar), used
  identically on all 5 wizard screens rather than each screen building
  its own header.

## Navigation

Bottom nav: **Home | Inspections | (+) | Wallet | Profile**
(`AppBottomNav` in `lib/app/router/app_shell_screen.dart`) — a custom
floating, pill-shaped bar (not a stock Material `NavigationBar`), with
the selected destination getting a mint pill highlight and the center
"+" rendered as a raised, elevated circle that visually breaches the
bar's top edge. The "+" is a **global action, not a tab** — it always
pushes the New Inspection flow and is never one of the 4 real
`StatefulShellBranch`es; see the class doc comment.

**One canonical entry point per action** — duplicates removed this
pass:
- **New Inspection**: the "+" bottom-nav action only. The Inspections
  screen's old `FloatingActionButton` ("New Inspection") was removed
  (it duplicated the same destination).
- **Configure Areas**: the New Inspection wizard's own step only — no
  other screen exposes "Add area".
- Every hardcoded route-path string literal that bypassed its own
  screen's `routePath` constant was normalized (`InspectionQueueScreen`,
  `ReportScreen`, `AiReviewOverviewScreen`) so a future path typo is a
  compile error, not a silent runtime 404.

Secondary actions moved into `PopupMenuButton` ("...") overflow menus
instead of scattering icon buttons across a card: the Inspections
list's sync/delete actions, and Configure Areas' edit/delete actions.
(`AreaInspectionScreen`'s per-finding add-photo/edit/delete icons were
deliberately left as direct icon buttons — that screen is exercised by
a large, pre-existing widget-test suite that taps those icons directly
by `IconData`, and consolidating them into an overflow menu was judged
not worth the regression risk for this pass.)

## Real data only

Every progress ring, metric card, chart, and status pill is computed
from real application state — `PhysicalProgress`/
`AiProcessingProgress`/`AiReviewProgress` (existing domain classes,
now also used for Home's hero, not just Inspection Overview's),
`InspectionSessionSummary.needsAttention`, real wallet ledger
transactions, and the real `CommercialConfig` (never a hardcoded
Credits-per-Ringgit rate or House Pass price). Concretely:

- Home's "Needs attention" list and the top-bar bell's badge count are
  the exact same real, non-fabricated signal used by the Inspections
  screen's own "Needs attention" section
  (`attentionSessionsProvider`) — never an invented "overdue by N
  days" item (no due-date field exists in the domain model to compute
  that from).
- Wallet's "Choose the right plan for you" pricing explainer reads
  `CommercialConfig.housePass.priceMyr`/`creditsPerMyr` — see
  `test/features/wallet_pricing_explainer_test.dart`, added this pass
  specifically to prove the mockup's illustrative "RM39/month" and a
  fabricated "RM0.50/credit" never leaked into the real screen (House
  Pass is `RM30 / property`, a fixed price, never a subscription).
  Wallet's "Avg. / analysis" stat is honestly labeled per-analysis
  (not "per inspection") because the client-visible wallet ledger has
  no per-inspection grouping key to compute a true per-inspection
  average from.

## Image fallbacks

No property-photo or area-photo capture exists anywhere in the data
model (confirmed by a full-codebase audit before this pass started).
Every property/area "thumbnail" in the redesigned screens is therefore
always `AppFallbackThumbnail` (an icon on a soft gradient) — never a
fetched or fabricated stock photo. This is a deliberate, permanent
choice, not a placeholder waiting for a photo feature: if real
property/area photo capture is added later, the fallback becomes the
`null`-image branch of a real `Image.file`/`Image.network` check,
exactly like `AreaInspectionScreen`'s existing evidence-photo pattern
(`Image.file` with a `ColoredBox` + icon fallback when a finding has no
photo yet).

User avatars are `AppAvatar` (generated initials), never a photo —
there is no profile-photo upload capability in the data model either.

## Deliberately omitted (would have been dead UI)

- **Reference Photo** capture on Area Detail — the mockup shows it, but
  no such capture flow exists in the app; adding the button would have
  had no real action behind it.
- **Notifications toggle** on Profile — no push-notification
  infrastructure exists. The top-bar bell instead surfaces the same
  real "needs attention" data everywhere else in the app.
- **Help & Support** on Profile — no support channel/destination is
  documented anywhere in this codebase to link to.
- A settings **gear icon** on Profile — no settings destination exists
  beyond what's already inline on the screen.

## Animations

All animation in this pass is a bounded `TweenAnimationBuilder` (rings,
progress bars, bar charts — pre-existing) or a bounded
`AnimatedContainer` (the bottom nav's selected-pill transition, the
wizard stepper's segment fill) — never an unbounded/looping
`AnimationController`. See `AppSkeletonBox` above for why: a looping
ticker anywhere in the widget tree defeats `tester.pumpAndSettle()`.

## Responsiveness

The bottom nav's per-destination label (`_NavDestination`) is wrapped
in a `FittedBox(fit: BoxFit.scaleDown)` rather than relying on
`overflow: TextOverflow.ellipsis` alone — a real device screenshot
during this pass's manual check showed "Inspections" truncating to
"Inspecti…" on an iPhone-width simulator before this fix. `FittedBox`
guarantees no truncation at any reasonable screen width instead of
budgeting exact pixels per destination.

Every redesigned screen still uses `SafeArea`, `AppSpacing`-based
padding, and scrollable (`ListView`) layouts rather than fixed pixel
positioning — no new fixed-width/fixed-height assumptions were
introduced that would break on a narrow phone.

## Manual verification performed this pass

`flutter build apk --debug` and `flutter build ios --simulator --debug`
both succeed. The app was installed and launched on a booted iPhone
simulator (`xcrun simctl install`/`launch`) and screenshotted twice —
once before and once after the bottom-nav label fix above, which is
how that bug was actually found. No interactive tap-through of every
screen was possible in this environment (no `idb`/Simulator UI
automation available), so this is a partial, honest manual check, not
a full walkthrough — see the final report's "Remaining genuine UX
gaps"/"screens to manually inspect next" for what a human should still
click through on a real device or a locally-run simulator.
