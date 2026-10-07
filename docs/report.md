# PDF Reporting (Phase 7)

Once physical inspection is complete and every AI suggestion has been
resolved (accepted, edited, or rejected/corrected), the inspector can
generate a homeowner-facing PDF report from the inspector-approved
findings, preview it, and share/export it through the OS share sheet.
Report generation is fully local — it never depends on Firebase or
network access.

## Report eligibility (the gate)

With progressive per-finding AI (see `docs/ai_review.md`), report
readiness requires **three independent axes** to all be settled —
never conflated:

```
Physical inspection complete (every included area)
  AND no finding still mid-AI-processing (queued/uploading/analyzing)
  AND no AI suggestion still pending review
  -> Report
```

`ReportCoordinator.generateReport` (implemented by
`DefaultReportCoordinator`, `lib/data/report/default_report_coordinator.dart`)
enforces this at the application/domain level, not just by disabling a
button:

1. Load the session. Missing session -> `ReportGenerationOutcome.sessionNotFound`.
2. `session.status == InspectionStatus.inProgress` (physical inspection
   not yet complete) -> `physicalInspectionIncomplete`.
3. `AiProcessingProgress.inFlight > 0` (some AI-eligible finding hasn't
   settled into a terminal `aiStatus` yet) **or**
   `AiReviewProgress.pending > 0` (some suggestion is still `pending`)
   -> `aiReviewIncomplete`.
4. Otherwise, render, save, and persist the report ->
   `ReportGenerationResult.success(report)`.

A `rejected`/"unresolved" suggestion does **not** block generation — it
is a *resolved*, reviewed state; see "Unresolved findings" below for
how it renders instead of blocking. A finding with zero evidence (no
photo — only possible for a legacy, pre-camera-first finding) is never
AI-eligible at all, so it can never block this gate either.

Every outcome is a typed `ReportGenerationResult`
(`lib/core/inspection/report/report_generation_result.dart`) — a caller
that tries too early gets a controlled result object, never an
exception or a silently-empty report. This mirrors `AiAnalysisResult`/
`SyncResult` from earlier phases.

UI-side, the Report screen is only reachable via "Continue to Report"
on the AI Review screen, itself only enabled once every suggestion is
resolved — the same defense-in-depth pairing (coordinator check +
navigation gating) used for AI review in Phase 6.

## Final inspector value precedence

The report **only ever shows inspector-approved/final values** — never
the AI's original suggestion when it was changed or rejected.
`buildReportModel` (`lib/core/inspection/report/report_model_builder.dart`,
a pure function, no I/O) implements this precedence per finding, and
takes two different paths depending on the finding's kind:

**Camera-first findings** (no legacy `elementId` — the normal case
today): resolved fresh from the controlled catalogue by id, never from
any AI-provided free text.

- A resolved `AiSuggestion` with `finalCatalogueEntryId` set -> resolve
  that id via `DefectCatalogue.instance.byId` and use its
  `mainElementName`/`componentName`/`defectDescription`/
  `correctiveAction`. The AI's original `suggestedCatalogueEntryId` is
  never read here.
- A resolved suggestion with no final entry (rejected/"unresolved") ->
  see "Unresolved findings" below.
- No suggestion yet, or still pending (shouldn't normally reach report
  generation at all, since the gate above blocks it — this is a
  defensive fallback) -> a clearly-labeled "Pending review" placeholder
  rather than an unapproved AI value.

**Legacy findings** (schema v5 and earlier, real `elementId` set):
unchanged from the original design — a resolved legacy suggestion's
`legacyFinalDefectType`/`legacyFinalRecommendation`/`legacyFinalNotes`
free-text fields are used; no suggestion at all falls back to the
finding's own recorded `description`/`notes`.

`test/core/report/report_model_builder_test.dart` asserts the original
AI value never leaks into the report text across accept/change/reject,
for both camera-first and legacy findings.

### Unresolved findings

A finding the inspector explicitly rejected/left unresolved renders as
an explicit line — `elementName: "Unresolved"`,
`defectType: "Unresolved — pending manual classification"` — rather
than being silently omitted or blocking the whole report. This is a
deliberate choice: the report readiness gate above does not require
every finding to have a confident classification, only that every
suggestion has been *reviewed* (accept/change/reject all count; only
`pending` blocks) — so an inspector can generate a report even with one
or two findings they've decided not to classify, as long as they made
that decision explicitly.

## Report domain model (provider-neutral)

The generic inspection domain never binds directly to a PDF library.
A typed model is built first, then handed to a swappable renderer:

```
InspectionSession
  -> buildReportModel()          (pure function, lib/core)
  -> ReportModel                 (pure Dart, lib/core)
       -> ReportRenderer.render() (interface, lib/core)
            -> PdfReportRenderer  (lib/data — the only file that
                                    imports package:pdf)
```

`ReportModel` (`lib/core/inspection/report/report_model.dart`):

