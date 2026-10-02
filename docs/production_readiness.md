# Production Hardening (Phase 8)

Phase 8 hardens the existing Home Inspection flow (Phases 1–7) for pilot
use. It does not add new product scope — no new industries, no redesign
of the inspection flow. This document covers the reliability, security,
and operational behavior added or confirmed this phase, plus what still
requires manual, external configuration before a real pilot.

## Live-testing fix pass (Auth, New Inspection flow, custom areas, UI overflow)

A round of hands-on testing surfaced four issues, fixed in this pass —
none required weakening or removing an existing test.

**Auth error messaging.** "The supplied auth credential is malformed or
expired" persisting after a successful password reset was traced to
Firebase's own intentional anti-enumeration behavior: Firebase merges
`invalid-credential`, `wrong-password`, and `user-not-found` into the
same error code so an attacker can't learn which part of a login
attempt was wrong. This was a messaging problem, not an auth-state bug
— `friendlyMessageForAuthError` (`lib/data/remote/firebase_auth_service.dart`)
now maps every credential-related code to one clear, honest message
("The email or password you entered is incorrect.") instead of
surfacing Firebase's literal, confusing wording. Separately, the
"already authenticated on a fresh install" report was confirmed (by
exhaustive grep — no anonymous/guest-auth code exists anywhere in the
app) to be expected iOS Keychain session persistence across a reinstall,
not silent/fake authentication; this is standard platform behavior, not
a defect. See `test/data/firebase_auth_error_mapping_test.dart`.

**New Inspection phantom-inspection fix.** Selecting a property type
used to call `startNew()` immediately — creating and persisting a real,
dashboard-visible inspection before the inspector had configured
anything or confirmed they wanted to proceed. Backing out at that point
left a phantom, half-configured inspection behind. The flow now runs
entirely through a separate, ephemeral, non-persisted
`NewInspectionDraftNotifier` (`lib/features/home_inspection/providers/new_inspection_draft_providers.dart`):
property type selection and area configuration only edit an in-memory
draft, and the *only* place an inspection is actually created is the
explicit "Start Inspection" button
(`_StartInspectionButton`,`area_configuration_screen.dart`), which is
guarded against a double-tap starting two sessions. Backing out at any
point before that simply discards the draft — nothing is ever written
to the database. See `test/area_configuration_screen_test.dart` and
`test/inspection_sessions_screen_test.dart` for the regression coverage
(select a property type then back out; configure areas then back out;
reopen and resume a draft; repeated taps on Start Inspection; no
duplicate inspections created).

**Custom area plumbing metadata.** Custom areas previously had no way
to mark "contains plumbing" / "inspect first" — only the built-in
default areas carried that metadata. `Section.copyWith` gained an
`isPlumbing` parameter, `HomeInspectionConfig.customSection` accepts
`isPlumbing`, and the area configuration screen's single add/edit
dialog (`_AreaEditDialog`) now exposes a "Contains plumbing" switch for
both new custom areas and edits to any existing area (built-in or
custom) — using Home Inspection terminology throughout ("area",
"plumbing", "inspect first"), not generic asset-management language. A
plumbing custom area participates in plumbing-first ordering exactly
like a built-in one, since it's the same `Section.isPlumbing` flag the
rest of the domain already reads.

**Area configuration overflow fix.** The "Plumbing area — inspect
first" pill was colliding with/overflowing past the edit/delete icon
buttons on narrow phones (a `RenderFlex` overflow inside the old
`ListTile`-based card). `_AreaCard` was restructured from `ListTile` to
an explicit `Row(Switch, Expanded(Column(name, pill)), edit, delete)` —
the `Expanded` guarantees the name/pill column always yields space to
the action buttons rather than fighting them for it, the area name gets
`maxLines: 2` + ellipsis for long custom names, and the pill itself
(`StatusPill`, `lib/app/theme/widgets/status_pill.dart`) now wraps its
label in `Flexible` + `TextOverflow.ellipsis` — a global fix, since
every other screen's status/sync pills share the same widget and were
equally at risk of the same overflow on a narrow device.

## Camera-first rewrite (product pivot)

The component-first physical inspection flow (Area → choose element →
choose component → manually add finding → photo) has been replaced
with a camera-first flow (Area → Take Photo → optional note → Save;
AI classifies against a controlled catalogue afterward) — see
`docs/home_inspection_workflow.md` for the full flow and
`docs/ai_review.md`/`docs/ai_provider_architecture.md` for the AI
model. This section covers the migration/compatibility impact only.

**Drift schema v6** (`lib/data/local/database.dart`): additive only,
consistent with the app's existing "never drop/recreate" migration
policy —

- `FindingRows.aiStatus` (new column, defaults to `notQueued`).
- `AiSuggestionRows` gained `suggestedCatalogueEntryId`,
  `suggestedConfidence`, `suggestedShortReason`,
  `suggestedCandidateEntryIds`, `finalCatalogueEntryId` (all nullable).
- A finding that already had an `AiSuggestion` from the old batch
  workflow is backfilled to `aiStatus = 'completed'` in the same
  migration, so its existing progress isn't misreported as never
  having been analyzed.
- `FindingRows.elementId` is **unchanged at the SQL level** — still a
  real, non-empty NOT NULL column for a legacy finding. A camera-first
  finding stores `''` (never SQL `NULL`) there instead, translated to
  Dart `null` by `DriftInspectionRepository` — deliberately avoiding an
  `ALTER TABLE` constraint change, which SQLite doesn't support without
  a full table rebuild. Zero schema risk to the column every legacy
  finding already depends on.
- **A genuine migration bug was caught and fixed while implementing
  this**: `migrator.createTable(aiSuggestionRows)` (run once, at schema
  v3) always builds the table from the table class's *current* Dart
  definition — meaning a device that jumps straight from schema v1/v2
  to v6 (skipping v3-v5 entirely, i.e. hadn't opened the app in a long
  time) would have the v6 columns already present the moment
  `createTable` ran, and the later `if (from < 6)` block's
  `addColumn` calls for those same columns would then fail with a
  duplicate-column SQL error. Fixed by only running those specific
  `addColumn` calls when `from >= 3` (the table already existed before
  this migration run) — see `test/data/database_migration_test.dart`
  for the regression test that exercises exactly this path (v1 and v5
  upgrade scenarios are both covered directly).

**Legacy findings** (schema v5 and earlier, with a real `elementId`)
continue to work, render, and report correctly — `report_model_builder.dart`
branches on `finding.elementId == null` to decide whether to resolve
display text from the controlled catalogue (camera-first) or from the
finding's own recorded element/component and a legacy suggestion's
preserved free-text fields (`legacyFinalElementId`, etc. — never
written by new code, only ever read for old data). See
`test/core/report/report_model_builder_test.dart` for both paths.

**UI**: the old `ElementInspectionScreen`/`finding_dialog.dart` (choose
element → choose component → add finding) are removed — nothing routes
to them anymore. `AreaInspectionScreen` was rebuilt around "Take Defect
Photo" as the primary action; see `docs/home_inspection_workflow.md`.

## Authentication hard gate (product pivot)

Authentication changed from *fully optional* (any screen reachable
signed out, "guest" sessions allowed) to a **hard gate**, whenever
Firebase is actually configured for a build: `buildAppRouter`'s
`redirect` callback (`lib/app/router/app_router.dart`) sends an
unauthenticated caller to `SignInScreen` before any route under
`/home-inspection/*` (dashboard, new inspection, physical inspection,
AI review, report) ever builds, and bounces a signed-in caller away
from `SignInScreen` back to the dashboard. `GoRouterRefreshStream`
(`lib/app/router/go_router_refresh_stream.dart`) re-evaluates this
redirect on every auth state change, not just on navigation, so a
sign-out that happens while a gated screen is already open is caught
immediately.

