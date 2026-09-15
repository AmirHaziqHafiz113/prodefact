# Production Hardening (Phase 8)

Phase 8 hardens the existing Home Inspection flow (Phases 1–7) for pilot
use. It does not add new product scope — no new industries, no redesign
of the inspection flow. This document covers the reliability, security,
and operational behavior added or confirmed this phase, plus what still
requires manual, external configuration before a real pilot.

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

- `DefaultAiReviewCoordinator.runAnalysis` — an in-memory
  `Set<String> _inFlight` rejects a second concurrent call for a
  session already being analyzed (returns `alreadyReviewed`). Without
  this, two concurrent calls could both read `aiReviewState: notStarted`
  before either had durably written `analyzing`, both call the AI
  backend, and duplicate every suggestion.
- `DefaultReportCoordinator.generateReport` — the same pattern; without
  it, two concurrent calls (same day → same predictable filename) could
  race writing the same file path.
- `DefaultSyncCoordinator.syncSession` — the same pattern, for a
  double-tap of "Sync now".

`ActiveInspectionSession` also holds its own `_isAnalyzing`/
`_isGeneratingReport`/`_isSyncing` flags as a second layer, so a rapid
double-tap at the UI level is rejected even before reaching the
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
- **AI requests exclude unnecessary account data**: `AiAnalysisRequest`/
  `AiFindingContext` (`lib/core/inspection/ai/`) have no `ownerUid`,
  `email`, or auth-token field at all — a structural guarantee, not
  just a convention — confirmed by capturing an actual request built
  during a full workflow run in `test/security_test.dart`.
- **Logs don't print secrets/tokens**: `AppLogger.error` logs an
  exception's type name rather than its full message (see "Logging"
  above), specifically to avoid a `FirebaseAuthException` or similar
  leaking an email/token into developer logs.
- **Production configuration placeholders are clearly distinguishable**:
  `lib/firebase_options.dart` opens with a large comment block
  explicitly stating it's a placeholder with no real credentials and
  the exact command (`flutterfire configure`) that replaces it.

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

Unchanged in shape from Phase 6, confirmed intact this phase:

```
Flutter (AiInspectionService.analyze)
  -> [future] authenticated backend gateway
       -> validates the request, selects/calls the real AI provider,
          validates the response, logs/rate-limits
  -> Flutter parses the typed AiAnalysisResponse
```

`FakeAiInspectionService` is explicitly named and documented as
fake/demo (`lib/data/ai/fake_ai_inspection_service.dart`) — deterministic,
no network call, not production AI. No paid/provider API is ever called
directly from Flutter, and no provider secret exists in the mobile
codebase (see "Security" above) — a real provider integration is
additive behind the same `AiInspectionService` interface, an override of
one provider (`aiInspectionServiceProvider`), never a rework of
`ActiveInspectionSession`, `AiReviewCoordinator`, the Drift schema, sync,
or any UI.

## Report hardening

Confirmed intact from Phase 7 (see `docs/report.md` for full detail),
re-audited this phase:

- Eligibility gating (physical inspection complete AND every AI
  suggestion resolved) is enforced in `DefaultReportCoordinator`, not
  just by hiding a button.
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

- **Firebase/AI are not "live"** in this repository as delivered: no
  real Firebase project is configured (placeholders only), and AI
  review runs against `FakeAiInspectionService` (deterministic, no
  network). Both are fully scaffolded to swap in real implementations
  behind their existing abstractions without touching the domain, UI,
  or persistence layers — see `docs/ai_review.md`/`docs/firebase.md`.
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
  model builder, migrations) is heavily tested; UI screens beyond the
  ones this phase specifically touched were not newly instrumented; see
  the coverage figure in the final Phase 8 report for the current
  overall percentage.
- **`activeSessionErrorProvider` is not yet wired into every screen** —
  it exists and is exercised by tests, and the two screens/flows this
  phase specifically hardened (start/resume, evidence capture, report
  generation) show it; wiring a consistent banner into the remaining
  screens (physical inspection queue, area configuration, AI review) is
  straightforward, additive follow-up work, not started this phase to
  keep the change bounded.

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
      ever grows (no delete-sync), and AI suggestions are demo-quality
      unless a real backend has been connected.
