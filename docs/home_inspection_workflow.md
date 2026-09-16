# Home Inspection Workflow

This is ProDefact's end-to-end Home Inspection workflow as implemented
today — **camera-first**, with AI running progressively per finding
against a controlled defect catalogue. See `docs/ai_provider_architecture.md`
for the AI/catalogue design and `docs/production_readiness.md` for the
live-testing fix pass this replaced the older component-first flow
with.

1. **App launch — authentication gate.** Once Firebase is configured
   for a build, an unauthenticated caller cannot reach the dashboard,
   create an inspection, physically inspect a property, or view a
   report — see "Authentication" below. Local-only/demo builds (no
   Firebase project configured) have no gate to enforce and work
   fully offline, unauthenticated, exactly as before.
2. **Inspector chooses a property type**: High Rise or Landed.
   ProDefact shows the default inspection areas for that property type
   (Entrance/Foyer, Kitchen, Living Room, Master Bathroom, etc. — see
   `lib/features/home_inspection/config/home_inspection_config.dart`).
   This step, and the next, only ever edit an **in-memory draft**
   (`NewInspectionDraftNotifier`) — nothing is persisted and nothing
   appears on the dashboard yet.
3. **Inspector configures areas**: include/exclude, rename, add a
   custom area (with a "contains plumbing" flag), edit, or remove.
   Only tapping **"Start Inspection"** turns the draft into a real,
   persisted, dashboard-visible inspection — backing out at any point
   before that discards the draft with nothing left behind.
4. **Physical inspection begins.** Areas flagged as plumbing areas are
   ordered first, since leakage/ponding tests need time to run while
   the inspector covers other areas.
5. **Inspector inspects each area — camera-first.** The area screen's
   primary, most prominent action is **"Take Defect Photo"**. There is
   no element/component picker to work through first:

   > Area → Take Photo → Preview Photo → optional short side note
   > (e.g. "Water leaking when turned on") → **Save Finding**.

   Saving persists the finding locally immediately (offline-first —
   no network or Firebase project required) and queues it for AI
   classification in the background. The inspector can immediately
   take the next photo without waiting — AI never blocks physical
   inspection, and capturing/previewing a photo alone (before Save)
   never triggers AI at all.
6. **AI classifies each saved finding progressively**, in the
   background, as soon as it's saved — never batched until the whole
   inspection is done, and never gated on physical inspection
   completion. For each finding, AI selects one entry (main element,
   component, defect) from ProDefact's **controlled defect catalogue**
   (`DefectCatalogue`) using the finding's area, the inspector's note,
   and its photo(s) — never inventing a classification outside that
   catalogue. A finding's per-finding AI status (`AiFindingStatus`:
   `notQueued` → `queued` → `uploading` → `analyzing` → `completed` /
   `needsReview` / `failed`) is visible on the area screen and rolled
   up into a real, count-based progress indicator on the dashboard
   card ("AI analysing · 12 of 19 findings · 63%").
7. **Steps 5–6 repeat** until every applicable area is finished. The
   inspector can mark an area physically complete independently of
   whether AI has finished analysing its findings yet — physical
   progress, AI processing progress, and inspector review progress are
   three separate, independently-tracked axes.
8. **AI is advisory only.** For every classification, the inspector
   reviews it in the AI Review screen and can:
   - **Accept** — approve the AI's own suggested catalogue entry as-is.
   - **Change** — pick a different entry via a searchable catalogue
     picker (never free-text — the inspector always selects from the
     controlled catalogue, never types a technical defect name).
   - **Reject / mark unresolved** — leave no final classification for
     now; can still be resolved later via Change.
   A finding AI could not confidently classify (`needsReview`, no
   catalogue entry) always requires the inspector to classify it
   manually via the same picker.
9. **Both the original AI classification and the inspector's final
   decision are preserved** — the original is never overwritten by
   review, and survives an app restart — for later audit/evaluation.
10. **Report readiness** requires all three axes settled: every
    included area physically complete, no finding still mid-AI-
    processing, and no AI suggestion left pending review. Once
    generated, the PDF report is grouped by area and uses only the
    inspector's **final, approved** classification and the catalogue's
    controlled corrective action — never a raw/unapproved AI value.

## Authentication

See `docs/production_readiness.md` ("Authentication hard gate") for
the full design: the router redirects an unauthenticated caller to
Sign In before any gated screen (`/home-inspection/*`) ever builds,
whenever Firebase is configured; a legitimate, previously-persisted
Firebase session restores automatically and is not affected. There is
no anonymous/guest authentication anywhere in the app.

## Where this lives in code

- Domain shapes: `Section`, `Finding` (camera-first — no forced
  element/component), `AiFindingStatus`, `AiSuggestion` (catalogue-
  based), `DefectCatalogue`, `Report` — all in `lib/core/inspection/`.
- The camera-first capture flow: `AreaInspectionScreen`
  (`lib/features/home_inspection/presentation/screens/`).
- The progressive AI queue and inspector review actions:
  `ActiveInspectionSession` (`lib/features/home_inspection/providers/
  active_session_providers.dart`).
- The controlled defect catalogue: `tool/generate_defect_catalogue.py`
  (source of truth) generates
  `lib/core/inspection/entities/defect_catalogue_data.dart` and
  `functions/src/ai/defect_catalogue_data.ts` — see
  `docs/ai_provider_architecture.md`.
