# Company custom catalogue

The ProDefact **master catalogue** (222 entries, controlled, shared) is never
modified by users. When an inspector can't find a defect or component, they
choose **Add New** in the defect selector; the entry goes to *their own*
catalogue only.

## Scope ("company")
There is no organisation/tenant model yet, so **a company is one signed-in
account**: entries live under `users/{uid}/customCatalogue/{id}` and are only
readable/writable by that uid (`firestore.rules`). Sharing a catalogue across
several inspectors of one company needs an organisation concept first.

## Behaviour
- Required: element, component, defect description, corrective action.
  Optional: note. Text is trimmed, whitespace-collapsed and `<` `>` stripped.
- Exact duplicates (same element + component + description, case-insensitive,
  against master *and* the account's own entries) are refused; a near-duplicate
  (same component, ≥80% shared words) warns but can be saved.
- Existing master element/component ids are reused when the names match;
  otherwise `custom_element.*` / `custom_component.*` ids are minted. Entry ids
  are `custom.<microseconds>` and can never shadow a master id.
- A saved entry is immediately searchable (including aliases), selectable, and
  used by reports with its own corrective action.
- Archiving hides an entry from search/selection; findings that already use it
  keep their wording.

## Storage
- Local: Drift `CustomDefectRows` (schema v17) is authoritative.
- Cloud: pushed on create/archive; **fetched and merged on sign-in / app start**
  so a fresh device restores the company's own entries. This is a deliberate,
  narrow exception to the otherwise push-only sync (`docs/firebase.md`).
- `DefectCatalogue.instance.replaceCustomEntries` is the in-memory overlay; it
  is cleared when there is no signed-in account or the account changes.

## Known limitation
**AI does not see custom entries.** The backend shortlist and validation use the
master catalogue only (one provider call, valid master ids only, no cross-account
leakage). Custom entries are chosen manually. Feeding an account's custom
entries into its AI shortlist needs the callable to load them per-uid and is a
follow-up.
