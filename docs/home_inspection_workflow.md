# Home Inspection Workflow

This is the target end-to-end workflow for Phase 1 (Home Inspection
only). The current foundation implements the entry point (steps 1–3, as a
read-only preview); the rest is future work.

1. **Inspector opens ProDefact** and chooses to start a Home Inspection.
2. **Inspector chooses a property type**: High Rise or Landed.
3. **ProDefact shows the default inspection areas** for that property
   type. Areas common to both:

   Entrance / Foyer, Kitchen, Living Room, Dining Room, Yard, Balcony,
   Master Bedroom, Bedroom 2, Bedroom 3, Bedroom 4, Maid Room / Powder
   Room, Utility / Store, Master Bathroom, Bathroom 2, Bathroom 3, AC
   Ledge, Serambi, Studio Unit, Studio Bathroom.

   Landed properties additionally offer: Staircase, Backyard, External
   Unit Wall, Porch, Main Gate, Mailbox / Parcel Box / Trash Bin, Roof.

   These are **defaults, not a fixed list** — every property differs, so
   inspectors must eventually be able to include, exclude, add, remove,
   and rename areas (not yet built).

4. **Physical inspection begins.** Areas containing plumbing — Master
   Bathroom, Bathroom 2, Bathroom 3, Studio Bathroom (if applicable), and
   Kitchen — must be inspected first, because leakage and ponding tests
   need time to run while the inspector covers other areas. Kitchen is
   included because its inspection starts by opening the sink tap and
   monitoring for leakage, same as the bathrooms. The default area
   ordering already reflects this (plumbing areas sorted first).

5. **Inspector inspects each area.** Typical elements — Floor, Wall,
   Ceiling, Door, Window, M&E — each with their own components (e.g.
   Floor → floor tile, cement slab, grouting, skirting, timber board).
   Elements and components are configurable, not hardcoded per area.

6. **During inspection** the inspector performs the physical check,
   captures photos, records information, and saves findings **as
   drafts**. Critically:

   > AI does **not** analyze photos during this step. There is no
   > photo → AI → confirmation → next-finding loop. AI review only
   > starts after the entire physical inspection is complete.

7. **Steps 5–6 repeat** until every applicable area is finished.
8. **Once physical inspection is complete**, AI analyzes all captured
   photos and inspector input together, suggesting element, component,
   likely defect type, recommendation, and notes where appropriate.
9. **AI is advisory only.** For every AI suggestion, the inspector can
   Accept, Edit, or Reject/Correct it. The inspector is always the final
   authority.
10. **Both the original AI suggestion and the inspector's decision are
    preserved** (accepted / edited / rejected, plus the correction), for
    later AI evaluation and improvement.
11. **Once AI review is complete**, ProDefact generates a professional
    PDF report for the homeowner.

## What the foundation phase implements

- The domain shapes for all of the above (`Section`, `InspectionElement`,
  `Component`, `Finding`, `Evidence`, `AiSuggestion`, `Report` in
  `lib/core/inspection/`).
- The Home Inspection default area/element/component configuration
  (`lib/features/home_inspection/config/home_inspection_config.dart`),
  including the plumbing-first ordering rule.
- The property type entry point (step 2) and a read-only preview of the
  resulting default areas (step 3), wired through Riverpod and go_router.

Everything from step 4 onward (camera capture, draft persistence,
area/element CRUD, AI integration, PDF generation) is intentionally out
of scope for this phase — see [architecture.md](architecture.md) for the
full list of deferred work.
