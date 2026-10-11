# Google Drive backup of original photos

Firebase Storage remains **operational** storage: AI reads it, sync uses it, and
the app shows it. The inspector's own Google Drive becomes **long-term storage
for the original, full-resolution photo**. Firebase originals are **not**
deleted.

## Flow

```
Capture photo → save locally → finding saved → (sync uploads operational copy
to Firebase; AI runs) → photo enters the Drive queue → upload ORIGINAL to Drive
→ re-read from Drive (size + MD5) → driveBackupStatus = verified
```

- The queue entry is added after the finding is saved locally. Nothing waits on
  it: capture, AI, sync and report generation never block on Drive.
- Offline, Drive unavailable or not connected: the finding continues normally
  and the photo waits in the queue.

## Storage structure

```
ProDefact/
  Inspections/
    2026/
      <last 8 of inspection id> - <Property name>/
        <Area name>/
          20261011_<Area>_<evidenceId>.jpg
```

- Folders are found by a stable key in `appProperties.prodefactFolderKey`:
  `root`, `inspections`, `year:2026`, `inspection:<id>` and
  `area:<inspectionId>:<sectionId>`. They are never found by their display names.
- Files carry `appProperties`: `prodefactEvidenceId`, `prodefactInspectionId`,
  `prodefactFindingId` and `prodefactSectionId`.

## Per-photo state

The `DriveBackupRows` table (on device, schema v18) holds:

- `driveFileId`, `driveFolderId`
- `status`: `notStarted` / `queued` / `uploading` / `verified` / `failed`
- `backedUpAt`, `lastError` (a short safe code), `retryCount`, `nextAttemptAt`

After verification, the same fields are merged onto the cloud evidence document,
along with `firebaseOriginalPresent: true`, `driveVerified` and
`eligibleForCleanup: false`. OAuth tokens are **never** stored, neither in
Firestore nor in the local database.

## Auth

**Profile → Storage & Backup → Google Drive.** It shows the connected account,
connection status, the Auto Backup toggle, waiting and failed uploads, the last
successful sync, Retry now, and Connect/Reconnect/Disconnect.

- Uses `google_sign_in` 7 with **only** the
  `https://www.googleapis.com/auth/drive.file` scope. That gives access to files
  the app creates, not full Drive access.
- Access tokens come from the platform SDK on demand and are held in memory only.

### Build and project setup required before real use

1. In Google Cloud (the same project as Firebase):
   - Enable the **Google Drive API**.
   - Configure the OAuth consent screen and add the `drive.file` scope.
   - Create OAuth clients: Android (package plus SHA-1), iOS, and a **Web** client.
2. Build with the client ids. They are public identifiers, not secrets:
   `--dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>` (needed on Android)
   and `--dart-define=GOOGLE_IOS_CLIENT_ID=<iOS client id>`.
3. iOS: add the reversed client id URL scheme and `GIDClientID` to
   `ios/Runner/Info.plist`.

## Reliability

| Case | Behaviour |
|---|---|
| App restart | Queue is in the database; `uploading` rows become `queued` on start |
| Network loss or timeout | `failed` + exponential backoff (1, 2, 4 … min, capped at 6 h); retried automatically, or now via Retry |
| Connectivity regained | Queue processed again |
| Duplicate prevention | One row per photo (primary key). Before uploading, Drive is searched for the photo's `prodefactEvidenceId`, and an earlier upload is adopted. The file id is recorded before verifying |
| Auth expiry or revoked | Queue pauses (rows stay `queued`, no retry penalty); "Reconnect needed" |
| User disconnects Drive | Uploads stop; the queue is kept for a later reconnect |
| Verification mismatch | File id cleared, retried as a fresh upload |
| Photo or inspection deleted | Queue row removed (files already in Drive are the user's) |

## Firebase retention (prepared, not enabled)

`FirebaseRetentionPolicy` (`cleanupEnabled = false`) computes
`firebaseOriginalPresent`, `driveVerified` and `eligibleForCleanup`. A future
cleanup may only ever remove a Firebase original once all three of these hold:

- the Drive copy is verified,
- the retention period (default 180 days) has elapsed since verification,
- the policy is enabled.

Nothing in the app or functions deletes Firebase originals today.

## Past inspections

- **Firestore:** metadata.
- **Firebase / on-device copy:** what Past Inspection photos show first.
- **Drive:** the original. **View Original** downloads it from Drive. If Drive
  can't provide it (not backed up, offline, access expired), the viewer keeps
  showing the device copy and says so.
