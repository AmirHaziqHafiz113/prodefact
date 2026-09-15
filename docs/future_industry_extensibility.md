# Future Industry Extensibility

ProDefact's long-term goal is a multi-industry inspection platform.
Phase 1 only ships Home Inspection UI, but the internal architecture is
built so other industries can plug into the same engine later.

## The generic concepts

`lib/core/inspection/` defines the industry-agnostic vocabulary the whole
platform is built on:

```
Industry            → Asset Type / Inspection Type
Inspection           → Section / Area
InspectionElement    → Component
Finding              → Evidence
AiSuggestion (AI Review)
Report
```

For Home Inspection these are presented to users under friendlier,
domain-specific names (never the generic technical terms):

| Generic concept | Home Inspection UI term |
|---|---|
| Industry | Home Inspection |
| Asset Type | High Rise / Landed |
| Inspection | Inspection |
| Section | Area |
| Element | Element |
| Component | Component |
| Finding | Defect |
| Evidence | Photos |
| AI Review | AI Review |
| Report | Report |

A future industry (e.g. automotive) would map the same generic concepts
onto its own vocabulary (e.g. Asset Type → Vehicle Model, Section →
Inspection Zone) without any changes to `core/inspection/`.

## How a new industry plugs in

1. Add a sibling module: `lib/features/<industry_name>/`, mirroring the
   shape of `lib/features/home_inspection/` — `config/`, `providers/`,
   `presentation/`.
2. Define that industry's `AssetType`s and default `Section` /
   `InspectionElement` / `Component` presets in its own `config/`,
   exactly as `home_inspection_config.dart` does today.
3. Add its own entry point screen(s) and register its routes in
   `app/router/app_router.dart`.
4. Reuse `core/inspection/` entities and (once built) the shared
   findings/evidence/AI-review/report machinery unchanged.

## What must stay generic vs. what is Home-Inspection-specific

- **Generic (in `core/`)**: the entity shapes, and — as they're built —
  the inspection engine's rules for recording findings, attaching
  evidence, running AI review, and generating reports.
- **Industry-specific (in `features/<industry>/`)**: which asset types
  exist, what the default sections/elements/components are, any
  industry-specific sequencing rules (e.g. Home Inspection's
  plumbing-areas-first rule), industry-specific report layout/branding,
  and all customer-facing terminology and screens.

Keeping this boundary strict is what lets Phase 1 ship Home-Inspection-
only UI today while leaving the core engine reusable for whichever
industry is added next — without a rewrite.
