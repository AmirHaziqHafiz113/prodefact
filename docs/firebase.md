# Firebase Integration (Phase 5)

ProDefact's local Drift database remains the durable, authoritative
store for active inspection work. Firebase is an optional cloud mirror
layered on top of it — never a requirement for basic operation. This
document covers the architecture, data model, sync lifecycle, and the
manual setup step required before any of it can actually reach a real
Firebase project.

## Architecture

```
UI / Riverpod
  -> ActiveInspectionSession (in-memory, write-through to local repo)
  -> InspectionRepository (local, Drift)      <- durable source of truth
  -> SyncCoordinator (application layer)
       -> InspectionRepository (local, read/mark-synced)
       -> CloudInspectionRepository (interface)
            -> FirestoreCloudInspectionRepository (Firebase impl)
  -> AuthService (interface)
       -> FirebaseAuthService (Firebase impl)
```

Nothing outside `lib/data/` imports `firebase_core`, `firebase_auth`,
`cloud_firestore`, or `firebase_storage`. The domain (`lib/core/`) and
UI (`lib/features/`, `lib/app/`) only ever see:

- `AuthUser` / `AuthService` (auth, generic)
- `CloudInspectionRepository` (remote persistence, generic)
- `SyncCoordinator` / `SyncResult` (orchestration, generic)

A test suite (`test/architecture/repository_boundary_test.dart`) checks
this boundary automatically, the same way it already checked that
Drift never leaked outside `lib/data/` in Phase 4.

## Auth

Email/password via Firebase Authentication — the simplest approach that
still gives real sign-in/sign-out/restore-on-restart semantics without
building a profile system. `authStateProvider` (a `StreamProvider`)
listens to `AuthService.authStateChanges()`, which Firebase itself
replays on app start, so auth state survives restarts for free.

**Updated**: signing in is optional only in **local-only/demo builds**
(no Firebase project configured — `firebaseReadyProvider` false).
Whenever Firebase *is* configured, authentication is a **hard gate** —
see `docs/production_readiness.md` ("Authentication hard gate"): no
inspection screen is reachable signed out at all, enforced by the
router's `redirect`, not merely by a soft "sync is disabled" state.

## Ownership & the "no cross-user visibility" rule

