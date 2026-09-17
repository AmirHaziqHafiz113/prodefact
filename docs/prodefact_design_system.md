# ProDefact Design System (Reference Synthesis Pass)

This is the authoritative visual design guide for ProDefact, superseding
`docs/ui_design_system.md` for **principles and rules** (that document
remains accurate for the specific navigation/component decisions made
in the consolidation pass it recorded — this document sets the system
those decisions should keep being measured against). `docs/design_system.md`
remains historical only.

**Scope of this pass:** this is a reference-synthesis and documentation
pass. No screen was redesigned, no Flutter code was changed, no
business logic was touched. This document is the input to a future
implementation pass, not a record of one.

## A note on the source material

Five external references were supplied in `docs/design-references/`:
Attio, Linear, Cal.com, Ramp, PocketUI. Before extracting principles,
it matters what these documents actually are, because it changes how
literally they can be trusted:

| Reference | What was actually captured | What was *not* captured |
|---|---|---|
| Attio | Marketing site only — pricing page, FAQ accordion, testimonial grid, CTA banner | No application UI at all |
| Linear | Marketing homepage **plus** four real workspace screens (issue list, project overview, inbox empty state) | No settings, no mobile layout, no color palette (explicitly withheld in the doc) |
| Cal.com | Application UI, but only auth/onboarding/signup — dark mode only | No dashboard, no booking management, no light mode |
| Ramp | Marketing homepage only — testimonials, feature sections, editorial photography | Explicitly excludes "the product dashboard interface, mobile navigation patterns, form components" — i.e. no wallet/financial *application* UI was actually shown |
| PocketUI | Marketing landing page for a dev tool | Explicitly excludes "pricing pages, authentication flows, application interface... and mobile-specific layouts" |

Four of five references are marketing sites for desktop SaaS products,
not mobile field tools, and only Linear shows real application screens.
None of them show a hand-held, outdoor, one-handed, camera-driven,
professional field workflow — which is what ProDefact actually is.
**This pass therefore treats all five as sources of transferable
*principles* (spacing discipline, type restraint, card judgment, status
treatment, elevation logic) rather than sources of literal layouts to
port.** Where a reference's own scope note says a pattern wasn't
observed (e.g. Ramp's transaction UI, PocketUI's mobile behavior), this
document says so rather than inventing a citation.

---

## Reference lesson summaries

### Attio
- **Adopt:** border-only card definition (no shadow elevation — a
  single hairline border at a consistent radius is enough to separate
  a card from its canvas); tight tracking on headings paired with
  generous body line-height (1.6) as a deliberate "scan vs. read"
  distinction; strict color discipline — one neutral scale, one accent,
  used only for interactive/highlighted moments.
- **Reject:** the dual-typeface system (a serif display face for hero
  moments) — ProDefact is a utility tool, not an editorial brand, and
  has no display-type use case; the four-column desktop grid and
  masonry testimonial layout, both meaningless on a phone; 6rem
  section spacing, which is a desktop marketing rhythm, not an
  operational one.

### Linear
- **Adopt (this is the highest-signal reference of the five, because
  it's the only one showing real dense application screens):**
  building hierarchy from alignment and hairlines *before* reaching for
  color or elevation; the explicit rule "do not promote every workspace
  region into a floating card"; a compact 12–16px operating type range
  for dense screens with only one true display moment per surface;
  8px/14–16px as the two working spacing rhythms for rows and controls;
  selected-state via subtle surface-fill rather than heavy borders;
  metadata reflowing from an inline strip to a stacked list on narrow
  width rather than being hidden or truncated; a genuinely sparse empty
  state (one message, small icon, no card wrapper).
- **Reject:** inventing a color palette or font family from this
  reference — it explicitly withholds both; assuming any hover/focus/
  loading/error state exists, since none were captured.

### Cal.com
- **Adopt (structure, not skin):** the three-level surface elevation
  model (canvas → surface → surface-elevated) as a *pattern* for
  showing depth without shadows; the single-column progressive setup
  flow (heading, step counter, one contained card, tertiary action
  below) as the shape for a guided wizard step; the horizontal segment
  step-progress indicator; full-width, centrally-padded buttons inside
  cards for comfortable touch targets.
- **Reject outright:** the dark canvas itself — ProDefact is light-mode
  only by design (field/outdoor legibility, printed-report continuity,
  existing brand), and there is no justification to introduce a second
  theme for this pass; Cal Sans as a second display typeface, for the
  same reason as Attio's serif; the split-panel product-preview layout,
  which is a desktop conversion pattern with no mobile equivalent.

### Ramp
- **Adopt:** weight restraint — using size and spacing to create
  hierarchy instead of bolding everything, which keeps a screen calm
  even when it's showing several numbers at once (directly relevant to
  Wallet, which shows balance + usage + history together); consistent
  card radius as a "family resemblance" device across otherwise
  different card types; treating photography/screenshots honestly
  rather than over-styling them — maps to ProDefact's existing "real
  data only, no fabricated placeholder charts" rule.
