# ProDefact Design System (Phase 9)

> **Superseded** — see `docs/ui_design_system.md` for the current
> design system, after the navigation/visual consolidation pass that
> redesigned Home, Inspections, the New Inspection wizard, Inspection
> Overview, Area Detail, Wallet, and Profile against supplied
> reference mockups. This document is kept for history only.

A centralized design system replaced the previous one-line
`ThemeData(colorSchemeSeed: Colors.indigo)` and per-screen ad hoc
styling. All business logic, providers, persistence, navigation
routes, and the AI/report timing rules are unchanged — this phase is a
presentation-layer overhaul only.

## Tokens (`lib/app/theme/`)

- **`app_colors.dart`** (`AppColors`): a deep teal/navy brand palette
  (`primary`/`primaryDark`/`primaryLight`/`accent`), neutral surfaces
  (`surface`/`surfaceAlt`/`surfaceMuted`/`outline`), text colors
  (`textPrimary`/`textSecondary`/`textMuted`), semantic status colors
  each with a paired background (`success`/`successBg`,
  `warning`/`warningBg`, `danger`/`dangerBg`, `info`/`infoBg`,
  `neutralBg`), and a distinct `plumbing`/`plumbingBg` pair so
  "plumbing-priority" reads as a category, not a status.
- **`app_metrics.dart`**: `AppSpacing` (xs=4 … xxl=32) and `AppRadius`
  (sm=8 … pill=999) — the only spacing/radius values screens should
  use, instead of arbitrary numbers.
- **`app_theme.dart`** (`AppTheme.light`): a full `ThemeData` built on
  `ColorScheme.fromSeed`, with a real typographic hierarchy
  (`displaySmall` → `bodySmall`) and consistent component themes for
  `AppBar`, `Card`, `FilledButton`/`OutlinedButton`/`TextButton`/
  `IconButton`, `TextField` (via `InputDecorationTheme`), `Chip`,
  `Dialog`, `BottomSheet` (drag handle enabled by default), `Divider`,
  `ProgressIndicator`, and `SnackBar`. Named semantically (not
  "light"-specific) so a future `AppTheme.dark` is a second
  `ColorScheme` away, not a rework.

## Reusable components (`lib/app/theme/widgets/`)

- **`StatusPill`** — icon + label + paired color, the app's one status-
  indicator primitive (sync state, review status, area status, report
  readiness) — never color alone.
- **`SyncStatusPill`** — `StatusPill` specialized for `SyncStatus`,
  deliberately worded without Firebase/Firestore terminology ("Local
  only" / "Pending sync" / "Synced").
- **`AppProgressBar`** — a labeled, animated (`TweenAnimationBuilder`)
  linear progress bar used for inspection completion and AI review
  completion.
- **`AppSectionHeader`** — a consistent section title (+ optional
  subtitle/trailing action) above card lists.
- **`AppLoadingView` / `AppEmptyView` / `AppErrorView`** — full-bleed
  loading/empty/error states with a consistent icon-circle + headline +
  message (+ optional retry/primary action) layout, used instead of a
  bare spinner or a plain `Text('Error: $e')`.
- **`AppInlineErrorBanner` / `AppInlineWarningBanner`** — dismissible/
  static inline banners for a surfaced, non-fatal issue (a failed
  write, a stale report) without leaving the current screen.

## Where it's applied

Every major screen was redesigned on top of these tokens/components:
the inspection dashboard (`InspectionSessionsScreen`), property type
selection, area configuration, the physical-inspection overview
(`InspectionQueueScreen`), area/element inspection, the finding
add/edit sheet, AI review (with original finding / AI suggestion /
inspector final decision visually attributed via `_AttributedBlock`),
the report screen (readiness card + generate/preview/share/regenerate),
and sign-in. See `docs/production_readiness.md`'s UI section and the
Phase 9 final report for the itemized before/after per screen.

## Interaction polish

- `AppProgressBar` animates value changes rather than snapping.
- The finding editor is a modal bottom sheet (`isScrollControlled`,
  `useSafeArea`, capped at 90% of screen height, drag handle from the
  theme) rather than a fixed-size `AlertDialog`, so it works
  comfortably on small phones and adapts to the keyboard.
- Element inspection uses a 2-column icon grid (one icon per common
  element name — Floor/Wall/Ceiling/Door/Window/M&E, generic fallback
  for a custom name) instead of a plain list, for touch-friendly
  scanning.
- The inspection queue highlights the next area to inspect (a flag icon
  + tinted card) without duplicating its name as a second, separately
  tappable text element.

## Accessibility / responsiveness

- Every icon-only `IconButton` carries a `tooltip` (exposed to screen
  readers via Flutter's semantics tree); evidence photo thumbnails
  carry an explicit `Semantics(image: true, label: ...)` describing
  either "Evidence photo" or "Evidence photo unavailable."
- No `textScaler` override anywhere — system text-scaling is respected.
- Status indicators pair an icon with a text label, never color alone.
- Screens use `SafeArea`, relative padding (`AppSpacing`), and
  scrollable layouts (`ListView`/`SingleChildScrollView`) rather than
  fixed pixel positioning, so common iPhone/Android phone sizes are
  supported without a separate breakpoint system.

## Manual end-to-end test checklist

See `docs/production_readiness.md` ("Manual E2E test sequence") for
the current, maintained checklist — camera-first capture, progressive
per-finding AI against the controlled catalogue, the authentication
hard gate, and report structure. Kept in one place rather than
duplicated here to avoid the two drifting out of sync.