**This does not apply in local-only/demo builds** (`firebaseReadyProvider`
false — no Firebase project configured at all): there is no backend to
authenticate against, so the existing fully-offline, no-account
behavior documented under "Offline-first guarantees" below is
unaffected. This is the only way "hard auth gate" and "physical
inspection must remain usable even if Firebase is unavailable" are both
true at once: the gate requires *being authenticated*, not *being
online* — a legitimately signed-in inspector's session restores from
the platform's own secure storage and works fully offline exactly as
before; the gate only ever blocks a genuinely never-authenticated (or
explicitly signed-out) caller.

A `resetPassword` method was added to `AuthService` (previously
missing entirely) with a "Forgot password?" entry point on
`SignInScreen` — closing a real gap where password-reset errors had no
handling at all before this pass. See
`test/features/auth_gate_test.dart` for the redirect behavior (gated
when Firebase is configured, un-gated in local-only mode, bounce-back
from Sign In when already authenticated).

## Offline-first guarantees

The local Drift database (`AppDatabase`, `lib/data/local/database.dart`)
is the single durable source of truth. Every screen and every workflow
step — property selection, area configuration, physical inspection,
evidence capture, AI review, PDF report generation and sharing — works
completely offline, with no network call and no Firebase project
required. `test/data/firebase_optional_test.dart` exercises the entire
flow start-to-finish with `firebaseReadyProvider` left at its default
`false` value to prove this directly, and
`test/architecture/repository_boundary_test.dart` prevents a Firebase
(or Drift, or a concrete AI implementation) type from leaking outside
`lib/data/` in the first place, so nothing outside that layer can ever
accidentally make a workflow step *require* one of these dependencies.

## Durable write safety

`ActiveInspectionSession` (`lib/features/home_inspection/providers/active_session_providers.dart`)
mirrors the durable database in memory so the UI reads/writes
synchronously without blocking on disk I/O for every keystroke or tap.
Every mutation (area configuration, section status, finding create/
edit/delete, evidence attach/remove, AI review decisions, report
metadata) follows the same pattern via a private `_persist` helper:

1. Apply the change to in-memory `state` optimistically (so the UI
   updates immediately).