**Note on "guest" sessions after the hard gate**: the `ownerUid == null`
("guest") case described below can now only actually occur in local-
only/demo builds — once Firebase is configured, the hard gate above
means a session can never be *created* while signed out in the first
place (there's no reachable screen from which to create one), so
`ownerUid` is always set immediately in that mode. The claiming logic
remains in place and correct — it's simply unreachable in normal
operation once a real Firebase project is configured, rather than
removed, since a local-only build (which has no such gate) still
relies on it behaving exactly as documented.

Every local session has a nullable `ownerUid`:

- Created while **signed out** → `ownerUid = null` ("guest" session).
- Created while **signed in** → `ownerUid` = the current uid immediately.
- A guest session is **claimed** (`ownerUid` set) the first time it's
  *resumed* while signed in, or — as a defensive second path — the
  first time it's *synced* while signed in. Claiming never reassigns a
  session that already has a (possibly different) owner.

The sessions list (`sessionSummariesProvider`) and every sync operation
are scoped by the current auth state:

| Signed in as | Sees |
|---|---|
| nobody (signed out) | only unclaimed guest sessions |
| uid `U` | `U`'s own sessions **and** still-unclaimed guest sessions |

A session already claimed by a *different* user is never returned to
anyone else, on this device or any other. This is what satisfies
"anonymous inspection data must not accidentally become visible across
users" — the failure mode Phase 5 explicitly calls out. The one
deliberately-out-of-scope case: two different real accounts sharing one
device, each with their own guest sessions created before either signed
in — those still show to both until claimed. Proper per-user local data
partitioning is a future-phase concern, not a Phase 5 one.

## Firestore data model

```
users/{uid}/inspections/{inspectionId}
  industry, assetTypeId, status, createdAt, updatedAt

  /sections/{sectionId}
    name, isPlumbing, isIncluded, orderIndex, elements (array of {id, name, components[]})

  /findings/{findingId}
    sectionId, elementId, componentId, description, notes, status,
    createdAt, updatedAt

    /evidence/{evidenceId}
      mediaType, source, caption, storagePath, createdAt
```

Notes:

- Every collection lives under `users/{uid}` — this is both the sync
  scope and the security-rule boundary (see below).
- `sectionId`/`elementId`/`componentId` on a finding are *references*,
  not copies of section data — sections are the only source for
  element/component templates, so nothing is duplicated.
- Local Drift ids (session, section, finding, evidence) are reused
  directly as Firestore document ids. That's what makes sync idempotent
  — pushing the same local record twice **overwrites** the same
  document; it can never create a duplicate.
- `elements` is stored as a plain nested array/map on the section
  document (not a JSON string, unlike the local SQLite column) since
  Firestore documents support nested structures natively.

## Storage path model

```
users/{uid}/inspections/{inspectionId}/findings/{findingId}/{evidenceId}.jpg
```

Deterministic and scoped the same way Firestore is. The local
`Evidence.filePath` is **never overwritten or deleted** by a sync — only
`Evidence.storagePath` and `syncStatus` change once upload succeeds, so
the app keeps working from the local file regardless of network state.

## Sync lifecycle

`SyncCoordinator.syncSession(sessionId)`:

1. Require a signed-in user — otherwise return `unauthenticated`
   immediately without touching local *or* remote data.
2. Load the session locally; `sessionNotFound` if it's gone.
3. Refuse to touch a session owned by a different user (defense in
   depth beyond the UI already only offering sync for sessions the
   current user can see).
4. Claim the session if it was still unowned.
5. Push the session document, then all sections (full replace — mirrors
   how the local repository already treats configured areas), then
   each finding, then each finding's not-yet-synced evidence: upload
   the file to Storage, then write its metadata with the resulting
   `storagePath`, then mark it `synced` locally.
6. On success, mark the session `synced` locally.
7. On **any** exception, mark the session `pendingUpdate` locally and
   return `failure(message)` — local data (sections, findings,
   evidence, their local files) is left completely untouched. Nothing
   is deleted or corrupted by a failed sync; the next attempt (manual
   or triggered) simply re-pushes from the same local state.

This is why sync failure can never destroy local data: every local
mutation already happens before any network call, via the same
write-through path Phase 4 established. The coordinator only ever
*reads* local state to push it, and only ever *marks* sync status
locally — it never rewrites section/finding/evidence content based on
what it pushed or what the network returned.

### Idempotency & duplicate-record prevention

- Stable local ids as remote document ids (above) means re-running sync
  after a partial failure re-sends the same documents rather than
  creating new ones.
- `pushSections` explicitly deletes any remote section no longer present
  locally (in the same batch that (re)writes the current ones), so
  removed areas don't leave orphaned cloud records behind.

## Conflict policy

**Local always wins. Sync is one-directional: local → cloud, push-only.**
Phase 5 never reads inspection data back down from Firestore/Storage
into Drift. There is therefore no scenario where a stale remote value
can silently overwrite a newer local edit — the local repository is
never written to as a result of a sync push. The only theoretical
"conflict" is two devices signed in as the same user pushing the same
session id — whichever push lands last in Firestore simply wins,
`updatedAt` on every record documents when each write happened, so
timestamp-aware reconciliation is a straightforward addition for a
future phase (e.g. real multi-device use), not something Phase 5 needs
to solve given inspections are effectively single-device today.

## Sync triggers

- **Manual**: the "Sync now" cloud icon next to any session on the
  sessions list, and the same action while a session is active
  (`ActiveInspectionSession.syncNow()`). This is the required
  always-available entry point for testing.
- **After sign-in**: not automatic in Phase 5 — the inspector is shown
  their sessions and syncs explicitly, avoiding a surprise burst of
  network activity the moment auth state changes.
- **After completing physical inspection**: left as a manual step for
  the same reason; a natural place to *add* an automatic trigger in a
  later phase once real usage patterns are known.

No periodic/background sync loop exists — avoiding exactly the
"overly aggressive sync loops" the brief warns against.

## Connectivity

Phase 5 does not add connectivity detection. A sync attempt simply
succeeds or fails based on the real Firebase call outcome — which is
the authoritative signal either way, so a connectivity check would only
ever be a hint duplicating information the SDK already gives for free.

## Offline-first behavior

Every read/write in the app goes through `InspectionRepository`
(Drift) first, exactly as in Phase 4. `CloudInspectionRepository` calls
only ever happen inside `SyncCoordinator.syncSession`, invoked
explicitly by the user. This means:

- No internet → the app is fully usable; `syncSession` returns
  `failure` if invoked, local data is unaffected.
- Firebase temporarily unavailable → same as above.
- Storage upload fails mid-sync → the exception propagates to the
  `catch` in `syncSession`; findings/sections already pushed in that
  run stay pushed (Firestore writes are already committed), the
  session is marked `pendingUpdate`, and the local evidence file/row is
  untouched, so a retry re-attempts only what's left `!= synced`.
- Firestore write fails → same handling.

## Sync status UI

Each session in the list shows a small cloud icon
(`localOnly` / `pendingCreate` / `pendingUpdate` / `pendingDelete` →
"sync pending" / `synced`) plus its existing Unfinished/Completed chip,
and a "Sync now" button (disabled with an explanatory tooltip if the
inspector isn't signed in or doesn't own that session).

## Security rules

`firestore.rules` and `storage.rules` (repo root) both apply the same
rule: only `request.auth.uid == uid` may read or write anything under
`users/{uid}/...`, and everything else is denied by default. Deploy
with the Firebase CLI once a project is configured:

```
firebase deploy --only firestore:rules,storage:rules
```

This repository does **not** deploy rules automatically — that's a
manual, explicit step for whoever owns the Firebase project.

## Setup instructions (manual — required before cloud sync works)

This phase implements all the code Firebase integration needs, but it
cannot select or create a real Firebase project on your behalf — that
requires interactive Google account credentials this environment
doesn't have. `lib/firebase_options.dart` currently contains only
placeholder values (no real project, no real API keys — see the file
itself), and the app **detects this and runs in local-only mode**
(`main.dart` catches the resulting `Firebase.initializeApp` failure).

To connect a real project:

```sh
npm install -g firebase-tools        # or your preferred install method
firebase login
dart pub global activate flutterfire_cli
flutterfire configure
```

`flutterfire configure` will ask you to pick (or create) a Firebase
project and which platforms to generate config for, then it overwrites
`lib/firebase_options.dart` with real values — no other code changes
are required; every provider in `lib/data/remote/` already reads
`DefaultFirebaseOptions.currentPlatform` exactly as generated.

Then enable, in the Firebase console, for that project:

- **Authentication** → Sign-in method → Email/Password (enable it).
- **Firestore Database** → create a database (production mode is fine
  given the rules above).
- **Storage** → create a default bucket.

Then deploy the security rules in this repo:

```sh
firebase deploy --only firestore:rules,storage:rules
```

`google-services.json` (Android) / `GoogleService-Info.plist` (iOS) are
**not required** by this integration — the app initializes Firebase
purely from `DefaultFirebaseOptions` on every platform, so those files
were deliberately not added and the Android Gradle project does not
apply the `google-services` plugin. If you later add them for other
tooling (e.g. Crashlytics, which needs a later phase), note neither
file contains a secret per Firebase's own documentation — they're safe
to commit — but this repo does not depend on their presence either way.

## Deferred to later phases

- Any pull-based (cloud → local) sync or real conflict merging.
- Automatic/background sync triggers.

Firebase Crashlytics, Analytics, and App Check were added in Phase 8 —
see `docs/production_readiness.md` for their setup and policy; they
follow the exact same "optional, guarded, local-first-unaffected"
pattern as everything above.
- Multi-account-per-device local data partitioning.
