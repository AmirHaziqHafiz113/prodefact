import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/inspection/inspection_domain.dart';

/// Real device connectivity via `connectivity_plus` — the only file in
/// the app that imports it (see
/// `test/architecture/repository_boundary_test.dart`). A
/// [ConnectivityResult] list containing only `none` means genuinely
/// offline; anything else means at least one network interface is up
/// (which is not the same as "the internet actually works" — see
/// `ConnectivityService`'s doc comment).
class ConnectivityPlusService implements ConnectivityService {
  ConnectivityPlusService([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<ConnectivityStatus> checkStatus() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _statusFor(results);
    } catch (_) {
      // A platform channel failure shouldn't be treated as "definitely
      // offline" — fall back to unknown so callers don't wrongly block
      // work that would otherwise succeed.
      return ConnectivityStatus.unknown;
    }
  }

  @override
  Stream<ConnectivityStatus> statusChanges() {
    return _connectivity.onConnectivityChanged.map(_statusFor);
  }

  ConnectivityStatus _statusFor(List<ConnectivityResult> results) {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return ConnectivityStatus.offline;
    }
    return ConnectivityStatus.online;
  }
}