- **Important caveat:** Ramp's own scope note excludes its actual
  product dashboard and financial application UI. Nothing here is a
  transaction-list or financial-metric-card pattern actually observed
  in Ramp's app — it is inferred from marketing-page card treatment
  only. Wallet/Top Up/House Pass decisions in this document lean more
  heavily on Linear's density discipline and ProDefact's own existing,
  tested wallet screen than on Ramp.
- **Reject:** the warm off-white/peach-tinted neutral palette —
  ProDefact's existing cool mint-green `surfaceAlt` is core brand
  identity and already shipped/tested; introducing a second neutral
  temperature would fight it. Also reject: desktop-scale 24–32px card
  padding and 4–6rem section gaps, both too generous for a phone
  screen; the editorial full-bleed photography treatment, which has no
  ProDefact use case (there are no property photos in the data model —
  see "Image fallback rules" below).

### PocketUI
- **Adopt:** borders as the primary structural device over shadows
  (reinforces the Attio/Linear direction — this pass now has three of
  five references independently converging on border-first elevation,
  which is a strong signal, not a coincidence to second-guess); tight
  component-level spacing steps (4/8/12/16px) for icon-text pairs and
  grouped elements, directly useful for Profile/settings rows; treating
  checkmarks/status glyphs in a muted tone distinct from the
  interactive accent, so a "done" indicator is never mistaken for a
  tappable action.
- **Important caveat:** its own scope note excludes "application
  interface... and mobile-specific layouts" — despite being assigned to
  "mobile-first component behavior" in this task's reference mapping,
  the document contains no actual mobile screens. Its usefulness here
  is the border/spacing/type-restraint discipline, generalized to
  mobile touch targets by this document, not copied mobile patterns.
- **Reject:** the purple decorative accent color (a second accent on
  top of blue) — ProDefact keeps a single-accent discipline (amber,
  reserved); the two-column marketing grid and wide desktop margins.

---

## Conflicts between references, and how they were resolved

1. **Shadow elevation (Ramp) vs. border-only elevation (Attio, Linear,
   PocketUI).** Resolved in favor of **border-only**, 3-to-1 among the
   references and already ProDefact's shipped convention (see
   `docs/ui_design_system.md` — cards already use `AppColors.outline`
   borders, not `BoxShadow`). Shadow is reserved for true overlay
   surfaces only (bottom sheets, dialogs, the raised center nav
   button) — never for routine cards or rows.

2. **Editorial/display typefaces (Attio's Tiempos Text, Cal's Cal
   Sans) vs. a single functional type family (Linear, Ramp's
   single-family discipline, PocketUI).** Resolved in favor of **one
   functional family, no display face**. ProDefact is not a marketing
   surface; it has no hero-headline moment to justify a second
   typeface, and a second family would be pure maintenance cost.
   Hierarchy comes from the existing size/weight scale (`displaySmall`
   → `labelLarge`), not a font swap.

3. **Dark-mode-first (Cal.com) vs. light-only (every other reference
   and ProDefact's own shipped identity).** Resolved in favor of
   **light-only**. Cal's *structural* patterns (elevation steps,
   progressive single-column setup) were extracted and re-skinned to
   light surfaces; the dark canvas itself was rejected outright.

