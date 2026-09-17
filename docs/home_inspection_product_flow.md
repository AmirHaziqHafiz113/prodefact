# Home Inspection Product Flow (Consolidation Pass)

> Updated by the P0 workflow-closure pass (schema v8) — see "P0
> closure pass" near the end for exactly what changed in that pass; the
> body of this document already reflects the current state.

This is the canonical, end-to-end description of ProDefact's Home
Inspection product — the source of truth for how the screens/workflows
fit together as one coherent lifecycle. It supersedes
`docs/home_inspection_workflow.md` as the top-level flow reference (that
document still has useful detail and now points here); the deeper
subsystem docs (`docs/ai_provider_architecture.md`, `docs/ai_review.md`,
`docs/report.md`, `docs/firebase.md`, `docs/production_readiness.md`,
`docs/commercial_model.md`) remain authoritative for their own areas and
are linked throughout.

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
       -> Area Notes / Inspection Notes (contextual, never a defect)
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

`InspectionQueueScreen` (`/home-inspection/inspection`). Plumbing areas
are listed first with the explanatory pill ("Plumbing area — inspect
first"); each area card shows physical status plus finding/photo
counts.

**Per-area AI/review counts (new this pass)**: each card now also shows
two more real, independent lines — `AI: 6/8 analysed` and
`Review: 4/8 reviewed` — computed by scoping `AiProcessingProgress`/
`AiReviewProgress` to that area's own findings/suggestions. A
zero-finding area reads `AI: No findings` / `Review: Not required`
rather than a misleading `0/0`. Physical, AI, and review are still
three genuinely independent counts, never combined into one number —
see `test/inspection_queue_screen_test.dart`.

**Sync status (new this pass)**: the app bar shows the active session's
sync pill (`Synced` / `N items waiting` / `Local only`), with the same
real pending-item count described in §2. A warning banner appears here
— *"This inspection is completed. Changes may require a new report
version."* — whenever the session's status is already `reported` (see
§11, "Completed inspection lifecycle").

**Area/Inspection notes (new this pass)**: an app-bar icon opens an
"Inspection note" editor (`ActiveInspectionSession.setInspectionNote`);
each area screen (§5) has the equivalent "Area note" action. Both are
optional, contextual, and never sent through AI classification —
persisted on `Section.note`/`InspectionSession.inspectionNote`
respectively, and surfaced in the generated report (see §10).

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

