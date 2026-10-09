# UX architecture — screen ownership and navigation (2026-10)

The inspection UX and navigation redesign. Product rules are frozen: report/PDF,
catalogue, AI matching, Reanalyse/Reject/Delete/Add New, billing and the
AI queue are unchanged. This pass changes only which screen owns what, how
the inspector moves between screens, and how they look.

## 1. Audit — before

### Navigation map (before)

```
Splash → Inspections tab (landing)

Bottom nav: Home | Inspections | + | Wallet | Profile

Home
  bell            → attention sheet → row → Inspection (queue)
  avatar          → Profile (pushed a second copy over the Profile tab)
  credits card    → Wallet tab;  Top Up → Top Up
  active hero     → Inspection (queue)
  needs-attention → Inspection (queue)            ← same as hero
  sync row        → Inspections tab
  recent rows     → Inspection (queue)            ← same as hero
  "View all"      → Inspections tab
Inspections
  bell / avatar   → attention sheet / Profile (duplicates of Home's)
  logout icon     → signs out (duplicate of Profile's Sign Out)
  every card      → Inspection (queue)
  metric strip    → (display only; repeats the filter-chip counts)
+                 → New Inspection setup (always, even with work in progress)
Wallet tab        → Top Up, House Pass, avatar → Profile
Profile           → (settings only; no Wallet/Custom Catalogue entry)

Inspection (queue) "Physical Inspection" — overview, progress hero, stats,
                   status strip, every area card, filters, add area, complete
  area card       → Area
  Complete        → AI Review
Area              → finding cards (inline resolution), camera
AI Review         → every finding (confirmed ones too) → Report
Report            → Report Details
```

### Problems found

1. **One destination, many doors.** Home's hero, needs-attention rows and recent
   rows, the bell sheet and every Inspections card all opened the same
   Inspection screen. "Needs review" never opened the review itself.
2. **Home duplicated Inspections.** "Recent inspections" was the same list,
   with a smaller card.
3. **No hub for one property.** The "Physical Inspection" screen tried to be the
   overview, the area list, the progress dashboard and the completion step all
   at once (about 15 widgets before the first area).
4. **AI Review duplicated Area Findings.** It listed every finding, confirmed
   ones included, so the few that needed a decision were hard to find.
5. **Report was hard to reach.** The only way in was through AI Review's
   "Continue to Report", even for an inspection that was already completed.
6. **"+" ignored context.** It always started a new inspection, even mid-job.
7. **Wallet was a primary tab** though inspectors use it rarely, while there was
   no top-level place for review work.
8. **Duplicate account chrome.** Bell, avatar and logout icons were repeated on
   Home, Inspections, Wallet and Profile (the avatar pushed a second Profile).
9. **Status visuals were inconsistent.** There were four separate chip
   implementations (session, area, suggestion and finding tone dot), each with
   its own labels and colours.
10. **The finding card had too many equal buttons.** It had an inline "Add
    another defect photo" in every card, the same action as the screen's camera
    button, plus a menu and three actions.

## 2. Plan — after

```
HOME → INSPECTION OVERVIEW → AREAS → AREA FINDINGS → FINDING DETAIL
```

Bottom nav: **Home | Inspections | + | Review | Profile**. Home is the landing
screen.

| Screen | Route | Owns |
|---|---|---|
| Home | `/home-inspection/home` (tab) | At a glance: the active inspection, things needing review, the latest report, a small credits card |
| Inspections | `/home-inspection/sessions` (tab) | Managing every job: search, filters (All, Draft, Active, Needs Review, Report Ready, Completed) and cards |
| Review | `/home-inspection/review-inbox` (tab) | Review inbox across inspections: only inspections with findings that need a decision |
| Profile | `/home-inspection/profile` (tab) | Account, inspector/company details, AI preference, custom catalogue, Wallet, app info, sign out |
| Inspection Overview | `/home-inspection/inspection` | Hub for one property: identity, status, progress, report readiness, and one primary action |
| Areas | `/home-inspection/inspection-areas` | Progress by area: filters, add a newly discovered area |
| Area Findings | `/home-inspection/inspection/:sectionId` | Capture plus findings for one area (unchanged logic) |
| Finding Detail | `/home-inspection/finding/:findingId` | A deep view of one finding, with its actions |
| AI Review | `/home-inspection/complete` | Exceptions only for the open inspection; resolved findings are collapsed |
| Wallet | `/home-inspection/wallet` (pushed) | Unchanged content; opened from Home's credits card and from Profile |
| Report | `/home-inspection/report` | Unchanged; opened from the Overview (and still from AI Review) |

### Retained, merged, added

- **Retained (logic untouched):** New Inspection setup flow, Area Findings
  capture/preview/quality/save, Report, Report Details, Top Up, House Pass,
  Photo Guide, Photo Viewer.
- **Split:** the old "Physical Inspection" screen becomes **Inspection
  Overview** (hub) and **Areas** (area list, filters, add area).
- **Added:** Review inbox (tab), Finding Detail, the capture-context sheet for
  "+".
- **Removed:** Home's "Recent inspections" list (Inspections owns it), the
  Inspections metric strip (the filter chips already count), the Inspections
  logout icon (Profile owns sign-out), the bell on Home/Inspections/Wallet (the
  Review tab with its badge replaces it), and the per-card "Add another defect
  photo" (the screen's camera button does exactly this).
- **Moved:** Wallet goes from a tab to a pushed screen, reached from Home's
  credits card and from Profile → Wallet & usage. No workflow depended on it
  being a tab. Top Up, House Pass purchase and the AI "Top Up" prompts all push
  their own routes.

### Each door has one destination

| Entry | Destination |
|---|---|
| Home → Continue Inspection | Overview of the most recently updated open inspection |
| Home → Needs review (one inspection) | That inspection's AI Review |
| Home → Needs review (several) | Review tab |
| Home → Latest report | That inspection's Report |
| Home → Start New Inspection | New Inspection setup |
| Home → View all inspections | Inspections tab |
| Home → credits card | Wallet |
| Inspections card | Overview |
| Overview primary (in progress) | **Continue Inspection** → the current area's Area Findings |
| Overview primary (site visit done, review pending) | **Review Findings** → AI Review |
| Overview primary (report ready or completed) | **View Report** → Report |
| Overview rows | Areas, Review findings, Report, Inspection details (a sheet); the row matching the primary is hidden |
| Areas card | That area's Area Findings |
| Finding card → photo | Photo viewer;  → card body / "Details" → Finding Detail |
| Review tab row | Resume, then AI Review |
| "+" (open inspections exist) | Sheet: pick an open inspection → pick an area → camera opens in that area; or start a new inspection |
| "+" (no open inspections) | New Inspection setup (unchanged) |

"Current area" for Continue Inspection is the area of the newest finding when
that area isn't complete yet. Otherwise it's the first not-completed area in
queue order (plumbing first). If every area is complete, it goes to Areas.

## 3. Visual system

- One status vocabulary, `AppStatus` / `AppStatusChip`, with icon, label and
  colour for Draft, Not started, In progress, Queued, Analysing, Confirmed,
  Needs review, Failed, Rejected, Report ready and Completed. Every chip in the
  app (sessions, areas, findings, suggestions) maps onto it.
- Cards drop the outline border in favour of a soft shadow. Status uses one
  chip, not an accent edge plus a chip.
- Photos are larger: the residence/cover photo on inspection cards and the
  Overview header, and a full-width photo on finding cards.
- Every screen has one filled primary action, pinned at the bottom. Secondary
  actions are list rows or text buttons.
- Touch targets are at least 48dp. Body text is at least 13sp.