4. **Card-for-everything (Attio's pricing/testimonial grids, Ramp's
   testimonial grid, PocketUI's feature cards) vs. Linear's explicit
   "not every region deserves a card."** Resolved decisively in favor
   of **Linear's restraint** — this is the direct answer to Task 4
   below and the single most important behavioral change this document
   recommends. The other three references are marketing pages where
   every block *is* content and *is* meant to draw an eye; ProDefact
   screens are operational, and a screen where every row is a bordered
   rounded rectangle is the exact "generic AI dashboard" look the brief
   says to avoid.

5. **Desktop-scale generous spacing (Attio 6rem sections, Ramp 4–6rem
   sections and 132px margins, PocketUI 96px section padding) vs.
   dense operational spacing (Linear's 8/14–16px rhythms).** Resolved
   in favor of **Linear's density**, because ProDefact is mobile-only
   and field-operational — there is no viewport width to spend on
   desktop-scale whitespace, and "premium" in a field tool reads as
   *precise*, not *spacious*. ProDefact keeps its existing
   `AppSpacing` scale (4/8/12/16/24/32) rather than importing any
   reference's literal spacing values.

6. **Warm neutral canvas (Ramp) vs. cool neutral canvas (ProDefact's
   shipped `surfaceAlt`).** Resolved in favor of **keeping ProDefact's
   existing cool mint-green neutral** — this is core, already-tested
   brand identity, and the brief explicitly says preserve the
   green/teal identity.

None of these conflicts required compromise between references — in
every case one side aligned with ProDefact's existing, shipped identity
and the mobile-field nature of the product, and that side won.

---

## 1. Design philosophy

ProDefact is used by a professional inspector walking through a
property, often one-handed, sometimes in bright outdoor light, moving
fast between areas and photographing real defects under real time
pressure. Every screen's job is to answer **"what do I do right now"**
in under a second of scanning. Visual design here is not brand
expression for its own sake — it is a tool for reducing the inspector's
cognitive load during a real physical task. Calm, bordered, low-noise
surfaces (Attio/Linear) plus real, non-decorative data (existing
"real data only" rule) plus restrained weight/color use (Ramp) serve
that job. Editorial flourish, marketing-scale whitespace, and
decorative photography do not, and are rejected regardless of how well
they work on the marketing sites they came from.

## 2. Visual personality

Professional, premium, calm, field-ready, trustworthy, mobile-first —
unchanged from the existing identity. Add to this, made explicit by the
reference synthesis: **restrained**, in the specific sense Linear uses
it — attention is earned by hierarchy and alignment, not by
decoration, and the interface should feel *fast to scan even when
dense*, not sparse for its own sake. ProDefact is full but not
cluttered (see Density, §30), precise but not sterile (keeps its warm
green accent and real charts, unlike a pure grayscale tool like
Linear).

## 3. Color roles

No new tokens. `lib/app/theme/app_colors.dart` remains authoritative:

| Role | Token(s) | Note |
|---|---|---|
| Brand / primary action | `primary`, `primaryDark`, `primaryLight` | Deep green — hero surfaces, primary buttons, the one dominant accent |
| Highlight (reserved) | `accent` (amber) | CTA/highlight use only — not a second routine accent; kept scarce per the single-accent discipline three of five references converged on |
| Canvas | `surfaceAlt` | Cool mint-tinted neutral — kept over any reference's warm-neutral alternative |
| Card/surface | `surface` | White, border-defined, never shadow-defined for routine cards |
| Input/track fill | `surfaceMuted` | Inputs, progress tracks, skeletons |
| Structural line | `outline` | The primary structural device per Attio/Linear/PocketUI convergence — used before reaching for a second surface color or a shadow |
| Text | `textPrimary`/`textSecondary`/`textMuted` | Three-step hierarchy is enough; do not add a fourth |
| Status pairs | `success`/`warning`/`danger`/`info` (+ Bg) | Always icon + label, never color alone (unchanged rule) |
| Category (not status) | `plumbing`/`plumbingBg` | Kept visually distinct from the semantic status set |

## 4. Typography hierarchy

No new type scale or font family. `app_theme.dart`'s existing scale
(`displaySmall` → `labelLarge`) stays as the single functional
hierarchy — no second/display typeface is introduced (see Conflict 2).
Apply Ramp's weight-restraint lesson going forward: default to
`textPrimary`/`w400-500` body weight even in dense financial or
operational screens, and reserve `w700` for the one true heading per
screen, not every card title. A screen where four different labels are
all bold has no hierarchy left to show.

## 5. Spacing scale

Unchanged: `AppSpacing` xs=4, sm=8, md=12, lg=16, xl=24, xxl=32 — the
only values used, no magic numbers. This scale already sits closer to
Linear's dense operational rhythm (8/14–16px) than to any marketing
reference's desktop spacing, which is correct for a phone screen and
should not be loosened.

## 6. Radius scale

Unchanged: `AppRadius` sm=8 (chips/thumbnails), md=12 (inputs/buttons),
lg=16 (cards), xl=20 (hero cards/sheets), pill=999. This already
matches the "consistent radius as family resemblance" principle Ramp
and PocketUI both independently demonstrate — one radius per role,
applied everywhere that role appears.

## 7. Elevation / border rules

**Border-first, shadow-rare** (Conflict 1). Rules:

- Routine cards, rows, and grouped lists: **1px `outline` border, no
  shadow.** This is now reinforced by three of five references, not
  just prior convention.
- Hero cards (`AppHeroCard`): the gradient fill itself provides
  separation; still no drop shadow.
- True overlays only — bottom sheets, dialogs, the raised center nav
  button — may use a soft shadow, because they are genuinely floating
  above the page, not sitting in its flow.
- Selected/active state (e.g. selected plan card, active nav
  destination): a subtle fill-color or border-color change, per
  Linear's "selected row gets subtle contrast, not a heavy border" —
  never a shadow-based "lift."

## 8. Page structure

Every screen: `SafeArea` → optional `AppTopBar` composition → scroll
body (`ListView`, not fixed positioning) → one primary action, visually
dominant, placed where a thumb reaches it (bottom-anchored or top of
the fold, screen-dependent — never buried below a long scroll on an
action-required screen). This is unchanged from the current shipped
pattern and is not renegotiated by this pass.

## 9. Card taxonomy (Task 4 — reducing generic card overuse)

This is the most important behavioral change in this document. The
question for every piece of information is: **"If I removed the
border/surface around this, would it lose any meaning?"** If not, it
doesn't get a card.

| Treatment | When to use it | ProDefact examples |
|---|---|---|
| **Flat section** | Page-level grouping where a header + spacing already separates it from neighbors; no border, no surface | A screen's "Recent Activity" section under its own `AppSectionHeader`, sitting directly on `surfaceAlt` |
| **Bordered row** | One item in a sequential list, where the *list* is the container, not each item | Inspection list rows, wallet transaction history rows, notification-style items |
| **Grouped list** | Several related rows that should read as one unit (settings-style) | Profile screen — one bordered container holding Account/Support/App rows with internal hairline dividers, **not** five separate stacked cards |
| **Hero card** | The single most important thing on the screen — at most one per screen | Home's active-inspection hero, Inspection Overview's progress hero, Wallet's balance card (`AppHeroCard`, unchanged) |
| **Elevated/bordered card** | A genuinely distinct, independently actionable unit — you could tap or act on this one thing without the rest of the screen | A finding card, a plan-choice card, an area-queue card |
| **Inline metric** | A single number + label with no independent action | A stat sitting directly in a header row — not everything needs `AppMetricCard`; reserve that component for when 2–4 stats need equal visual weight side by side |
| **Pill / chip** | Status or category label, always inline with text, never a mini-card | `StatusPill`, `SyncStatusPill`, area status chips |
| **Banner** | Full-bleed, edge-to-edge colored strip for a state that affects the whole screen | Offline banner, "needs attention" warning banner — deliberately *not* inset like a card, so it reads as systemic, not as one more content block |
| **Bottom sheet** | A focused decision that should pause the main flow | AI approval decision, plan confirmation |

**Rule of thumb going forward:** a screen should show at most one hero
card, a handful of elevated cards for genuinely distinct actionable
units, and everything else as flat sections, bordered rows, grouped
lists, pills, or inline metrics. If a screen's build produces five or
more visually identical rounded rectangles stacked vertically, that is
the "card / card / card / card / card" failure mode the brief names,
and the fix is to reclassify most of them as bordered rows inside one
grouped list, not to keep them as separate cards.

## 10. Buttons

Unchanged component set, restated with the priority discipline from
§6 (Task 6) below applied: exactly one filled/primary button per screen
state; secondary actions are outlined or tonal, never a second filled
button competing for the same attention. Full-width primary buttons
for the one decisive action on a form-like screen (Cal.com's pattern,
adopted); compact inline buttons for secondary/tertiary actions.

## 11. Inputs

`surfaceMuted` fill, `outline` border, `AppRadius.md` — unchanged.
Cal.com's label-above-input-above-helper-text stacking is already
ProDefact's pattern; keep it. Grouped related fields (e.g. address
line 1/2) compress spacing to `AppSpacing.sm` between them and
`AppSpacing.lg` between unrelated field groups — Cal's "0.75rem within
a group, 1rem between groups" distinction, mapped onto ProDefact's own
scale.

## 12. Status chips

Unchanged: `StatusPill`/`SyncStatusPill`, always icon + label, never
color alone. PocketUI's lesson applies directly: a status glyph (done/
in-progress/needs-attention) must never visually resemble the
interactive accent color, so it's never mistaken for a tappable
button.