2. Await the actual database write.
3. **On success**: clear any previously-surfaced write error.
4. **On failure**: if nothing else has changed `state` since step 1 (a
   later, unrelated edit didn't arrive while this write was in flight),
   roll `state` back to what it was *before* the optimistic update, and
   set a user-facing message on `activeSessionErrorProvider`.

This means the UI can never be left showing a change that was never
actually saved — a failed write is always either rolled back or (if
superseded by later, successful edits) simply no longer relevant.
`markPhysicalInspectionComplete`, `startAiAnalysis`, `generateReport`,
and `syncNow` follow the same success/failure discipline directly
(they're already `Future`-returning, result-typed operations).
`startNew`/`resume` now return `bool` (previously `void`) so their two
UI call sites (`PropertyTypeSelectionScreen`, `InspectionSessionsScreen`)
show an error and stay on the current screen instead of navigating
forward on a failed session creation/load.

Tested in `test/features/durability_test.dart` using a
`FaultInjectingRepository` test double (`test/support/`) that can be
told to throw on one specific method call, without needing to actually
break the filesystem.

**Known limitation**: the rollback compares by object identity — if a
write fails and, in the same tick, something else already replaced
`state` with a different value, the failure is logged/surfaced but no
rollback happens (there's nothing stale left to roll back). This is
intentional: local SQLite writes are fast and essentially never fail in
practice (the realistic failure modes are disk-full or a permission
error), so this window is narrow, and never rolling back a *newer*,
successful edit was judged more important than perfect rollback
semantics for a failure this rare.

## Concurrency

Three coordinators guard against a double-tap starting two overlapping
runs of the same expensive, non-idempotent operation for the same
session, in addition to each already being logically idempotent/safe to
retry sequentially:

- `DefaultAiClassificationCoordinator.classifyFinding` — an in-memory
  `Set<String> _inFlight` (keyed by `sessionId/findingId`) rejects a
  second concurrent classification call for the same finding (returns
  `alreadyInFlight`). Without this, two concurrent calls could both
  read the finding's pre-classification `aiStatus` before either had
  durably persisted a suggestion, both call the AI backend, and
  duplicate the suggestion. Note this is scoped per *finding*, not per
  *session* — progressive AI means many findings across many areas can
  legitimately be classifying concurrently; only the same finding
  twice at once is guarded against.
- `DefaultReportCoordinator.generateReport` — the same pattern; without
  it, two concurrent calls (same day → same predictable filename) could
  race writing the same file path.
- `DefaultSyncCoordinator.syncSession` — the same pattern, for a
  double-tap of "Sync now".

`ActiveInspectionSession` also holds its own `_classifyingFindingIds`/
`_isGeneratingReport`/`_isSyncing` guards as a second layer, so a rapid
double-trigger at the UI level is rejected even before reaching the
coordinator. Verified with genuinely concurrent (`Future.wait`, not
sequential) calls in `test/data/concurrency_test.dart`, using fakes with
an artificial delay so the race window is real rather than incidental.

## Session deletion

New this phase: `InspectionRepository.deleteSession` (implemented by
`DriftInspectionRepository.deleteSession`) deletes the session row;
every child row (sections, findings, evidence metadata, AI suggestions,
report metadata) cascades via the FK `ON DELETE CASCADE` already
declared on each table. `ActiveInspectionSession.deleteSession` wraps
this: it loads the session first to collect every evidence file path
and the report file path, deletes the database row, then best-effort
deletes each file via `EvidenceFileStore`/`ReportFileStore` (a failed
file delete is logged and otherwise ignored — it never blocks or
reverts the database deletion). If the deleted session was the active
one, the active session is cleared.

UI: a "Delete inspection" icon per row on `InspectionSessionsScreen`,
behind a confirmation dialog ("This permanently deletes ... This cannot
be undone.").

**Limitation — local-only**: this phase does not delete previously
synced data from Firestore/Storage. `CloudInspectionRepository` already
exposes `deleteFinding`/`deleteEvidence` (used nowhere yet — sync is
currently push/create/update-only, never push-delete), but a full
recursive delete of a session's Firestore subcollections and Storage
folder was judged out of scope for this phase. If a session was synced
before being deleted locally, its cloud copy remains until either a
future phase adds cloud deletion or someone removes it manually via the
Firebase console. This is a deliberate, documented scope cut — not an
oversight.

Tested in `test/data/session_deletion_test.dart`: cascade at the
database level, no-op on a missing session, evidence-file cleanup on
single-evidence removal, evidence-file cleanup on finding removal, and
full evidence+report file cleanup on whole-session deletion.

## Local file lifecycle

Two file-cleanup points that previously left orphan files now clean up
via a shared `EvidenceFileStore` abstraction
(`LocalEvidenceFileStore`/`FakeEvidenceFileStore`):

- Removing one piece of evidence deletes its file.
- Removing a finding deletes every evidence file it had attached.
- Deleting a whole session deletes every evidence file across every
  finding, plus its generated report file.
- Regenerating a report deletes the previous report file when the new
  one has a different path (unchanged from Phase 7).

A missing/already-deleted file is never an error anywhere in this
chain — `LocalEvidenceFileStore.deleteEvidenceFile` checks existence
before deleting and swallows any I/O failure (logged, not thrown).

## Error handling

Every failure-prone boundary now has explicit, non-silent handling:

- **Database writes/reads**: `_persist`'s rollback-and-surface pattern
  above; `startNew`/`resume` catch and report instead of throwing past
  their `Future`.
- **Image capture/import**: `ImagePickerEvidenceCaptureService` wraps
  both the picker call and the file-copy-into-app-storage step in
  try/catch, raising a typed `EvidenceCaptureException` with a
  human-readable message (never a raw `PlatformException`).
  `ActiveInspectionSession.addEvidence` catches this (and anything else)
  and surfaces one fixed, generic message via
  `activeSessionErrorProvider` — the underlying exception detail is
  logged (`AppLogger`), never shown in the UI.
- **File copy/write/delete**: `LocalEvidenceFileStore` and
  `LocalReportFileStore` (Phase 7) both catch and log; a report render
  failure is caught by `DefaultReportCoordinator` and returned as
  `ReportGenerationResult.failure`.
- **Evidence preview**: already handled since Phase 4/6 —
  `_EvidenceThumbnail` checks `file.existsSync()` and shows a
  "broken image" placeholder instead of throwing; `PdfReportRenderer`
  does the same per-photo (Phase 7).
- **Firebase Auth**: `FirebaseAuthService` already converts
  `FirebaseAuthException` into a typed `AuthException` with a friendly
  message (Phase 5, unchanged).
- **Firestore/Storage sync**: `DefaultSyncCoordinator` already wraps
  the whole push in try/catch, marking the session `pendingUpdate`
  rather than losing local data (Phase 5, unchanged; now also
  guarded against concurrent double-sync, see "Concurrency" above).
- **AI coordinator**: already wraps the backend call in try/catch,
  marking `aiReviewState: failed` without touching existing data
  (Phase 6, unchanged; now also guarded against concurrent double-run).
- **Report generation / PDF write / PDF share**: generation failures
  return `ReportGenerationResult.failure` (Phase 7, unchanged);
  `ActiveInspectionSession.shareReport` now catches a share failure and
  surfaces it via `activeSessionErrorProvider` instead of letting it
  propagate uncaught.
- **Navigation during async operations**: every screen that awaits a
  provider call before navigating checks `context.mounted` first
  (already established pattern from earlier phases; confirmed intact
  for the two changed call sites, `_selectPropertyType` and `_resume`).

No user-facing message anywhere includes a raw stack trace or a raw
exception's `toString()` — `AppLogger` (below) carries that detail for
developers only.

## Logging

`AppLogger` (`lib/core/logging/app_logger.dart`) is a minimal, dependency-free
static logging seam: `debug`/`info`/`warning`/`error`, each prefixed
`[ProDefact][LEVEL]`. It exists so development diagnostics are visibly
distinct from user-facing error messages, and so error logging is
consistent across the app instead of ad hoc `print`/`debugPrint` calls
scattered through it. It never logs a full evidence file path, a secret,
or an auth token — call sites pass short, generic descriptions, and
`AppLogger.error` logs an exception's *type name*, not its full message,
specifically so a `FirebaseAuthException` (which can embed an email) or
similar can't leak PII into logs by accident. Stack traces are only
printed in non-release builds.

## Database hardening

Schema is now at **v5**. History (see the doc comment on `AppDatabase`
in `lib/data/local/database.dart` for the authoritative, up-to-date
version):

- v1 (Phase 4): sessions, sections, findings, evidence.
- v2 (Phase 5): `ownerUid` on sessions, `storagePath` on evidence.
- v3 (Phase 6): `aiReviewState` on sessions, `AiSuggestionRows` table.
- v4 (Phase 7): `ReportRows` table.
- v5 (Phase 8): indexes on the foreign-key columns SQLite doesn't index
  automatically — `finding_rows.session_id`, `evidence_rows.finding_id`,
  `ai_suggestion_rows.session_id`, `ai_suggestion_rows.finding_id`.
  Index-only; no table/column changes, so nothing about this migration
  can affect existing data, and it runs identically on `onCreate` (fresh
  install) and `onUpgrade` (existing install).

Every migration step so far is strictly additive (`addColumn`/
`createTable`/an index) — there is no destructive upgrade path (no
`DROP TABLE`, no data-losing `ALTER`) anywhere in `MigrationStrategy`.

**Cascade/orphan-prevention review**: every child table's FK to
`InspectionSessionRows` (or, for evidence/AI suggestions, transitively
via `FindingRows`) declares `onDelete: KeyAction.cascade`. Deleting a
session row is therefore sufficient on its own to remove every section,
finding, evidence-metadata row, AI suggestion, and report-metadata row
that referenced it — confirmed directly in
`test/data/session_deletion_test.dart`. `FindingRows.sectionId` is a
plain (non-FK) reference into the session's own `elementsJson`-embedded
section template rather than `SectionRows`, which is intentional
(sections are a per-session configuration blob, not independently
addressable rows) and unaffected by this phase.

**Migration tests**: `test/data/database_migration_test.dart` builds
real on-disk SQLite files by hand at schema v1 and v2 (raw `CREATE
TABLE`/`INSERT` statements mirroring exactly what those versions' Dart
table definitions produced, plus `PRAGMA user_version`), then opens
them with the real `AppDatabase` (v5) and exercises the actual
`MigrationStrategy.onUpgrade` — not a re-implementation of it. It
asserts: pre-existing data survives untouched, new columns appear with
their defaults, new tables exist and are queryable, and the new v5
indexes exist (checked via `sqlite_master`, since Drift has no typed API
for "does this index exist"). A third test confirms a fresh install
(`onCreate`) also gets the v5 indexes.

## Firebase hardening (still fully optional)

- **Auth state handling**: `authStateProvider` restores sign-in state
  on app restart via the underlying stream (Phase 5, unchanged); signing
  out (or an expired/invalidated session) never touches local data —
  confirmed directly in `test/data/firebase_optional_test.dart`
  ("signing out ... never deletes or clears the local inspection data").
- **Ownership checks**: unchanged from Phase 5 — a session already
  owned by a different signed-in user is never synced
  (`SyncOutcome.unauthenticated`); an unclaimed guest session is claimed
  by whoever first resumes or syncs it.
- **Sync status / retries**: unchanged from Phase 5 — a failed sync
  marks `pendingUpdate` and is safely retryable (already tested in
  `test/data/sync_coordinator_test.dart`); now also can't race itself
  (see "Concurrency").
- **Stable IDs / duplicate writes**: unchanged — every push is keyed by
  the same stable local id, so repeated syncs never create duplicate
  remote records (`test/data/sync_coordinator_test.dart`, "repeated sync
  does not create duplicate logical records").
- **Storage paths / Firestore schema**: unchanged (see `docs/firebase.md`).
- **Local-only sessions / signed-out behavior**: every workflow step
  works fully signed-out; sync/share of cloud state is the only thing
  gated on being signed in, and that gate fails closed (never silently
  no-ops as "success").
- **No bidirectional overwrite**: unchanged and deliberately so — sync
  remains local → cloud only.

## Security

Confirmed by this phase's audit (existing guarantees) plus what's new:

- **No provider API keys in Flutter, ever**:
  `test/architecture/repository_boundary_test.dart`'s secret scan
  (OpenAI/Google-API-key-shaped strings, `*_API_KEY` assignments)
  passes; the only "keys" anywhere in `lib/` are the placeholder
  `REPLACE_WITH_YOUR_...` strings in `lib/firebase_options.dart`, which
  are not secrets (Firebase's client config is not sensitive — see
  Firebase's own docs) and are clearly labeled as placeholders in a
  comment at the top of that file.
- **No secrets committed**: confirmed by inspection; nothing under
  version control contains a real credential.
- **Firestore/Storage rules deny cross-user access**: unchanged from
  Phase 5 (`firestore.rules`/`storage.rules`, `docs/firebase.md`).
- **Filenames/paths are sanitized**: `buildReportFileName` (Phase 7)
  strips everything but `[A-Za-z0-9_-]` from the session id component,
  so a session id crafted to look like a path-traversal attempt
  (`../../etc/passwd`) or containing shell-metacharacters/control
  characters/null bytes can never produce a filename containing a path
  separator, `..`, or an injection-shaped character — see
  `test/security_test.dart`. Evidence filenames are never
  user-influenced at all (built from an internal counter + timestamp),
  so there's no user input to sanitize there in the first place.
- **User input cannot escape app-managed directories**: evidence files
  are written only under `<appDocuments>/evidence/<findingId>/`, and
  report files only under `<appDocuments>/reports/` — both fixed
  prefixes computed by the app, never user-supplied.
- **No unsafe dynamic file paths**: confirmed by inspection — every
  `File(...)`/directory path in `lib/data/` is built from app-generated
  ids and fixed prefixes, never directly from unsanitized user text.
- **AI requests exclude unnecessary account data**:
  `AiFindingClassificationRequest` (`lib/core/inspection/ai/`) has no
  `ownerUid`, `email`, or auth-token field at all — a structural
  guarantee, not just a convention — confirmed by capturing an actual
  request built during a full workflow run in `test/security_test.dart`.
- **Logs don't print secrets/tokens**: `AppLogger.error` logs an
  exception's type name rather than its full message (see "Logging"
  above), specifically to avoid a `FirebaseAuthException` or similar
  leaking an email/token into developer logs.
- **Production configuration placeholders are clearly distinguishable**:
  `lib/firebase_options.dart` opens with a large comment block
  explicitly stating it's a placeholder with no real credentials and
  the exact command (`flutterfire configure`) that replaces it.

### Re-audit for the camera-first/controlled-catalogue pass

Re-confirmed unchanged and still correct:

- `firestore.rules`/`storage.rules` — still scoped to
  `users/{uid}/...`, deny-by-default elsewhere; no change was needed
  since evidence/finding paths didn't change shape.
- The `classifyFinding` callable (renamed from `analyzeInspection`,
  same security posture) still: requires `request.auth` before
  touching any provider; derives the evidence Storage path only from
  the verified caller's own `uid` plus the request's own ids, never
  from a client-supplied path; independently re-verifies ownership via
  Firestore before ever reading Storage. See
  `docs/ai_provider_architecture.md` ("Secure evidence delivery") and
  `functions/src/handle_classify_finding.test.ts` for the auth-gate and
  ownership tests.
- `DEEPSEEK_API_KEY` is still Secret-Manager-only, never logged, never
  in Flutter source — unchanged.
- New this pass: the router's authentication hard gate (see "Camera-
  first rewrite (product pivot)" above) — client-side navigation
  gating only, not a substitute for the server-side rules/callable auth
  checks above, which remain the actual trust boundary.
- New this pass: the controlled defect catalogue itself contains no
  user data and is committed as plain source (not a secret) — both
  copies (`defect_catalogue_data.dart`/`.ts`) are generated from
  `tool/generate_defect_catalogue.py`, a public, non-sensitive
  transcription of a published defect list.

## App Check

**Scaffolded, not enforced against a real project.** `firebase_app_check`
is now a dependency; `lib/data/appcheck/app_check_setup.dart` calls
`FirebaseAppCheck.instance.activate(...)` from `main.dart`, but only
after `Firebase.initializeApp` has already succeeded, and the whole call
is wrapped in try/catch — a failure here is logged and never blocks
startup. It selects the **debug provider** in debug builds (no real
credentials needed — Firebase generates a random per-install debug
token, printed to the console, that you register in the Firebase
console to allow that install through while iterating) and the
platform's real attestation (Play Integrity / App Attest) in release
builds.

**Manual steps still required** before App Check actually enforces
anything (impossible to do without a real, interactive Firebase
project — not fabricated here):

1. `flutterfire configure` against a real project (see
   `docs/firebase.md`).
2. Firebase console → App Check → register the app for each platform,
   choosing Play Integrity (Android) / App Attest or DeviceCheck (iOS).
3. For local development, run the debug build once, copy the debug
   token Firebase prints to the console, and add it under App Check →
   Apps → (your app) → Manage debug tokens.
4. Once ready, enforce App Check on Firestore/Storage/any callable
   functions from the App Check console page for each product.

## Crashlytics

**Scaffolded, not verified against a real project** (no real Firebase
project exists in this environment to send a crash to). `firebase_crashlytics`
is now a dependency; `lib/data/crash/crash_reporting.dart`'s
`initializeCrashReporting()` is called from `main.dart` only after
Firebase itself is ready, and:

- Wires `FlutterError.onError` to
  `FirebaseCrashlytics.instance.recordFlutterFatalError` (chaining to
  whatever handler was previously installed, so nothing already relying
  on `FlutterError.onError` — e.g. Flutter's own default red-screen
  reporting in debug — is silently dropped).
- Wires `PlatformDispatcher.instance.onError` to
  `FirebaseCrashlytics.instance.recordError(..., fatal: true)` for
  uncaught async/platform errors.
- Sets `setCrashlyticsCollectionEnabled(!kDebugMode)` — **disabled in
  debug builds** (so ordinary `flutter run`/`flutter test` sessions
  never appear in a real project's Crashlytics dashboard) and enabled in
  release builds.
- Never calls Crashlytics's own `.crash()` test method anywhere — no
  fake/test crash is ever sent, on startup or otherwise.
- The whole function is wrapped in try/catch; a failure to initialize
  Crashlytics is logged via `AppLogger` and never blocks startup.

**Manual steps still required**: `flutterfire configure` against a
real project; no other manual console step is required for Crashlytics
specifically beyond that (it's automatically available once Firebase is
configured for the project).

## Analytics

`AnalyticsService` (`lib/core/inspection/services/analytics_service.dart`)
is a closed, parameter-free interface — `logEvent(AnalyticsEvent event)`,
where `AnalyticsEvent` is a plain enum with exactly five values:
`inspectionStarted`, `inspectionCompleted`, `aiReviewStarted`,
`aiReviewCompleted`, `reportGenerated`. There is **no way to attach a
property to an event through this interface at all** — this is a
structural guarantee, not a convention, that a call site can never
accidentally attach a finding description, inspector note, image path,
AI raw output, or email address to an analytics event, confirmed in
`test/security_test.dart` ("analytics excludes sensitive content").

`analyticsServiceProvider` falls back to a no-op implementation when
Firebase isn't ready — Analytics is purely optional instrumentation, the
same as every other Firebase-backed feature. Every call site in
`ActiveInspectionSession` goes through a `_logAnalytics` helper that
also catches and swallows *any* failure (including a failure to
construct the underlying `FirebaseAnalyticsService` itself, which can
happen in a test/CI environment) — a broken or unavailable Analytics
backend can never interrupt or fail the workflow step it's attached to.

Events fire at: a new session is created (`inspectionStarted`); AI
analysis actually runs (not on a no-op re-tap) (`aiReviewStarted`);
every AI suggestion becomes resolved (`aiReviewCompleted`); and report
generation succeeds (`reportGenerated` + `inspectionCompleted` — the
practical "this inspection's workflow, end to end, is done" moment in
the app's current scope).

## AI security architecture (production-readiness)

The real, deployed architecture (superseding the earlier "[future]
gateway" placeholder this section originally described):

```
Flutter (AiInspectionService.classifyFinding)
  -> FirebaseAiInspectionService -> `classifyFinding` callable
       -> requires Firebase Authentication (unauthenticated -> rejected
          before any provider is ever invoked)
       -> validates the request (functions/src/ai/validation.ts)
       -> resolves evidence server-side, ownership-checked
          (functions/src/ai/evidence.ts)
       -> calls DeepSeek (deepseek-flash), validates its response
          against the controlled catalogue (functions/src/ai/gateway.ts)
  -> Flutter parses the typed AiFindingClassification
```

Full detail: `docs/ai_provider_architecture.md`.
`FakeAiInspectionService` is explicitly named and documented as
fake/demo (`lib/data/ai/fake_ai_inspection_service.dart`) — deterministic,
no network call, not production AI, used only when Firebase isn't
configured. No paid/provider API is ever called directly from Flutter,
and no provider secret (`DEEPSEEK_API_KEY`, Secret-Manager-only) exists
in the mobile codebase (see "Security" above) — swapping to a different
provider is an override of one provider (`aiInspectionServiceProvider`
server-side selection), never a rework of `ActiveInspectionSession`,
`AiClassificationCoordinator`, the Drift schema, sync, or any UI.

## Report hardening

Confirmed intact from Phase 7 (see `docs/report.md` for full detail),
re-audited this phase:

- Eligibility gating (physical inspection complete AND no finding
  still mid-AI-processing AND every AI suggestion resolved — see
  `docs/ai_review.md`, "Report readiness") is enforced in
  `DefaultReportCoordinator`, not just by hiding a button.
- A file-write failure (or a render failure) is caught and returned as
  `ReportGenerationResult.failure` — inspection data is untouched.
- A missing/deleted evidence photo is caught per-image in
  `PdfReportRenderer` and rendered as a "Photo unavailable" placeholder
  rather than failing the whole report.
- Staleness (`Report.isStaleRelativeTo`) is still surfaced as a banner
  rather than silently presenting an outdated report as current.
- Regeneration still replaces (not accumulates) the report row and
  deletes the superseded file — now also guarded against a concurrent
  double-regenerate (see "Concurrency").
- Filenames are still deterministic and sanitized (re-verified against
  path-traversal/control-character input this phase — see "Security").
- The report only ever contains `AiSuggestion.final*` values — the
  original AI `suggested*` output is never rendered, so no internal AI
  metadata (the AI's original, possibly-overridden suggestion) can ever
  leak into a homeowner-facing PDF by mistake — this was already
  covered by Phase 7's `report_model_builder_test.dart` and reconfirmed
  unchanged this phase.

## Permissions

Audited both platforms; **no changes were needed** — they were already
minimal:

- **iOS** (`ios/Runner/Info.plist`): `NSCameraUsageDescription` and
  `NSPhotoLibraryUsageDescription` only, each describing exactly why
  (attaching evidence photos). No location, microphone, contacts, or
  other permission is requested.
- **Android** (`android/app/src/main/AndroidManifest.xml`):
  `android.permission.CAMERA` only. No `READ_EXTERNAL_STORAGE`/
  `WRITE_EXTERNAL_STORAGE` — the gallery picker uses `image_picker`'s
  modern scoped-storage-friendly system photo picker, which needs no
  storage permission on current Android versions. A `<queries>` entry
  allows resolving the camera app intent on Android 11+; this is
  visibility, not a permission grant.
- **Permission denial**: `image_picker` surfaces a denied
  camera/library permission as a thrown platform exception, which
  `ImagePickerEvidenceCaptureService` now catches and converts to
  `EvidenceCaptureException`, which `ActiveInspectionSession.addEvidence`
  catches and surfaces as a friendly, generic message — never a crash,
  never a silently-ignored tap. Verified in `test/security_test.dart`
  ("permission denial handled gracefully").

## Accessibility

Existing baseline was already reasonable (every icon-only `IconButton`
in the app already carries a `tooltip`, which Flutter also exposes to
screen readers). This phase's pass added one concrete gap-fill:
evidence photo thumbnails (`_EvidenceThumbnail` in `finding_dialog.dart`)
now carry an explicit `Semantics(label: ..., image: true)` describing
either "Evidence photo" or "Evidence photo unavailable — the file is
missing", so a screen reader user gets a description of what's in each
thumbnail slot instead of silence. Confirmed elsewhere, unchanged: tap
targets use standard Material widgets (default ≥48dp), no
`textScaler` override anywhere (system text-scaling is respected), and
status indicators (sync icon, completion `Chip`) already pair color
with an icon/text label rather than relying on color alone.

## UX states

Reviewed against loading/empty/error/success/disabled/retry for the
screens touched this phase:

- `InspectionSessionsScreen`: loading (spinner), empty ("No saved
  inspections yet."), error (inline message from the summaries
  provider), success (list), and now a working delete action with
  confirmation + a success snackbar.
- `PropertyTypeSelectionScreen`/resume flow: a failed `startNew`/
  `resume` now shows a snackbar and stays on the current screen instead
  of silently doing nothing or navigating to a screen with no session.
- `ReportScreen` (Phase 7, unchanged): not-generated/generating/ready/
  failed states, each with visible feedback.
- Every mutating action in `ActiveInspectionSession` now has a
  consistent failure surface via `activeSessionErrorProvider` that any
  screen can watch; wiring a visible banner into every remaining screen
  (physical inspection queue, area configuration) is straightforward
  future work using the same provider but was not spread across every
  screen this phase to keep the change bounded — see "Known
  limitations".

## Performance

Reviewed the items in scope; the only change made was the v5 database
indexes (see "Database hardening") — `loadSession` looks up findings/
evidence/AI suggestions by exactly the columns now indexed, and an
inspection with many findings would otherwise force a full table scan
per lookup. No other change was made:

- Evidence images are already capped (`maxWidth: 2000, imageQuality: 90`
  in `image_picker`, Phase 4) — no unbounded full-resolution loads.
- PDF report generation already renders off the evidence file paths
  directly (no double-buffering all bytes in memory at once) and the
  `ReportScreen`'s "Generating..." state already disables re-entry
  during the (already backgrounded, non-UI-blocking) render.
- No obvious N+1 query pattern was found elsewhere — `loadSession`
  already batches its evidence lookup with a single `isIn(findingIds)`
  query rather than one query per finding (Phase 4, unchanged).
- Provider rebuild scope was not re-architected this phase — no
  measured jank was found, and speculative re-scoping without a
  measured problem would risk exactly the kind of premature
  over-engineering the brief asked to avoid.

## Firebase real-config readiness (manual steps for a real pilot)

Unchanged process from Phase 5 (`docs/firebase.md` has the full detail;
summarized here with the Phase 8 additions folded in):

1. `firebase login`, `dart pub global activate flutterfire_cli`,
   `flutterfire configure` — replaces the placeholders in
   `lib/firebase_options.dart` with a real project's values. No other
   code change is required.
2. Firebase console: enable **Authentication → Email/Password**,
   create a **Firestore** database, create a **Storage** bucket.
3. Deploy the committed security rules:
   `firebase deploy --only firestore:rules,storage:rules`.
4. **App Check** (new, optional): register the app per platform in the
   App Check console section; for local development, register the
   debug token the app prints to console on first run. See "App Check"
   above.
5. **Crashlytics** (new, optional): no additional console step beyond
   step 1 — it's available automatically once the project is
   configured. See "Crashlytics" above.
6. **Analytics** (new, optional): no additional console step beyond
   step 1.

No secret is ever committed by any of the above — `flutterfire
configure` writes only client-side configuration values, which Firebase
itself documents as non-sensitive.

## Known limitations (pilot-readiness caveats)

- **Firebase/AI are not "live" against a real pilot project** as
  delivered: no real Firebase project is configured in this repository
  (placeholders only), so `aiInspectionServiceProvider` resolves to
  `FakeAiInspectionService` (deterministic, no network) until
  `flutterfire configure` points it at a real project. The real,
  provider-neutral, multimodal (`deepseek-flash`), controlled-catalogue
  implementation itself exists and is deployed to `prodefact-82bac`
  (`FirebaseAiInspectionService` → `classifyFinding` callable → the
  DeepSeek gateway) — see `docs/ai_provider_architecture.md` — but it
  has not been exercised against a real signed-in user and a real
  synced photo in this environment; that is the manual E2E gap called
  out below.
- **The "waiting for connection" AI status does not detect genuine
  network loss directly** — there is no connectivity-monitoring plugin
  in this app. `isOnlineForAiProvider` is a proxy (true whenever
  Firebase isn't configured at all, or the inspector is signed in) —
  if a signed-in device is actually offline, a queued finding simply
  stays `queued` (safe: never lost, never duplicated) but the
  dashboard card may briefly still say "analysing" rather than
  "waiting for connection" until the next sync attempt fails. A future
  pass could add `connectivity_plus` for a more precise label.
- **Cloud deletion is not implemented** — deleting a session locally
  never deletes a previously-synced remote copy (see "Session
  deletion").
- **Sync never pushes deletes** — deleting a finding/evidence locally
  after it was already synced leaves the remote copy in place until a
  future full-session sync/cleanup story is built; `deleteFinding`/
  `deleteEvidence` exist on `CloudInspectionRepository` but are not yet
  wired into `DefaultSyncCoordinator`.
- **App Check/Crashlytics cannot be verified end-to-end** without a
  real Firebase project — the code path is real, guarded, and won't
  break local-only operation, but no crash has actually been observed
  arriving in a Crashlytics dashboard, and no request has actually been
  attested by App Check, in this environment.
- **Coverage is uneven** — core domain logic (coordinators, the report
  model builder, migrations, the AI catalogue/gateway) is heavily
  tested; UI screens beyond the ones a given pass specifically touched
  were not newly instrumented.
- **`activeSessionErrorProvider` is not yet wired into every screen** —
  it exists and is exercised by tests, and several screens/flows show
  it; wiring a consistent banner into every remaining screen is
  straightforward, additive follow-up work.
- **The searchable catalogue picker ("Change") has no fuzzy matching**
  — `DefectCatalogue.search` is a plain case-insensitive substring
  match across defect/component/main-element name. Sufficient for 222
  entries in practice, but a typo-tolerant search would be a nice-to-
  have follow-up.
- **No automated test drives the real DeepSeek API, a real device
  camera, or a real Cloud Storage upload** — every AI/evidence test
  uses a fake provider or hand-rolled fake Firestore/Storage client.
  This is a deliberate, standard testing boundary (never spend real
  money/quota in CI), but it means the manual E2E sequence below is not
  optional decoration — it is the only verification that the real,
  deployed integration actually works end-to-end.

## Pilot-readiness checklist

Use this before a real pilot inspection:

- [ ] Run `flutterfire configure` against a dedicated (not shared/test)
      Firebase project.
- [ ] Enable Email/Password auth; create Firestore + Storage; deploy
      `firestore.rules`/`storage.rules`.
- [ ] Decide whether App Check enforcement is required for the pilot;
      if so, register debug tokens for pilot devices and enable
      enforcement in the console.
- [ ] Confirm Crashlytics is receiving events from a real release build
      (Crashlytics collection is intentionally disabled in debug
      builds — test with a release/profile build instead).
- [ ] Decide on a real AI backend if AI-assisted review beyond the demo
      fake is required for the pilot (see `docs/ai_review.md`,
      "Production backend gateway design").
- [ ] Manually verify, on a real device: camera permission denial
      recovers gracefully; deleting an inspection actually removes its
      photos/report from the device's storage; a report survives being
      generated, shared, and regenerated after an edit.
- [ ] Confirm pilot inspectors understand: cloud data currently only
      ever grows (no delete-sync), and an unauthenticated device never
      sees the dashboard once Firebase is configured for this build.

### Manual E2E test sequence (required — not covered by automated tests)

None of this has been exercised on a real device/simulator against a
real Firebase project in this environment. Before treating any of the
features in this pass as pilot-ready, manually run through:

1. **Authentication hard gate.** Uninstall and reinstall the app (or
   use a fresh simulator) against a build with a real Firebase project
   configured. Confirm the app never shows the dashboard, New
   Inspection, or any inspection screen while signed out — only Sign
   In/Register. Register a new account, sign out, sign back in with
   the correct password (succeeds) and then with a deliberately wrong
   password (shows the clear "email or password is incorrect" message,
   not a raw Firebase code). Tap "Forgot password?", request a reset
   for a real test account, confirm the email arrives, and confirm
   signing in with the new password works and the old one no longer
   does. Confirm a legitimate prior session (don't sign out; just
   relaunch the app) restores automatically without being asked to
   sign in again.
2. **New Inspection — no phantom inspections.** From the dashboard,
   start New Inspection, pick a property type, then back out (device
   back button and the app bar back arrow) before touching the areas
   screen — confirm nothing appears on the dashboard. Repeat, this time
   configuring areas (toggle a couple off, rename one, add a custom
   plumbing area) and backing out before "Start Inspection" — confirm
   again nothing was created. Finally, go through the flow and actually
   tap "Start Inspection" once — confirm exactly one inspection appears,
   including the custom area and your include/exclude/rename choices.
3. **Camera-first capture, rapid succession.** Open an area and confirm
   "Take Defect Photo" is the single, prominent primary action — no
   element/component picker appears anywhere first. Take a photo,
   preview it, add a short note, tap "Save Finding" — confirm it
   appears in the findings list within the same screen almost
   immediately, with an AI status that starts at "waiting"/"analysing"
   without ever blocking you from immediately tapping "Take Defect
   Photo" again. Repeat several times in quick succession (take, save,
   take, save...) and confirm no duplicate findings and no UI stall.
   Add a second photo to an existing finding and confirm it re-queues
   AI (status returns to "analysing").
4. **Area configuration on a narrow phone.** On the smallest real/
   simulated device available, open area configuration and confirm the
   "Plumbing area — inspect first" pill never visually collides with or
   hides the edit/delete buttons, for both a short default area name
   and a long custom one. Confirm the photo preview sheet (photo + note
   + Save/Discard) is fully visible and usable without scrolling on the
   same small device.
5. **Physical vs. AI vs. review progress — independence.** Mark every
   area physically complete while at least one finding is still
   showing "AI analysing" or is unreviewed — confirm you can freely
   move between areas and the AI Review screen shows progress
   ("analysing · X of Y", "needs review") without letting you continue
   to the report yet. Confirm the dashboard card's AI progress line
   updates as findings finish, independent of physical-completion
   state.
6. **Real AI Vision review against the controlled catalogue.** With a
   real Firebase project and the deployed `classifyFinding` function
   (`DEEPSEEK_API_KEY` bound), sign in, complete an inspection with
   several photographed defects across different areas (include at
   least one genuinely unclear/ambiguous photo). Confirm: each result
   is one of the defined catalogue entries (never a made-up
   element/component/defect); the "needs review" cases occur for the
   ambiguous photo rather than a confident wrong guess; the review
   screen's wording is plain-language, not a technical paragraph;
   "Change" opens a searchable picker (never a free-text field) and
   choosing an entry updates the final value while leaving the original
   AI pick visible/preserved. Force-quit and reopen the app and confirm
   both the original AI classification and your reviewed final value
   are still present (not overwritten) for at least one accepted and
   one changed suggestion.
7. **PDF report structure.** Generate the report and confirm: findings
   are grouped by area matching the areas you actually configured;
   numbering runs continuously across the whole report (not reset per
   area); each finding shows an actual evidence photo (not a
   placeholder); the corrective action text matches the catalogue,
   not any AI free text; a rejected/unresolved finding (if you left one
   that way) renders as "Unresolved" rather than blank or crashing;
   pages break cleanly with 20+ findings.
8. **AI failure paths.** With airplane mode on, save a new camera-first
   finding and confirm its status clearly reads as waiting/unable to
   analyse right now (not a crash, not silently stuck as "analysing"
   forever) and that physical inspection data is completely unaffected;
   confirm it actually gets classified once connectivity returns
   without any extra action from the inspector.
9. **Android + iOS parity.** Repeat at least steps 1, 3, and 6 on both
   an Android device/emulator and an iOS device/simulator.

## Product flow consolidation pass

This pass turned the existing, already-mature building blocks (Phases
1-8 above) into one coherent lifecycle with a clear beginning, middle,
and end — see `docs/home_inspection_product_flow.md` for the canonical,
full description. It added no new industries and did not touch the AI/
security/catalogue architecture (re-audited and found already correct:
catalogue counts exactly 11/34/222, auth-gated evidence resolution,
Secret-Manager-only provider key, deny-by-default Firestore/Storage
rules — no functions code changed this pass).

**Removed**: the vestigial `HomeShellScreen` splash screen (zero data,
one pointless extra tap before the real dashboard) — the dashboard
(`InspectionSessionsScreen`) is now the app's initial route.

**Added**:

- **Property Details** (New Inspection step 2) and **Review Setup**
  (step 4, the sole place `startInspection()` is now called) screens —
  see `docs/home_inspection_product_flow.md`.
- **Profile screen** (on-device company/inspector-name prefill data,
  sign out) — reached from the dashboard app bar.
- Dashboard **"Needs attention"** section, **search**, and **status
  filters** — all backed by real, already-computed counts, never
  fabricated.
- **"Add another photo"** wired to the existing (previously unused)
  `ActiveInspectionSession.addEvidence` multi-photo capability.
- **"Classify Manually"** on a `failed` AI finding (new
  `ActiveInspectionSession.manuallyClassifyFinding`), alongside the
  existing "Retry" — an inspector is never blocked by an AI failure
  with no suggestion to fall back on.
- AI Review grouped by area, with a photo thumbnail per card and
  confidence/reason collapsed behind "AI details".
- Report Readiness now shows the three progress axes (physical/AI/
  review) plus an unresolved-findings count, not just aggregate stats.
- **Report versioning** (`Report.version`) — regenerating after
  inspection data changed is now visibly "v2", not a silent overwrite.

**Database**: schema v6 -> v7, strictly additive (nine nullable
property-details columns + `inspectionDate` on sessions, `version` on
reports, a new single-row `UserProfileRows` table) — see the version
history in `lib/data/local/database.dart` and
`test/data/database_migration_test.dart` for the v5->v7/v6->v7 upgrade
coverage.

**Tests**: net +9 test cases across existing suites (multi-photo UI,
manual classification x2, property details validation x2, dashboard
search/filter, report-model property-details mapping x2, migration
coverage for v7) plus every existing test updated for the two extra
setup screens now in the New Inspection navigation stack. Full suite:
221 passing, 0 failing (`flutter test`) as of this pass; Functions
unaffected (57 passing, unchanged).

**Known limitations / P1 backlog carried forward** (see
`docs/home_inspection_product_flow.md` for the full list and reasoning
for each): reference photos (no data model change made), area/
inspection notes (no schema field exists yet), real connectivity
detection (`isOnlineForAiProvider` is still a signed-in-status proxy,
not `connectivity_plus`), cloud/push-delete sync (still local-delete-
only, per the existing documented scope cut above), per-area AI/review
counts on the Inspection Overview list, an editable pre-generate report
metadata confirmation step, and a historical (v1/v2/v3) report PDF
archive (only the current version's file is kept on disk; the version
*number* is durable, the file history isn't).

### Manual E2E additions for this pass

Add these to the sequence above before treating the consolidated flow
as pilot-ready — none of this has been exercised on a real device/
simulator against a real Firebase project in this environment:

1. **New Inspection through Property Details and Review Setup.** Start
   a new inspection, pick a property type, and confirm "Continue" on
   Property Details is blocked with a visible "Required" error until a
   title is entered. Fill in title, address, unit, and client name,
   continue to area configuration, configure areas, then confirm Review
   Setup shows everything you entered correctly before tapping "Start
   Inspection" — and that the dashboard card afterward shows your title
   and unit, not the raw property type.
2. **Multi-photo in the field.** Save a finding, then tap "Add another
   photo" on its card and confirm a second photo attaches and the
   finding's AI status returns to analysing (re-queued) rather than
   staying at its previous terminal state.
3. **AI failure with no fallback but Classify Manually.** Force an AI
   classification to fail (e.g. simulate a provider outage), confirm
   both "Retry" and "Classify Manually" appear, and that "Classify
   Manually" opens the same searchable catalogue picker used elsewhere
   and correctly marks the finding reviewed/completed.
4. **Dashboard search/filter/Needs attention.** With several
   inspections in different states, confirm search narrows by title/
   unit/address, each status filter shows the expected subset, and any
   inspection with a pending AI review or a failed classification
   appears under "Needs attention" — and that this section is absent
   entirely when nothing actually needs attention (never a fake/empty
   placeholder item).
5. **Report versioning.** Generate a report, edit a finding afterward,
   confirm the stale banner explicitly names the next version number,
   regenerate, and confirm the report screen now reads "Generated v2".
6. **Profile prefill.** Set an inspector name in Profile, start a new
   inspection, and confirm Property Details' inspector name field is
   pre-filled with it (and can still be overridden per-inspection).

## P0 workflow-closure pass

A follow-up pass closing the P0 gaps the previous pass's own P1
backlog called out explicitly — see
`docs/home_inspection_product_flow.md` ("P0 items closed this pass")
for the full description of each. No redesign; every change below is
additive to the existing architecture.

**Added**:

- **Per-area AI/review counts** on the Inspection Overview area cards
  (`InspectionQueueScreen`) — real, count-based, never a fake `0/0`.
- **Real connectivity detection** — new `ConnectivityService`
  abstraction (`lib/core/inspection/services/connectivity_service.dart`),
  implemented via `connectivity_plus` in
  `lib/data/remote/connectivity_plus_service.dart` (the only file that
  imports it — enforced by the architecture boundary test). Used as a
  fast-path gate right before an AI upload attempt (a fresh
  `checkStatus()` call, not a cached value) and to auto-resume queued
  AI work the moment connectivity returns, reusing the existing
  idempotency guarantees — no duplicate classifications, ever. Device
  connectivity is explicitly documented as not the same as working
  internet access; a real request failure is still the ultimate source
  of truth.
- **Visible sync state on Inspection Overview**, plus a real
  "N items waiting" count (evidence not yet synced) on both the
  dashboard card and the overview app bar, replacing the generic
  "Pending sync" label when the count is known.
- **Friendlier sync failure feedback**: "We couldn't sync some
  changes. Your inspection is still saved on this device." with a
  Retry action, replacing a raw `result.outcome.name`/message string.
- **Area notes** (`Section.note`) and **inspection notes**
  (`InspectionSession.inspectionNote`) — optional, contextual, never
  defects, never sent through AI classification. Editable from the
  area screen and the Inspection Overview app bar respectively; both
  appear in the generated report (area note under that area's heading,
  inspection note in the report summary).
- **Report Details** (`ReportDetailsScreen`) — a confirm/edit step for
  the report's cover-page metadata, reached from the Report screen,
  without returning to Property Details. Stored as a new
  `ReportMetadata` value, deliberately **separate** from
  `PropertyDetails` (the original setup record) so confirming/editing
  what appears on a report can never corrupt the inspection's own
  setup data. The PDF now uses `reportMetadata` when present, falling
  back to `PropertyDetails`, then the property type label.
- **Explicit "Completed" lifecycle status** — the dashboard pill now
  distinguishes In Progress / AI Processing / Report Ready / Completed
  instead of a binary Completed/Unfinished; only `reported` (an actual
  report exists) reads "Completed". An inline warning — "This
  inspection is completed. Changes may require a new report version."
  — appears on Inspection Overview when resuming a `reported` session;
  nothing is blocked or silently overwritten.

**Database**: schema v7 -> v8, strictly additive (`reportMetadataJson`
+ `inspectionNote` on sessions, `note` on sections) — see
`test/data/database_migration_test.dart` for the v7->v8 upgrade
coverage.

**Tests**: net +14 test cases (per-area progress rendering, the
connectivity abstraction's online/offline/unknown matrix, the offline-
save-then-reconnect-resume integration test, area/inspection-note
persistence, report-metadata precedence over property details, the
explicit lifecycle-status pill, and v7->v8 migration coverage). Full
suite: 235 passing, 0 failing; Functions unaffected (57 passing,
unchanged — no backend code was touched this pass).

**A genuine bug caught and fixed while implementing this**:
`isOnlineForAiProvider` originally read sign-in state only via the
async `authStateProvider` stream, which can still be `AsyncLoading`
(momentarily unresolved) in the exact window right after a session is
created and a finding is immediately saved — misreading "not yet
resolved" as "signed out" and therefore "offline". Fixed by falling
back to the synchronous, always-current `authServiceProvider.
currentUser` getter whenever the stream hasn't resolved yet. Caught by
`test/features/connectivity_ai_resume_test.dart` during development,
not by production usage.

**Known limitation carried forward from this pass's own implementation**:
`tester.runAsync()` is required in any `testWidgets` test that mixes
real async provider/repository work with widget pumping — the fake-time
test binding otherwise stalls indefinitely on real `Future`/`Timer`
completion (discovered writing
`test/inspection_queue_screen_test.dart`; no such issue exists in the
codebase's many plain `test()`-based provider tests, which run in real
async already).

### Manual E2E additions for this pass

1. **Per-area progress.** Open Inspection Overview with a mix of
   zero-finding and multi-finding areas; confirm each card's AI/review
   lines match reality and a zero-finding area reads "No findings"/"Not
   required" rather than "0/0".
2. **Real offline behavior.** Turn on airplane mode, save a finding,
   confirm it stays "Waiting for connection" (never briefly flashes
   "AI analysing"), turn airplane mode off, and confirm it resumes and
   completes without any manual retry.
3. **Sync item count.** With several unsynced photos, confirm the
   dashboard card and Inspection Overview both show the same real "N
   items waiting" count, and that it reaches 0 after a successful sync.
4. **Report Details round-trip.** From the Report screen, open Report
   Details, change the title/client, save, generate the report, and
   confirm the PDF cover page reflects the edited values — while
   Property Details (checked separately, e.g. by returning to a fresh
   New Inspection flow) is unaffected.
5. **Area/inspection notes in the PDF.** Add a note to one area and an
   inspection-level note, generate the report, and confirm both appear
   in the expected places (area heading; report summary).
6. **Completed-inspection warning.** Resume an inspection that already
   has a generated report, add or edit a finding, and confirm the
   "changes may require a new report version" banner is visible before
   any edit is made (not just after).

## Commercial layer

A commercial layer (AI Credits, Flex Credits, House Pass, wallet
ledger, sandbox-only payment architecture) was added across three
passes — backend (`functions/src/billing/`) and Flutter (splash/bottom
nav/Wallet/Top Up/Choose AI Plan/House Pass screens, Drift v9, Auto
Analyse, per-finding AI level override, and Save Finding no longer
auto-queuing AI). See `docs/commercial_model.md` for the full design.
This does not change this document's overall pilot-readiness status —
it is additional scope layered on top of the existing inspection
workflow, validated via `dart format`/`flutter analyze`/`flutter test`
(291 tests)/`flutter build ios --simulator --debug`/`flutter build apk
--debug`/`flutter build apk --release` and the `functions/` suite
(lint/build/111 tests), but never a real device or a human clicking
through the commercial flows.

**READY** (built and tested against the fake/local-only backend and
the callables' own test suites):
- Wallet ledger, its cached balance, and customer-safe transaction
  descriptions (no internal ledger jargon, no literal "Sandbox" wording
  in a description a real user could ever see).
- The Flex Credits estimate → approve → reservation → settlement
  protocol, including the insufficient/zero-Credits flows and a
  Top-Up-returns-to-the-same-finding round trip.
- House Pass: backend purchase/sandbox-activation/allowance tracking,
  a production-safety gate that refuses to sell the test allowance
  outside sandbox mode (`isHousePassSafeToSell` —
  `functions/src/billing/pricing_config.ts`), and the full Flutter UX
  (purchase screen, every lifecycle state, an inspection-queue re-entry
  banner, and an allowance-reached interrupt that turns Auto Analyse
  back off and asks for fresh consent before spending Flex Credits).
- Auto Analyse (2026-10-02): now always on — no toggle; see
  docs/commercial_model.md ("Auto Analyse is always on"). Historical
  note follows.
- Auto Analyse: a per-inspection toggle, off by default for Flex
  Credits (explicit opt-in required), turned on automatically the
  moment a House Pass becomes active.
- AI tiers: Profile default, per-inspection override, and (new this
  pass) a per-finding override in the approval dialog itself — no raw
  provider/model id is ever shown to a customer anywhere in Flutter.
- House Pass Expert-surcharge UX with the backend-computed surcharge
  amount, never computed client-side.
- The sandbox payment boundary, independently proven on both halves:
  backend/environment (`PAYMENTS_MODE=sandbox` required —
  `handle_confirm_sandbox_payment.test.ts`) and Flutter compile-time
  (every `confirmSandboxPayment` call site is `kDebugMode`-gated,
  checked by `test/architecture/sandbox_payment_boundary_test.dart`,
  and confirmed by grepping the compiled release AOT binary — zero
  occurrences of "sandbox"/"Simulate Payment"/"Debug build" survive
  release tree-shaking).
- The OpenAI provider mapping (current model ids verified against
  official docs, image/structured-output support, timeout/retry
  handling) — this pass also found and fixed a real bug: the GPT-5.6
  family rejects any non-default `temperature`, which would have made
  every real `analyseFinding` call fail outright.

**STILL REQUIRED before a real production launch:**
- `analyseFinding` (the priced AI-classification callable) cannot be
  deployed until `OPENAI_API_KEY` is provisioned in Secret Manager for
  `prodefact-82bac` — see `docs/commercial_model.md` ("AI levels and
  provider mapping") for the exact command. No key was fabricated
  anywhere in this codebase; `classifyFinding` (the existing, unpriced
  path) is unaffected and keeps using DeepSeek.
- An explicit production House Pass allowance — `pricing/config` still
  needs `housePass.environment: "production"` with a deliberately
  chosen `allowanceFindings`, a business decision this pass doesn't
  attempt. Until then, House Pass purchases outside sandbox mode are
  now actively refused rather than silently selling the test value.
- A real payment gateway — Top Up and House Pass purchase only work via
  the debug-only sandbox path today.
- Manual/real-device QA — nothing here replaces a human clicking
  through the commercial flows on a real device.

Supporting infrastructure already in place:
- Firestore rules for `users/{uid}/wallet`, `walletTransactions`,
  `housePasses`, `paymentIntents`, `aiJobs` (owner-read-only, no client
  write ever) and `pricing/config` (unreadable and unwritable by any
  client) — see `firestore.rules`, dry-run-validated as compiling
  successfully against project `prodefact-82bac` this pass.
- No new Firestore composite indexes are required — every commercial
  query (House Pass status, payment intents) uses plain equality
  filters with client-side sorting instead of `orderBy`, deliberately
  avoiding the need for one (`firestore.indexes.json` stays empty).
