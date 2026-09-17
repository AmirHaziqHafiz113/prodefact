/// Real, device-level network reachability — distinct from (and a
/// signal feeding into, not a replacement for) "is the AI/sync backend
/// actually usable right now" (`isOnlineForAiProvider`), which also
/// requires being signed in. A network interface being up does not
/// guarantee working internet access (captive portals, a
/// misconfigured DNS, a server-side outage) — callers should treat
/// [offline] as a reliable "definitely can't reach anything" signal,
/// but still handle an actual request failure while [online]/[unknown]
/// gracefully rather than assuming success.
enum ConnectivityStatus { online, offline, unknown }

/// Kept as an abstraction (like `AuthService`/`EvidenceCaptureService`)
/// so UI/providers never depend on `connectivity_plus` directly, and so
/// tests can substitute a fake instead of driving real platform
/// connectivity events.
abstract class ConnectivityService {
  /// The current status, checked immediately (not from a cached/stale
  /// stream value).
  Future<ConnectivityStatus> checkStatus();

  /// Emits whenever device connectivity changes. Does not necessarily
  /// emit an initial value on subscription — callers that need a
  /// starting value should call [checkStatus] first.
  Stream<ConnectivityStatus> statusChanges();
}