**Pending commercial-layer change (backend built, Flutter not yet
wired up — see `docs/commercial_model.md`).** Save Finding queuing AI
automatically, as described above, is the behavior this app has today.
A commercial pass has since built (but not yet integrated into this
screen) a backend contract where Save Finding stays free/physical-only
and AI analysis becomes a separate, explicit step: an estimate ("Up to
N Credits"), inspector approval, then `analyseFinding`. Until that
Flutter integration lands, this section's description remains accurate.

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

### Report metadata confirmation (new this pass)

`ReportDetailsScreen` (`/home-inspection/report-details`, reached via
"Report Details" in the Report screen's app bar) lets the inspector
review/edit the report's cover-page metadata — title, project,
address, block/unit, client, inspector, inspection date, and a
separate **report date** — right before generating, without going back
to Property Details. Saving writes a `ReportMetadata` (see
`lib/core/inspection/entities/report_metadata.dart`), stored
**separately** from `PropertyDetails` on
`InspectionSession.reportMetadata` — editing it can never corrupt the
original New Inspection setup record. `buildReportModel` prefers
`reportMetadata` when present, falling back to `PropertyDetails`, then
to the property type label for a session with neither (schema v6 and
earlier). The generated PDF also now includes the whole-inspection note
in its summary and each area's note under that area's heading, when
present — see `lib/data/report/pdf_report_renderer.dart`.

## 11. Completed Inspection / History

**Explicit lifecycle status (new this pass)**: a session's dashboard
pill (`_LifecycleStatusPill`) no longer collapses every non-`inProgress`
state into one "Completed" label. Each `InspectionStatus` value gets
its own honest label:

```
inProgress                    -> In Progress
physicalInspectionComplete    -> AI Processing
aiReviewComplete              -> Report Ready
reported                      -> Completed
```

Only `reported` (a report has actually been generated) reads
"Completed" — see `test/inspection_sessions_screen_test.dart`, "the
dashboard pill only reads 'Completed' once a report has actually been
generated." The dashboard's coarser Active/Recent grouping
(`InspectionSessionSummary.isComplete`, `status != inProgress`) is
unchanged, since that's a pre-existing Phase 4 contract several other
tests already depend on — only the *label* on each card became more
precise, not the grouping.

**Editing a completed inspection**: `InspectionQueueScreen` shows an
inline warning — *"This inspection is completed. Changes may require a
new report version."* — whenever the resumed session's status is
already `reported` (see §4). Nothing is blocked or silently modified;
the inspector can still add/edit findings, and doing so simply means
the next `Generate Report` produces the next version (§10, "Report
versioning") rather than silently overwriting the existing one.

`InspectionSessionsScreen`'s "Recent" section (renamed this pass — see
§2), plus the dashboard search/filter, is how a completed inspection is
found again. Full detail (evidence, AI original-vs-final, report) is
reached by resuming the session as before — unchanged data model.

## Offline / Sync / Error Handling

`docs/production_readiness.md` ("Offline-first guarantees", "Durable
write safety", "Error handling") and `docs/firebase.md` ("Sync
lifecycle") remain authoritative. Every new screen this pass (Property
Details, Review Setup, Profile, Report Details) reads/writes only
through the same `NewInspectionDraftNotifier`/`ActiveInspectionSession`/
`InspectionRepository` seams every existing screen already used, so
none of the offline-first guarantees needed to change.

### Real connectivity detection (new this pass)

`ConnectivityService` (`lib/core/inspection/services/connectivity_service.dart`)
is a new abstraction — `ConnectivityStatus { online, offline, unknown }`
— implemented by `ConnectivityPlusService`
(`lib/data/remote/connectivity_plus_service.dart`, the only file that
imports `connectivity_plus`; enforced by
`test/architecture/repository_boundary_test.dart`). It replaces the old
signed-in-only proxy:

- **Gating**: right before attempting to upload/classify a finding,
  `ActiveInspectionSession._enqueueAiClassification` awaits a **fresh**
  `ConnectivityService.checkStatus()` call (not a cached stream value —
  see the code comment on why) and stays `queued` (never shows
  `uploading`/`analyzing`) when it reads `offline`. An `unknown`
  reading is treated as online rather than blocking work on an
  ambiguous signal, and a genuine request failure despite a
  "connected"/`unknown` reading is still handled by the existing sync
  try/catch fallback — connectivity is a fast-path hint, never the sole
  source of truth (device connectivity ≠ working internet).
- **Auto-resume**: `ActiveInspectionSession.build()` listens to
  `connectivityStatusProvider` (a live stream) and calls the existing
  `processQueuedAiClassifications()` the moment the signal transitions
  to `online` — reusing its pre-existing idempotency guarantees (an
  in-flight guard plus a deterministic suggestion id), so a flaky
  reconnect signal firing twice can never duplicate a classification or
  a finding. See `test/features/connectivity_ai_resume_test.dart`.
- **Local-only/demo mode** (`firebaseReadyProvider` false) never
  touches connectivity at all — AI runs synchronously offline via the
  fake service regardless, exactly as before.

## Schema

Drift schema bumped **v6 -> v8** across this pass and the prior one,
strictly additive throughout (see the doc comment on `AppDatabase` in
`lib/data/local/database.dart` for the authoritative version history).

**v7** (prior pass):

- Nine nullable property-details columns + `inspectionDate` on
  `InspectionSessionRows`.
- `ReportRows.version` (`INTEGER NOT NULL DEFAULT 1`).
- New `UserProfileRows` table (a single local row).

Covered by `test/data/database_migration_test.dart`: v5->v7 and v6->v7
upgrade paths (including the specific "table already existed" edge
case the v6 migration already had to handle), plus a fresh install.

**v8** (this pass):

- `InspectionSessionRows.reportMetadataJson` (nullable, JSON-encoded
  `ReportMetadata` — deliberately separate from the v7 property-details
  columns; see §10) and `InspectionSessionRows.inspectionNote`
  (nullable).
- `SectionRows.note` (nullable) — per-area contextual notes.

Covered by `test/data/database_migration_test.dart`: a new v7->v8
upgrade test (confirms a pre-existing area row survives untouched) and
the fresh-install test extended to check the v8 columns.

## P0 items closed this pass (were P1 backlog)

- **Per-area AI/review counts** — done, §4.
- **Real connectivity detection** — done, "Real connectivity detection"
  above.
- **Area notes / inspection notes** — done, §4/§10 (schema v8).
- **Visible sync state on Inspection Overview** — done, §4.
- **Report metadata confirmation before generating** — done, §10
  (`ReportDetailsScreen`, schema v8 `ReportMetadata`).
- **Explicit "Completed" lifecycle status** — done, §11.

## P1 backlog (still deferred, documented, not built)

These were explicitly allowed to be partial/deferred per the brief's
P0/P1/P2 scope, to avoid destabilizing the P0 lifecycle above:

- **Reference photos** (non-defect area documentation). No data model
  change was made — `Evidence`/`Finding` are unchanged. The lowest-risk
  path when this is built is a `Finding.kind` (`defect`/`reference`)
  enum reusing the existing capture/evidence plumbing, with
  `isAiEligible` gated to `kind == defect`, rather than a new table.
- **Historical report PDF archive**. `Report.version` is tracked and
  displayed, but only the current version's PDF file is kept on disk —
  a future pass could keep every version's file (or re-render on
  demand from a stored `ReportModel` snapshot) rather than just the
  latest.
- **Cloud/push-delete sync**. Unchanged and still documented as a
  deliberate scope cut in `docs/production_readiness.md` ("Session
  deletion", "Known limitations") — deleting a session/finding locally
  never deletes previously-synced cloud data.

## P2 (explicitly out of scope this pass)

Unchanged from the existing P2 list — rectification/reinspection,
client portal, contractor workflow, team accounts, signatures, video/
audio evidence, measurement tools, thermal inspection, expansion to
other industries. See `docs/future_industry_extensibility.md`.
