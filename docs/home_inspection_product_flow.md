# Home Inspection Product Flow (Consolidation Pass)

This is the canonical, end-to-end description of ProDefact's Home
Inspection product — the source of truth for how the screens/workflows
fit together as one coherent lifecycle. It supersedes
`docs/home_inspection_workflow.md` as the top-level flow reference (that
document still has useful detail and now points here); the deeper
subsystem docs (`docs/ai_provider_architecture.md`, `docs/ai_review.md`,
`docs/report.md`, `docs/firebase.md`, `docs/production_readiness.md`)
remain authoritative for their own areas and are linked throughout.

ProDefact's definition: **a camera-first property inspection system
where inspectors capture evidence naturally, AI maps that evidence to a
controlled defect library in the background, the inspector verifies the
results, and the system produces a professional standardized defect
report.**

## The lifecycle

```
App launch
  -> Authentication (hard gate once Firebase is configured)
  -> Home (the inspections dashboard)
  -> New Inspection
       -> Property Type (High Rise / Landed)
       -> Property Details (title, address, project, unit, client, inspector, date)
       -> Area Configuration (include/exclude/rename/add/remove, plumbing flag)
       -> Review Setup (read-only summary) -> Start Inspection
  -> Inspection Overview (physical / AI / review progress, plumbing-first area list)
  -> Physical Area Inspection
       -> Take Defect Photo -> Preview -> optional note -> Save Finding
       -> Add Another Photo (same finding, more evidence)
       -> Area Notes / Inspection Notes (P1 — see below)
  -> Background AI Classification (progressive, per finding)
  -> Area Completion -> Continue Property
  -> Physical Inspection Complete
  -> AI Review (Accept / Change / Reject, grouped by area)
  -> Report Readiness
  -> Generate Report -> Report Preview -> Share / Export
  -> Completed Inspection / History (dashboard, searchable/filterable)
```

Every step below names the screen/route and the code that owns it.

## 1. Authentication

Unchanged in substance from the existing hard-gate design — see
`docs/production_readiness.md` ("Authentication hard gate") for the full
rationale. What changed this pass: the **dashboard is now the app's
initial route** (`InspectionSessionsScreen.routePath`,
`lib/app/router/app_router.dart`) — the old `HomeShellScreen` splash
("ProDefact — Start Home Inspection") added a pointless extra tap with
no data of its own and has been removed. Since the dashboard is already
under the gated path prefix (`/home-inspection`), an unauthenticated
caller is redirected to Sign In on the very first frame whenever
Firebase is configured, exactly as before — there is no longer an
unguarded screen in between.

Sign In / Register / Forgot Password remain one screen
(`SignInScreen`, toggle-based) — unchanged this pass.

## 2. Home (dashboard)

`InspectionSessionsScreen` (`/home-inspection/sessions`) answers the
three dashboard questions directly:

- **What am I working on?** — "Active inspections" section.
- **What needs my attention?** — new **"Needs attention"** section,
  above Active: any inspection with a pending AI review suggestion or a
  failed AI classification (`InspectionSessionSummary.needsAttention`,
  backed by real `aiPendingReviewCount`/`aiFailedFindingsCount` values
  computed by the repository — never a fabricated count).
- **How do I start a new inspection?** — the "New Inspection" FAB, as
  before.

New this pass:

- **Search** — a text field filtering the visible list by title, unit,
  address, or property type label (client-side, case-insensitive
  substring match over already-loaded summaries).
- **Filters** — All / In Progress / Needs Review / Report Ready /
  Completed, as `ChoiceChip`s, derived from each session's existing
  `status`/`aiPendingReviewCount` — no new persisted state.
- **Profile entry point** — a person icon in the app bar opens
  `ProfileScreen` (see §9).
- **Richer cards** — a card now shows the captured property title and
  unit/address (falls back to the property type label for a session
  with no property details — schema v6 and earlier), alongside the
  existing sync pill, completion pill, and AI progress line.

## 3. New Inspection

### Step 1 — Property Type

`PropertyTypeSelectionScreen` (`/home-inspection`) — unchanged.
Selecting High Rise/Landed only begins an in-memory
`NewInspectionDraft` (`NewInspectionDraftNotifier`); nothing is
persisted yet.

### Step 2 — Property Details (new this pass)

`PropertyDetailsScreen` (`/home-inspection/property-details`). Captures
the metadata the report's cover page and the dashboard card need:

- **Required**: Inspection / Property title.
- **Optional**: property address, project/development name, block/
  tower, unit number, client/owner name, inspector name (prefilled from
  the on-device profile — see §9), developer, contact number,
  inspection date (defaults to today).

Purely in-memory (`NewInspectionDraft.propertyDetails`) until Start
Inspection — backing out here leaves nothing behind, same guarantee as
every other setup step. "Continue" validates only the required title
and proceeds to Area Configuration.

### Step 3 — Area Configuration

`AreaConfigurationScreen` (`/home-inspection/areas`) — unchanged
behavior (include/exclude, rename, add/edit/remove custom areas, a
"Contains plumbing" flag, reset to defaults). What changed: its bottom
action is now **"Review & Start"**, which pushes to Review Setup rather
than creating the inspection directly.