```
ReportModel
  sessionId, propertyTypeLabel, inspectionDate, generatedAt
  totalAreas, completedAreas, totalFindings, totalEvidence
  areas: [ReportAreaSection]
    name, isPlumbing
    findings: [ReportFinding]     — deliberately can be empty
      number                      — sequential across the WHOLE report,
                                     never reset per area (the reference
                                     format's "No" column)
      elementName, componentName?
      defectType?, recommendation?, notes?
      evidenceFilePaths: []
```

`number` is assigned once, in `buildReportModel`, by a running counter
threaded across areas in order — area 1's 3 findings get 1-3, area 2's
findings continue from 4, and so on, matching the reference report
format ("DEFECT_REPORT_LIST.xlsx - REPORT- For Editing.pdf") where
numbering runs continuously down the whole document rather than
restarting per section.

Only `session.sections.where((s) => s.isIncluded)` are considered —
excluded areas never appear in the report at all.

`test/architecture/repository_boundary_test.dart` asserts that no file
outside `lib/data/` imports `package:pdf/pdf.dart` or
`package:pdf/widgets.dart`, the same boundary pattern already used for
Drift/Firebase/AI SDKs.

## PDF structure (`PdfReportRenderer`)

`lib/data/report/pdf_report_renderer.dart`, built on `package:pdf`:

- **Cover / header**: "ProDefact", "Home Inspection Report", inspection
  ID (session id), property type, inspection date, report generation
  date.
- **Inspection summary**: total areas, completed areas, total findings,
  total evidence photos, and a completion label.
- **Area-by-area findings**, grouped by area name, matching the
  reference report's structure (Foyer/Entrance, Living, Kitchen, Master
  Bathroom, etc. — one heading per included area, in configured
  order):
  - Each finding card is headed `#<number> — <main element> —
    <component>` (continuously numbered across the whole report — see
    `ReportModel` above), followed by "Finding: <defect description>",
    "Recommendation: <corrective action>" (the controlled catalogue
    text, resolved fresh by id — never AI free text), inspector notes,
    and any evidence thumbnails.
  - **An area with zero findings still renders its heading**, with
    "No defects recorded." in place of finding cards — it is never
    omitted from the report.
  - A rejected/unresolved finding renders as "Unresolved — pending
    manual classification" rather than blank (see "Unresolved
    findings" above).
