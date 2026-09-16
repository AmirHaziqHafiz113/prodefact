import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/data/remote/firebase_auth_service.dart';

/// Regression coverage for the live-testing defect: a sign-in attempt
/// (even with a freshly-reset, correct password) surfaced the raw
/// Firebase SDK string "The supplied auth credential is malformed or
/// has expired." — which is the SDK's own generic wording for
/// `invalid-credential`, a code Firebase now returns for wrong
/// password, a non-existent account, *and* a genuinely malformed/
/// expired credential alike (an anti-enumeration measure). Passing
/// that string straight to the user was the actual defect; this test
/// locks in the friendlier mapping instead.
void main() {
  test('invalid-credential (Firebase\'s merged wrong-password/no-account '
      'code) gets a clear, actionable message — never the SDK\'s own '
      '"malformed or has expired" wording', () {
    final message = friendlyMessageForAuthError('invalid-credential');
    expect(message, contains('email or password is incorrect'));
    expect(message, isNot(contains('malformed')));
    expect(message, isNot(contains('expired')));
  });

  test('wrong-password and user-not-found map to the same clear message '
      'as invalid-credential (Firebase already refuses to distinguish '
      'them for account-enumeration safety, so the UI should not pretend '
      'to either)', () {
    final wrongPassword = friendlyMessageForAuthError('wrong-password');
    final userNotFound = friendlyMessageForAuthError('user-not-found');
    final invalidCredential = friendlyMessageForAuthError('invalid-credential');
    expect(wrongPassword, invalidCredential);
    expect(userNotFound, invalidCredential);
  });

  test('invalid-email is distinguished from a wrong password', () {
    expect(
      friendlyMessageForAuthError('invalid-email'),
      contains('valid email'),
    );
  });

  test('network-request-failed points at connectivity, not credentials', () {
    expect(
      friendlyMessageForAuthError('network-request-failed'),
      contains('connection'),
    );
  });

  test('too-many-requests suggests waiting rather than blaming the '
      'password', () {
    expect(
      friendlyMessageForAuthError('too-many-requests'),
      contains('Too many attempts'),
    );
  });

  test('user-disabled is distinguished from a wrong password', () {
    expect(friendlyMessageForAuthError('user-disabled'), contains('disabled'));
  });

  test('email-already-in-use (sign-up) is distinguished from sign-in '
      'failures', () {
    expect(
      friendlyMessageForAuthError('email-already-in-use'),
      contains('already exists'),
    );
  });

  test('weak-password (sign-up) is distinguished from sign-in failures', () {
    expect(
      friendlyMessageForAuthError('weak-password'),
      contains('stronger password'),
    );
  });

  test('an unrecognized code still produces a safe, generic message '
      'rather than leaking the raw code', () {
    final message = friendlyMessageForAuthError('some-future-error-code');
    expect(message, isNot(contains('some-future-error-code')));
    expect(message, isNotEmpty);
  });
}