### Step 4 — Review Setup (new this pass)

`ReviewSetupScreen` (`/home-inspection/review`) — a read-only summary:
property title/type, address, project/unit/client, selected areas
(with plumbing areas called out and the plumbing-first rationale
explained), inspector, and inspection date. **This is now the only
screen that calls `NewInspectionDraftNotifier.startInspection()`** —
guarded against a double-tap exactly as the old in-place button was
(see `test/area_configuration_screen_test.dart`, "repeated taps on
Start Inspection do not create duplicate inspections"). "Back" returns
to Area Configuration without losing any draft state.

**No phantom inspections**: nothing is written to the database until
"Start Inspection" on this screen succeeds — confirmed for every step
along the new, longer setup path in
`test/area_configuration_screen_test.dart` and
`test/inspection_sessions_screen_test.dart`.

## 4. Inspection Overview

`InspectionQueueScreen` (`/home-inspection/inspection`) — unchanged
this pass. Plumbing areas are listed first with the explanatory pill
("Plumbing area — inspect first"); each area card shows physical status
plus finding/photo counts. (AI/review counts per area card are not yet
surfaced here — see "P1 backlog" below.)

## 5. Physical Area Inspection — camera-first capture

`AreaInspectionScreen` (`/home-inspection/inspection/:sectionId`) —
"Take Defect Photo" remains the sole, prominent primary action; no
element/component picker is ever shown first. Flow: Take Photo ->
Preview -> optional side note -> Save Finding. Saving persists the
finding immediately and queues AI in the background — see
`docs/ai_provider_architecture.md` ("Progressive per-finding AI
pipeline"). Nothing about this changed.

### Multi-photo (wired up this pass)

The underlying capability (`ActiveInspectionSession.addEvidence`,
attaching a new photo to an *existing* finding and re-queuing AI if the
finding had already settled) already existed but had no UI entry point.
Each finding card now has an **"Add another photo"** action
(`Icons.add_a_photo_outlined`) that calls it directly — see
`test/physical_inspection_flow_test.dart` ("'Add another photo' attaches
a second photo... and re-queues it for AI").

### AI failure fallback: Retry + Classify Manually (new this pass)

A `failed` finding's status line now shows two actions, not one:
**Retry** (unchanged) and **Classify Manually** — opens the same
searchable, controlled-catalogue picker "Change" uses, and calls the
new `ActiveInspectionSession.manuallyClassifyFinding(findingId,
catalogueEntryId)`, which creates a `providerId: 'manual'` suggestion
(no invented `suggestedCatalogueEntryId` — that stays null, honestly
recording that AI never classified this one) with the inspector's pick
as the final value, and marks the finding `completed`. A no-op if a
suggestion already exists for that finding (the `needsReview`/
`completed` cases already have "Change" for this). See
`test/features/active_session_provider_test.dart` ("manual
classification").

## 6. Background AI Classification

Unchanged — see `docs/ai_provider_architecture.md` and
`docs/ai_review.md` in full. Progressive, per-finding, against the
controlled 11-main-element / 34-component / 222-defect-entry catalogue
(`tool/generate_defect_catalogue.py` — counts verified this pass, exact
match).

## 7. Area / Continue Property / Physical Inspection Complete

Unchanged this pass — area completion is independent of AI/review
progress; "Complete Physical Inspection" is enabled once every included
area is done and navigates to AI Review.

## 8. AI Review

`AiReviewOverviewScreen` (`/home-inspection/complete`). Changed this
pass:

- **Grouped by area** — suggestions are now listed under their area's
  name, in the inspection's configured area order (a suggestion whose
  area was since excluded/removed still appears, in an unlabeled
  trailing group, rather than being silently dropped).
- **Photo thumbnail** — each card now shows the finding's first photo
  next to "Your note", not just a photo count.
- **Collapsible "AI details"** — confidence and the short reason are
  now behind a tap-to-expand "AI details" row instead of always
  visible, keeping the primary Accept/Change/Reject decision
  uncluttered.

Accept/Change/Reject semantics, and the original-vs-final preservation
guarantee, are unchanged — see `docs/ai_review.md`.

## 9. Profile (new this pass)

`ProfileScreen` (`/home-inspection/profile`), reached from the
dashboard's app bar. Shows the signed-in email (read-only, from
Firebase Auth — never a raw uid) or "Local inspector" in local-only
mode, plus two editable, on-device-only fields: **company name** and
**inspector name** (`UserProfile`, a single local row — not synced to
Firebase). These prefill the inspector name on the Property Details
step and are available for report metadata. Sign out is available here
when signed in.

## 10. Report Readiness & Report

`ReportScreen` (`/home-inspection/report`) — the "not generated" state
now shows a genuine **Report Readiness** breakdown, not just an
areas/findings/photos summary:

```
Physical inspection   12/12 complete
AI analysis            43/43 processed
Review                 41/43 reviewed
Unresolved              2 finding(s)      (shown only when > 0)
```

Each row is real, count-based (`PhysicalProgress`/
`AiProcessingProgress`/`AiReviewProgress`, `AiSuggestionStatus.rejected`
count for "Unresolved") — never a derived/misleading single percentage.
The three-axis report gate itself (physical complete AND no AI
in-flight AND no suggestion pending) is unchanged — see
`docs/report.md`.

### Report versioning (new this pass)

`Report.version` (defaults to 1, additive schema column) increments
every time `DefaultReportCoordinator.generateReport` regenerates a
report for a session that already has one. The "Generated" pill now
reads "Generated v2 · 2026-01-05", and the existing staleness banner
now says explicitly: *"This inspection has an existing report (v1)...
regenerating will create v2."* This satisfies the product requirement
that editing after a report exists never silently overwrites — the
inspector always sees the version number change. **Not yet
implemented**: only the *current* version's PDF is kept on disk (the
"latest report per inspection" policy from `docs/report.md` is
unchanged) — no historical v1/v2/v3 PDF archive. That would be a
follow-up storage change, not a data-model one (the version number is
already durable).

### Report metadata (new this pass)

The PDF cover page now uses the captured `PropertyDetails` (title,
project/development, block/unit, address, client, inspector) when
present, falling back to the property type label for a session with no
property details (schema v6 and earlier) — see
`lib/data/report/pdf_report_renderer.dart`. There is no separate
"confirm metadata" dialog before generating; the report always reflects
whatever was captured during Property Details setup — editing it after
generation is future work (see P1 below).

## 11. Completed Inspection / History

Unchanged data model this pass — `InspectionSessionsScreen`'s
"Completed" section, plus the dashboard search/filter above, is how a
completed inspection is found again. Full detail (evidence, AI
original-vs-final, report) is reached by resuming the session as
before.

## Offline / Sync / Error Handling

Unchanged this pass — see `docs/production_readiness.md`
("Offline-first guarantees", "Durable write safety", "Error handling")
and `docs/firebase.md` ("Sync lifecycle"). Every new screen this pass
(Property Details, Review Setup, Profile) reads/writes only through the
same `NewInspectionDraftNotifier`/`ActiveInspectionSession`/
`InspectionRepository` seams every existing screen already used, so
none of the offline-first guarantees needed to change.

## Schema

Drift schema bumped **v6 -> v7**, strictly additive (see the doc
comment on `AppDatabase` in `lib/data/local/database.dart` for the
authoritative version history):

- Nine nullable property-details columns + `inspectionDate` on
  `InspectionSessionRows`.
- `ReportRows.version` (`INTEGER NOT NULL DEFAULT 1`).
- New `UserProfileRows` table (a single local row).

Covered by `test/data/database_migration_test.dart`: v5->v7 and v6->v7
upgrade paths (including the specific "table already existed" edge
case the v6 migration already had to handle), plus a fresh install.

## P1 backlog (documented, not built this pass)

These were explicitly allowed to be partial/deferred per the brief's
P0/P1/P2 scope, to avoid destabilizing the P0 lifecycle above:

- **Reference photos** (non-defect area documentation). No data model
  change was made — `Evidence`/`Finding` are unchanged. The lowest-risk
  path when this is built is a `Finding.kind` (`defect`/`reference`)
  enum reusing the existing capture/evidence plumbing, with
  `isAiEligible` gated to `kind == defect`, rather than a new table.
- **Area notes / inspection notes**. No field exists yet on `Section`
  or `InspectionSession` — this is new schema work (an additive
  `notes` column on each), not a repurposing of an existing field.
- **Real connectivity detection**. `isOnlineForAiProvider`
  (`lib/data/remote/remote_providers.dart`) is still a proxy
  (Firebase-configured-and-signed-in), not real network-reachability
  detection — see `docs/production_readiness.md` ("Known
  limitations"). Adding `connectivity_plus` was scoped for this pass
  but not implemented, to keep the change set focused on lifecycle
  coherence; it's an isolated, additive change to that one provider
  when picked up.
- **Cloud/push-delete sync**. Unchanged and still documented as a
  deliberate scope cut in `docs/production_readiness.md` ("Session
  deletion", "Known limitations") — deleting a session/finding locally
  never deletes previously-synced cloud data.
- **Per-area AI/review counts on the Inspection Overview screen**. The
  area card still shows only physical status + finding/photo counts;
  AI/review status is visible per-finding on the area screen itself and
  in aggregate on AI Review, just not yet rolled up per-area on the
  overview list.
- **Editable report metadata / re-confirm before generating**. The
  report always uses whatever was captured at Property Details setup
  time; there's no separate "confirm/edit metadata" step immediately
  before Generate Report.
- **Historical report PDF archive**. `Report.version` is tracked and
  displayed, but only the current version's PDF file is kept on disk.

## P2 (explicitly out of scope this pass)

Unchanged from the existing P2 list — rectification/reinspection,
client portal, contractor workflow, team accounts, signatures, video/
audio evidence, measurement tools, thermal inspection, expansion to
other industries. See `docs/future_industry_extensibility.md`.