## 13. Progress indicators

Unchanged: `AppProgressBar`, `AppRingProgress`. No visual change
recommended by this pass; the recent responsiveness pass already
hardened these against overflow.

## 14. Charts

Unchanged: `AppBarChart`, real-data-only. Ramp's "treat data honestly"
principle reinforces the existing rule — never a placeholder/fabricated
data point, which the codebase already avoids by construction.

## 15. Bottom navigation

Unchanged: the floating pill bar with a raised center "+" action.
No reference here shows a mobile bottom nav (none of the five have a
genuine mobile capture), so this stays exactly as shipped.

## 16. Wizard stepper

Unchanged component (`AppWizardStepper`), but its *shape* is now
additionally validated by Cal.com's onboarding pattern: heading + step
counter above a single contained step, tertiary "back" action below,
one thing to do per screen. This is what ProDefact's New Inspection
wizard already does — no change, just confirmed as correct.

## 17. Lists

Apply Linear's row discipline: stable text baselines, low-contrast
hairline separators between rows, identifier/status/title/metadata
aligned on one line where it fits, reflowing to stacked pairs
(label above value) rather than truncating when width is tight (this
generalizes the "metadata reflows before information is hidden"
lesson, and is consistent with the responsiveness pass's `Wrap`-based
fixes). Do not wrap each row in its own bordered card (§9).

