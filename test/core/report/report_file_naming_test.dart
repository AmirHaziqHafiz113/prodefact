import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';

void main() {
  test('the filename is deterministic for the same session and date', () {
    final date = DateTime(2026, 3, 5);
    final first = buildReportFileName(sessionId: 'session_123', date: date);
    final second = buildReportFileName(sessionId: 'session_123', date: date);

    expect(first, second);
    expect(first, 'ProDefact_HomeInspection_session_123_20260305.pdf');
  });

  test('a different date produces a different filename', () {
    final a = buildReportFileName(
      sessionId: 'session_123',
      date: DateTime(2026, 3, 5),
    );
    final b = buildReportFileName(
      sessionId: 'session_123',
      date: DateTime(2026, 3, 6),
    );
    expect(a, isNot(b));
  });

  test('unsafe characters in the session id are sanitized', () {
    final name = buildReportFileName(
      sessionId: 'session/../weird id?.txt',
      date: DateTime(2026, 3, 5),
    );

    expect(name, isNot(contains('/')));
    expect(name, isNot(contains('?')));
    expect(name, isNot(contains(' ')));
    expect(name.endsWith('.pdf'), isTrue);
    expect(name.startsWith('ProDefact_HomeInspection_'), isTrue);
  });

  test('an empty session id still produces a valid filename', () {
    final name = buildReportFileName(sessionId: '', date: DateTime(2026, 3, 5));
    expect(name, 'ProDefact_HomeInspection_session_20260305.pdf');
  });
}
