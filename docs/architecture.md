# Architecture

ProDefact's Phase 1 foundation is a Flutter app with three layers, kept
deliberately separate so future industries can plug in without touching
the generic engine or each other.

```
lib/
  app/                     App shell: theme, routing, root widget.
  core/inspection/         Generic inspection engine/domain (industry-agnostic).
  features/home_inspection/ Home Inspection module: config + presentation.
```

## `lib/app/`

The composition root. `app.dart` builds the `MaterialApp.router`, wired to
`router/app_router.dart` (go_router) and `theme/app_theme.dart`. This layer
knows about screens from feature modules, but feature modules never import
from `app/` — dependencies point inward.

## `lib/core/inspection/` — generic inspection engine/domain

Plain Dart entities with no Flutter, Firebase, or industry-specific
dependencies:

| Entity | Purpose |
|---|---|
| `Industry` | Which vertical (home inspection today; automotive/industrial/etc. later) |
| `AssetType` | A kind of asset within an industry (e.g. a property type) |
| `Inspection` | Root aggregate for one inspection job |
| `Section` | A configurable area/zone of an inspection |
| `InspectionElement` | A physical element within a section (Floor, Wall, Door, ...) |
| `Component` | A sub-part of an element that can be individually assessed |
| `Finding` | A recorded defect/observation, saved as a draft |
| `Evidence` | A photo (or other evidence) attached to a finding |
| `AiSuggestion` | AI's advisory input for a finding, plus the inspector's accept/edit/reject decision |
| `Report` | The generated report for a completed inspection |

Nothing here mentions "High Rise", "Bathroom", or any Home Inspection
concept. This is what lets a future industry (e.g. automotive) define its
own configuration while reusing the same engine.

## `lib/features/home_inspection/` — Home Inspection module

Home Inspection specific configuration and UI, expressed in terms of the
generic domain above:

- `config/home_inspection_config.dart` — default `Section`/`InspectionElement`/
  `Component` presets for Home Inspection (see
  [home_inspection_workflow.md](home_inspection_workflow.md) for the
  exact area lists and ordering rules).
- `providers/home_inspection_providers.dart` — Riverpod providers exposing
  the selected property type and its derived default areas.
- `presentation/screens/` — `PropertyTypeSelectionScreen` (the High Rise /
  Landed entry point) and `AreaListScreen` (a read-only preview of the
  resulting default areas).

This module is the only place Home Inspection terminology appears in code
outside of docs and tests. A future industry would add a sibling
`lib/features/<industry>/` module in the same shape, without modifying
`core/`.

## State management: Riverpod

Vanilla `flutter_riverpod` providers (no code generation) are used for
foundation-phase state — currently just the selected property type and
the areas derived from it. This keeps the dependency surface small while
the app is this simple; more complex state (in-progress findings, AI
review state) can move to `Notifier`/`AsyncNotifier` providers as those
features are built.

## Routing: go_router

`app_router.dart` defines a small, flat route table:

| Path | Screen |
|---|---|
| `/` | `HomeShellScreen` — landing screen, Phase 1 only offers Home Inspection |
| `/home-inspection` | `PropertyTypeSelectionScreen` |
| `/home-inspection/areas` | `AreaListScreen` (read-only preview stub) |

## What this foundation intentionally does not include

Per the Phase 1 scope, the following are deferred and have no code yet:

- Firebase / any backend integration
- Real AI integration (only the `AiSuggestion` domain shape exists)
- PDF report generation
- Camera / photo capture
- The full physical inspection workflow (recording findings, drafts,
  include/exclude/add/remove/rename UI for areas)

See [home_inspection_workflow.md](home_inspection_workflow.md) for the
target workflow this foundation is built to support, and
[future_industry_extensibility.md](future_industry_extensibility.md) for
how new industries are expected to plug in later.