- **Evidence photos** are embedded as inline thumbnails. A missing,
  deleted, or unreadable image file is caught per-image
  (`_buildEvidenceThumbnail`'s try/catch) and replaced with a small
  "Photo unavailable" placeholder box — one bad photo never fails the
  whole report render. `test/data/pdf_report_renderer_test.dart`
  exercises this directly against the real renderer.
- **Footer**: "Generated by ProDefact. Advisory report for
  informational purposes only." plus "Page X of Y" — deliberately
  generic, no fabricated certifications, regulatory claims, or
  warranties.

Design is intentionally plain and professional: consistent spacing,
a small accent color for headings, finding cards with a light
background, and `pw.MultiPage` for automatic page breaks — no attempt
at heavy visual polish.

## Report generation lifecycle & file naming

`buildReportFileName` (`lib/core/inspection/report/report_file_naming.dart`)
produces a deterministic, sanitized filename:

```
ProDefact_HomeInspection_<sanitizedSessionId>_<yyyyMMdd>.pdf
```

Non `[A-Za-z0-9_-]` characters in the session id are stripped; an empty
sanitized id falls back to `session`, so the filename is always valid
across iOS and Android filesystems.

`DefaultReportCoordinator.generateReport`:

1. Builds the `ReportModel` from the current session.
2. Renders it via the injected `ReportRenderer`.
3. Saves the bytes via the injected `ReportFileStore` (production:
   `LocalReportFileStore`, writing to `<appDocumentsDirectory>/reports/`
   via `path_provider`).
4. If a previous report existed for this session under a **different**
   file path, deletes the old file — avoiding orphan PDFs on disk.
5. Persists `Report` metadata (id, sessionId, filePath, fileName,
   generatedAt, sourceUpdatedAt) via `InspectionRepository.saveReport`.
6. Any failure at steps 2–5 is caught and returned as
   `ReportGenerationResult.failure(message)` — the inspection's
   findings/evidence/suggestions are completely untouched by a failed
   report run.

## Local file storage & report metadata persistence

PDF **bytes are never stored in Drift** — only metadata. Drift schema
v4 adds `ReportRows` (`lib/data/local/tables.dart`):

```
ReportRows
  id, sessionId (PRIMARY KEY, references InspectionSessionRows, cascade)
  filePath, fileName
  generatedAt, sourceUpdatedAt
  syncStatus (default: localOnly)
```

`sessionId` (not `id`) is the primary key — this is the "latest report
per session" policy: `insertOnConflictUpdate` naturally replaces the
row on regeneration rather than accumulating history, and the
coordinator explicitly deletes the previous PDF file. A session has at
most one current report at any time. Added via
`MigrationStrategy.onUpgrade` (`from < 4`) — the existing v1–v3
database is never dropped or recreated.

`Report` metadata survives app restart: loading a session
(`DriftInspectionRepository.loadSession`) joins in its `ReportRows` row
if one exists.

## Regeneration / invalidation policy

There is no separate mutable "stale" status column. Instead,
`Report.isStaleRelativeTo(currentSessionUpdatedAt)` compares the
report's stored `sourceUpdatedAt` snapshot against the session's
current `updatedAt`. If the session has changed since the report was
generated (a finding edited, an AI suggestion changed, new evidence
added), the Report screen shows a "data has changed, regenerate" banner
— **the outdated report is never silently presented as current without
that warning**. Regenerating always produces a fresh PDF, replaces the
`ReportRows` row for that session, and deletes the old file.

## Sharing / export

`ReportShareService` (interface, `lib/core/inspection/report/report_share_service.dart`)
is implemented by `PrintingReportShareService`
(`lib/data/report/printing_report_share_service.dart`), which calls
`package:printing`'s `Printing.sharePdf()` — the generic, cross-platform
OS share sheet on both iOS and Android. No email/WhatsApp-specific
integration. Kept behind the interface so tests use
`FakeReportShareService` instead of driving a real share sheet.

The Report screen's preview uses `package:printing`'s `PdfPreview`
widget directly (a UI-only rendering widget, not PDF construction) —
this is the one accepted exception in the architecture boundary test,
documented inline there.

## Firebase / cloud independence

Report **generation** never touches Firebase, auth, or the network —
`test/features/report_provider_test.dart` generates a report with
`firebaseReadyProvider` left at its default (unconfigured) value to
prove this directly.

Report **metadata** (not PDF bytes) is optionally mirrored to Firestore
for future sync: `CloudInspectionRepository.pushReportMetadata` writes
only `id`, `fileName`, `generatedAt`, `sourceUpdatedAt` under
`users/{uid}/inspections/{id}`'s `report` field.
`DefaultSyncCoordinator` calls this alongside its existing
sections/findings/evidence/AI-suggestion sync, opportunistically — a
failed or skipped metadata push never blocks local report generation
or use. Uploading the actual PDF bytes to Cloud Storage was
deliberately **not implemented** in this phase (optional, per spec);
adding it later is an addition to `FirestoreCloudInspectionRepository`
alone.

## UI flow (`ReportScreen`)

`lib/features/home_inspection/presentation/screens/report_screen.dart`,
reached at `/home-inspection/report`:

- **Not generated**: "Generate Report" button.
- **Generating**: button shows a spinner; disabled to prevent double
  submission.
- **Ready**: `PdfPreview` (from `package:printing`) shows the generated
  PDF; "Regenerate" and "Share / Export" actions.
- **Failed**: an error banner ("Report generation failed: ...") above
  the not-generated view, so the inspector can retry without losing any
  inspection data.
- A stale-data banner appears whenever `report.isStaleRelativeTo(...)`
  is true, independent of the four states above.

## Testing strategy

Widget tests intentionally avoid pumping the real `PdfPreview` widget
(it drives `package:printing`'s platform channels for rasterization,
which aren't mocked in the default Flutter test environment) —
`test/report_screen_test.dart` covers the not-generated and failed
states only; the ready/success path is verified instead at the
repository/coordinator/provider level (`test/data/report_coordinator_test.dart`,
`test/features/report_provider_test.dart`) by asserting on
`session.report` and the fake file store, without ever mounting
`PdfPreview`.

## Future report customization

Because `ReportModel` and `ReportRenderer` are decoupled, future work
(a firm logo/letterhead, configurable disclaimer text, a different
layout per property type, a second renderer such as HTML/DOCX) is an
addition alongside `PdfReportRenderer`, not a rework of the report
gate, the data model, persistence, or sharing.


## Cover and defect table (2026-10-07)

**Cover (page 1), top to bottom:** brand header, the large Residence / Unit
Photo (full width, 290pt box, fitted — never stretched; nothing drawn if there
is no photo), `BUILDING DEFECT INSPECTION REPORT`, property line, then Address,
Purchaser / Owner, Property type, Project / Developer, Inspection date,
Prepared by, Contact, a small version/ID line and the Inspection Summary.

**Defect pages (page 2 on):** at most 5 findings per page, as a table with a
repeated header row:

| No. | Area / Element | Finding | Photo | Recommendation | Note |
|---|---|---|---|---|---|
| 26pt | 88pt | 110pt | 116pt | 112pt | 71pt |

(content width 523.3pt = A4 less 36pt margins; photo box 104 x 80pt, aspect
ratio preserved.) Each row is the finding's **final resolved** result — the
inspector's choice over a stale AI result — with the catalogue's corrective
action. **These dimensions are estimates from the written brief; no reference
screenshots were supplied, so nothing has been measured or overlaid against a
reference.** A reference page would let the column proportions, row heights,
fonts and borders be measured and tuned.