## 18. Finding cards

The one place an "elevated/bordered card" per-item is clearly correct
(§9) — a finding is a genuinely distinct, independently actionable unit
(has its own photo, note, defect classification, edit/delete actions).
Keep the existing direct-icon-button pattern on `AreaInspectionScreen`
(documented in `docs/ui_design_system.md` as an intentional exception
to the overflow-menu convention, for test-suite stability) — this pass
does not revisit that decision.

## 19. Wallet / financial UI

No reference actually shows financial application UI (Ramp's own scope
note excludes its dashboard). This section is therefore led by
Linear's density discipline and ProDefact's own shipped, tested Wallet
screen, not by Ramp's marketing cards. Apply: weight restraint on the
balance figure (one clearly larger number, not multiple competing bold
figures), inline metrics for secondary stats (avg/analysis, this
period's usage) rather than a wall of `AppMetricCard`s, and bordered
rows (not cards) for transaction history — a transaction list is a
sequential list per §17/§9, not a stack of cards.

## 20. Profile / settings rows

Grouped list (§9), not stacked cards — directly informed by PocketUI's
border-as-structure lesson and Linear's row discipline. One bordered
container per logical group (Account, App, Support), hairline dividers
between rows within a group, `AppSpacing.lg` between groups.

## 21. Empty states

Linear's empty-inbox pattern, generalized: a genuinely sparse state —
one clear message, a small icon if useful, centered in the available
region, **not wrapped in an attention-seeking card.** Reserve for
actual absence of content (no inspections yet, no transactions yet);
do not reuse as a generic onboarding hero.

## 22. Loading states

Unchanged: static (non-animated) `AppSkeletonBox`/`AppSkeletonCardList`
— deliberately not animated, for the ticker/`pumpAndSettle` reason
already documented in `docs/ui_design_system.md`. No reference material
changes this.

## 23. Error states

Unchanged: `AppErrorView`/`AppInlineErrorBanner`. Apply the banner
treatment from §9 — full-bleed, not inset like a card, so an error
reads as systemic rather than as one more content block competing with
the rest of the screen.

## 24. Offline / sync states

Unchanged: `SyncStatusPill`, `AppInlineWarningBanner`. Same banner
discipline as §23.

## 25. Image fallback rules

Unchanged, and directly reinforced by rejecting Ramp's editorial
photography treatment (§Ramp lessons) — ProDefact has no property/area
photo capture in its data model, so `AppFallbackThumbnail` (icon on
gradient) remains the only correct treatment, never a stock or
fabricated photo. `AppAvatar` (generated initials) remains the only
correct user representation.

## 26. Animation rules

Unchanged: bounded `TweenAnimationBuilder`/`AnimatedContainer` only,
never an unbounded/looping `AnimationController`. No reference
supplies real motion specifications (all five explicitly withhold
this), so this pass does not add or change animation guidance beyond
what's already shipped.

## 27. Mobile touch target rules

Minimum 44×44pt tap targets on every interactive element — this is
stated explicitly in Attio's accessibility section and is standard
practice; apply it uniformly, including icon-only buttons
(`AreaInspectionScreen`'s per-finding icon buttons, overflow menu
triggers, chip taps). Full-width primary buttons on forms/wizard steps
(Cal.com's pattern) inherently satisfy this; verify icon-only buttons
specifically, since they're the ones most likely to fall short.

## 28. Accessibility

Existing rules unchanged and reinforced by the references: status
communicated by icon + label never color alone (already ProDefact
convention, reinforced by PocketUI's "don't confuse status glyphs with
actions"); minimum 4.5:1 text contrast (all references that state a
number agree on this); visible focus/selection states via
border/fill-color change, not shadow alone (Linear).

## 29. Responsive rules

Unchanged from the recently-completed responsiveness pass
(`docs/ui_design_system.md`'s "Responsiveness" section): `SafeArea`,
`AppSpacing`-based padding, scrollable layouts, `FittedBox` for
brand-mark/label elements that can't budget exact pixels, `Flexible`/
`Wrap` for any Row that pairs a flexible element with an unflexible
trailing pill/chip. Add one new rule from Linear's responsive
capture: **reflow metadata before hiding it** — when a row's secondary
information (date, count, status) doesn't fit inline at a given text
scale or width, stack it below the primary label rather than
truncating or dropping it.

## 30. Density rules (Task 5)

ProDefact should feel full but not cluttered — the exact target stated
in the brief. Per-screen density:

| Screen | Density | Why |
|---|---|---|
| Splash | Minimal | Single brand moment, nothing to scan |
| Sign In (Auth) | Low | One decision (sign in), form-focused |
| Home | Medium | One hero + a short list of secondary info — orienting, not operational |
| Inspections (sessions list) | Medium-high | A working list an inspector scans repeatedly during the day |
| Property Type | Low | A single, large-target decision screen |
| Property Details | Low-medium | A form — density comes from field count, not decoration |
| Configure Areas | Medium-high | Many toggleable rows; this is the list-of-rows case, not cards |
| Choose AI Plan | Low | A small number of large, comparable decision cards — the one place a card-grid is correct, because each card *is* a distinct choice |
| Review Setup | Medium | A summary — denser than a form, lighter than an operational screen |
| Inspection Overview (queue) | High operational density | The working screen during an actual inspection — must show maximum real state per scroll |
| Area Detail / Finding list | High operational density | Same reasoning — this is the screen open while physically walking a property |
| Finding Capture | Low | A focused, single-task moment (camera + note) — deliberately quiet so the photo/note is the whole screen's attention |
| AI Approval (dialog/sheet) | Medium | A focused decision surface, denser than capture but still single-purpose |
| AI Review | Medium-high | Per-area classification results — operational, but read-only/reviewable rather than actively worked |
| Wallet | Medium-high financial density | Balance + usage + history together, but weight-restrained (§19), not crowded |
| Top Up | Low-medium | A focused transaction flow — one decision, minimal distraction |
| House Pass | Medium | Pricing/decision screen — denser than Top Up because it's comparing a surcharge estimate, lighter than the operational screens |
| Profile | Medium, grouped-settings density | Grouped list (§20), not stacked cards |
| Report | Medium | Read-only summary, scannable but not operational |
| Completed Inspection | Medium | Same reasoning as Report |

## 31. Visual priority levels (Task 6)

Every screen defines its actions in three tiers, so no two actions ever
compete for the same attention:

- **Primary** (exactly one visually dominant, filled/colored action per
  screen state): Start Inspection, the camera/capture action, Analyse,
  Generate Report, Complete Physical Inspection, Continue/Next in the
  wizard.
- **Secondary** (outlined or tonal, present but not competing): Top
  Up, filters, notes/edit actions, progress indicators, plan-choice
  selection before confirmation.
- **Tertiary** (text-only or icon-only, muted color, lowest visual
  weight): overflow-menu actions, metadata, timestamps, sync/delete
  actions, "View details" links.

Rule: if a screen has two buttons that look equally weighted, one of
them is miscategorized. This is the direct fix for "every button/action
having equal visual weight," and it applies retroactively as a review
lens for the screens already shipped, not just future ones.

## 32. Do / Don't examples

| Do | Don't |
|---|---|
| One hero card per screen, at most | A hero card *and* three more cards that all visually compete with it |
| Bordered rows inside one grouped list for Profile | Five separate stacked cards for Profile's Account/Support/App sections |
| A single filled primary button per screen state | Two filled buttons side by side, both demanding equal attention |
| Reflow metadata to a stacked line when width is tight | Truncate or silently drop metadata to fit a fixed-width Row |
| Use size + spacing for hierarchy, bold sparingly | Bold every label, heading, and value on a dense screen until nothing stands out |
| Full-bleed banner for offline/error/warning states | An inset "warning card" that reads as just another content block |
| Icon + label for every status | Color-only status (fails colorblind users, fails the existing accessibility rule) |
| `AppFallbackThumbnail` for every property/area "photo" | A stock or placeholder photo implying a capture feature that doesn't exist |

---

## Task 2 — ProDefact screen → reference mapping

Read this table with the caveat above in mind: "Relevant reference"
names which reference's *principles* were leaned on most, not a
literal layout source — none of the five references contain an actual
property-inspection screen.

| ProDefact Screen | Relevant Reference | Principles to adopt | Principles to reject |
|---|---|---|---|
| Splash | — (none apply) | Minimal, single brand moment; no reference shows a splash screen | N/A |
| Sign In (Auth) | Cal.com (structure only) | Single-column centered form, full-width primary button, label-above-input stacking | Dark canvas, Cal Sans, split-panel product-preview persuasion layout |
| Home | Attio + Linear | Attio's calm hierarchy/border-only cards for the hero; Linear's "not everything is a card" for the secondary info below it | Attio's masonry/grid patterns; any desktop spacing scale |
| Inspections | Linear | Dense row-based list, hairline separators, status mark + title + metadata on one line, reflow-not-truncate on narrow width | Turning each inspection into its own elevated card |
| Property Type | Cal.com (structure) | Large, clear decision cards — the correct case for a card grid, since each *is* a distinct choice | Dark mode, split-panel layout |
| Property Details | Cal.com | Grouped form fields, tight spacing within a group vs. between groups, label/input/helper stacking | Dark canvas, Cal Sans display headings |
| Configure Areas | Linear + PocketUI | Row-based list of toggleable items with hairline separators; border-first structure | Wrapping every area row in its own card |
| Choose AI Plan | Cal.com + Attio | Cal's step-progress pattern; Attio's border-only comparison-card treatment (small number of cards, genuinely comparable — correct card use) | Attio's four-column desktop grid, "Save" gradient badges |
| Review Setup | Linear | Vertical detail sequence: identity, then properties inline/stacked, then confirmation — "introduce info in the order needed to act" | Any card-grid treatment; this is a summary, not a comparison |
| Inspection Overview | Attio (density) + Linear (restraint) | High-density hero + list combination, but list rows stay row-based, not card-based | Attio's card-for-everything marketing layout |
| Area Detail | Attio (density) + Linear (restraint) | Same as above — high operational density via list rows and inline metrics, not stacked cards | Generous marketing spacing |
| Finding Capture | Linear (empty-state restraint) | Deliberately quiet, single-task screen — same "don't wrap in an attention-seeking card" principle applied to a focused capture moment | Any decorative framing around the camera/note UI |
| AI Approval | Cal.com (progressive disclosure) | Focused bottom-sheet decision surface, one clear action | Dark mode, multi-panel layout |
| AI Review | Linear | Per-area results as a scannable list, status marks inline with titles | Turning every classified finding into its own bordered card |
| Wallet | Linear (density) — **not** Ramp (Ramp's dashboard wasn't captured) | Weight-restrained balance figure, inline metrics for secondary stats, bordered rows for transaction history | Ramp's card-based testimonial-grid treatment, warm neutral palette |
| Top Up | Cal.com (single-column focus) | One clear decision, full-width primary action, minimal distraction | Split-panel persuasion layout, dark canvas |
| House Pass | Attio (comparison card, border-only) | Small number of genuinely comparable pricing options, border-only card treatment | Four-column desktop grid, gradient "Save" badges |
| Profile | PocketUI + Linear | Grouped list with hairline-divided rows, border-first structure, tight icon-text spacing | Stacked individual cards per setting; purple/second-accent decoration |
| Report | Linear | Scannable, read-only summary — same restraint as Review Setup | Editorial photography treatment |
| Completed Inspection | Linear | Same as Report | Same as Report |

---

## Files created / updated

- **Created:** `docs/prodefact_design_system.md` (this file) — the
  authoritative visual design guide going forward.
- **No other files were created or modified.** No application code,
  no screen, no widget, no business logic was touched, per the task's
  explicit scope.

## Recommended next UI implementation pass

Given this document, the highest-value next pass (not started, and
should be scoped/approved separately before any code changes) is:

1. **Profile screen restructure** — convert its current layout to the
   grouped-list pattern (§20/§9) — the single clearest, lowest-risk
   "card / card / card" fix identified, since Profile is explicitly a
   settings-style screen with no genuine per-row independent action.
2. **Wallet weight-restraint pass** — audit the balance/stat figures
   for competing bold weights (§19) and convert secondary stats from
   `AppMetricCard` grids to inline metrics where they don't need equal
   visual weight with the balance.
3. **A systematic §9 card-taxonomy audit** across every screen inventoried
   in the Task 2 table — a short pass that reclassifies any row-like
   content currently wrapped in an individual bordered card into a
   bordered row inside a grouped list, guided by the "would removing
   the border lose meaning?" test.
4. **Visual priority audit (§31)** — a review pass (not necessarily a
   redesign) confirming each screen has exactly one primary action;
   likely to surface a small number of screens where two buttons
   currently compete.

Each of these should be scoped as its own explicit implementation pass
with the user's sign-off before touching Flutter code, consistent with
this pass being synthesis-only.
