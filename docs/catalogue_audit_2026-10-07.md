# Catalogue audit — "DEFECT_REPORT_LIST.xlsx - MASTER LIST" (2026-10-07)

**Outcome: the attached document was analysed but NOT applied.** Replacing the
222-entry catalogue with it would delete most of the app's defect coverage and
cannot be done faithfully from this export. Details and the way forward below.

## What the attachment actually contains

A 52-page PDF export of a spreadsheet, structured **by location**, not by
building element:

- 13 "main elements" that are *areas*: Roof, Entrance / Foyer, Living, Dining,
  Balcony, Yard, Kitchen, Master Bedroom, Bedroom 1-3, Utility Area, Bathroom.
  (These match the app's inspection **Sections**, not its catalogue elements.)
- 104 components named "Area - Item" (e.g. "Living - Floor", "Balcony - Hand
  Rail", "Toilet - Floor Trap").
- Defect lists exist for only **14 of the 104 components**:
  - Roof - Matel [sic] Deck (8), Tiles (4), Water Tank (4), External wall (6),
    Others (6) = 28 rows
  - 9 door components (Entrance Main Door, Yard / Kitchen / Master Bedroom /
    Bedroom 1-3 / Utility / Toilet Door), 13 identical defects each = 117 rows
  - **90 components have no defect rows at all** (every Floor, Wall, Ceiling,
    Window, Window Handle, Switches, Plugpoint, Sliding Door, Hand Rail, Floor
    Trap, Water Closet, Wash Basin, Shower Head, ...).
- 48 corrective actions, numbered 1-48, **not linked to any defect row**: the
  first table's three columns are visibly misaligned (blue cells run past their
  component rows), and ~12 of the actions are just "Please make good".
- No "Railing" component. The closest is "Balcony - Hand Rail", with no defects.

## Old (coded) vs attachment

| | Coded catalogue | Attachment |
|---|---|---|
| Structure | Element -> Component -> Defect -> Corrective action | Area -> "Area - Item" -> (mostly empty) |
| Main elements | 9 (Roof, Door, Window, Wall, Floor, Ceiling, Plumbing, Sanitary Fitting, Electrical Fitting) | 13 (areas) |
| Components | 34 | 104 |
| Defect rows | 222, each with its own corrective action | ~145 (28 roof + 117 door), no action link |
| Corrective actions | 222, one per defect | 48, unlinked |

Entries that would be **lost** if the attachment replaced the code: every
Floor (38), Window (37), Sanitary Fitting (32), Wall (15), Ceiling (9),
Plumbing (8) and Electrical Fitting (7) entry — 146 of 222, everything outside
Door and Roof — because the attachment lists no defects for them. Even the 74
Door entries (Door Leaf, Frame, Hinge, Lockset, Closer, Stopper, Sliding Door
Frame/Panel/Glass, ...) have no counterpart: the attachment's 13 door defects
are generic.
Entries that the attachment adds: roof component families and 13-defect door
sets (generic "Chipped / Dented / Hole", "Difficult to Close", "Single Layer
Paint on Top of Door Leaf", ...), none of which carry a corrective action.

## Why it was not applied

1. It is not a drop-in replacement: it is a location matrix in which 90 of 104
   components have no defects, so applying it would remove working AI/search/report coverage.
2. Corrective actions cannot be attached to defects without guessing.
3. Applying it would also invalidate every stored finding's catalogue id.

## Railing — root cause

"Railing" is **not in the coded catalogue and not in the attachment with any
defect**, so it could never be analysed, suggested or reported: there was
nothing to select. The earlier belief that it "exists in the catalogue" does not
match either source. What was wrong and is now fixed:

- A note naming a part the catalogue lacks (railing, handrail, balustrade,
  staircase, floor trap, cabinet, wardrobe, countertop, fence) is detected
  deterministically; such a finding is **never forced onto a look-alike**
  (a door) — it goes to review with the paint-finish family as candidates and
  the inspector can **Add New** (company catalogue) — which then resolves,
  searches, stores and reports like any entry (tested with a Railing entry).
- There is no whitelist of report components: the PDF renders whatever entry
  it is given (tested with Railing, Door Frame, Sliding Door Frame, Concrete
  Wall, Floor Tiles).

## What is needed to adopt the new catalogue

One of:

- A clean export: one row per *component x defect*, with its own corrective
  action, element/component names as they should appear (and Railing, Floor
  Trap, Hand Rail with defects), **or**
- Confirmation that the location-based hierarchy is intended — then the
  catalogue schema (element -> component) needs a decision on how areas and
  items map before any data is replaced.

Until then the coded catalogue stays authoritative, unchanged (222 entries).
