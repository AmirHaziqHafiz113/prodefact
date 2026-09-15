/// Where a locally-persisted record stands relative to a future remote
/// backend. Phase 4 is local-only — nothing here is transmitted yet —
/// but records are shaped so a later sync phase can act on this field
/// without a schema change.
enum SyncStatus {
  /// Created and only ever intended to live locally so far; no sync
  /// attempt has been made.
  localOnly,

  /// Created locally and still waiting to be pushed to a remote backend.
  pendingCreate,

  /// Modified locally after a previous sync; the remote copy is stale.
  pendingUpdate,

  /// Deleted locally but the remote copy (if any) still needs removing.
  pendingDelete,

  /// Matches the remote backend as of the last successful sync.
  synced,
}
