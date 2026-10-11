import 'package:google_sign_in/google_sign_in.dart';

import '../../core/inspection/backup/drive_backup.dart';

/// OAuth client ids, supplied at build time (never committed secrets —
/// OAuth client ids are public identifiers). See docs/drive_backup.md:
/// `--dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>` (Android) and
/// `--dart-define=GOOGLE_IOS_CLIENT_ID=<iOS client id>` (iOS).
const _serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
const _iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

/// [DriveAuthService] backed by the platform Google Sign-In SDK. Requests
/// only [kDriveFileScope]. Access tokens are obtained on demand from the
/// SDK and kept in memory only — never written to Firestore or the
/// local database.
class GoogleSignInDriveAuth implements DriveAuthService {
  GoogleSignInDriveAuth({GoogleSignIn? signIn})
    : _signIn = signIn ?? GoogleSignIn.instance;

  final GoogleSignIn _signIn;
  Future<void>? _initialized;
  GoogleSignInAccount? _account;

  static const _scopes = [kDriveFileScope];

  Future<void> _ensureInitialized() {
    return _initialized ??= _signIn.initialize(
      clientId: _iosClientId.isEmpty ? null : _iosClientId,
      serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
    );
  }

  DriveAccount _toAccount(GoogleSignInAccount account) =>
      DriveAccount(email: account.email, displayName: account.displayName);

  @override
  Future<DriveAccount?> restore() async {
    await _ensureInitialized();
    final account = await _signIn.attemptLightweightAuthentication();
    if (account == null) return null;
    _account = account;
    return _toAccount(account);
  }

  @override
  Future<DriveAccount> connect() async {
    await _ensureInitialized();
    final account = await _signIn.authenticate(scopeHint: _scopes);
    // Authorization is separate from sign-in: explicitly grant the one
    // Drive scope (UI only if not already granted).
    await account.authorizationClient.authorizeScopes(_scopes);
    _account = account;
    return _toAccount(account);
  }

  @override
  Future<String> accessToken() async {
    await _ensureInitialized();
    var account = _account;
    if (account == null) {
      account = await _signIn.attemptLightweightAuthentication();
      _account = account;
    }
    if (account == null) throw const DriveAuthRequiredException();
    final authorization = await account.authorizationClient
        .authorizationForScopes(_scopes);
    if (authorization == null) {
      throw const DriveAuthRequiredException('scope_not_granted');
    }
    return authorization.accessToken;
  }

  @override
  Future<void> disconnect() async {
    await _ensureInitialized();
    _account = null;
    await _signIn.disconnect();
  }
}
