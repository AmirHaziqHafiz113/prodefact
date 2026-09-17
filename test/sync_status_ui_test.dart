import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/local/database_providers.dart';

import 'support/fake_auth_service.dart';
import 'support/fake_cloud_inspection_repository.dart';
import 'support/test_repository.dart';

void main() {
  testWidgets('the sessions list shows a sync status icon and a working '
      '"Sync now" action, signed in as a fake user', (tester) async {
    final cloud = FakeCloudInspectionRepository();
    final container = ProviderContainer(
      overrides: testOverridesWithSync(
        cloudRepository: cloud,
        authService: FakeAuthService(initialUser: testAuthUser),
      ),
    );
    addTearDown(container.dispose);

    // Seed one guest session directly through the repository so this
    // test doesn't need to drive the whole setup flow first.
    final repository = container.read(inspectionRepositoryProvider);
    final session = await repository.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: const [],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ProDefactApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Local-only before any sync.
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);

    // "Sync now" lives behind the card's "..." overflow menu now.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sync now'));
    await tester.pumpAndSettle();

    // The manual "Sync now" action reached the coordinator, which
    // pushed through the fake cloud repository...
    expect(cloud.pushedSessions.containsKey(session.id), isTrue);
    // ...and the list now reflects the synced state.
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
    expect(find.text('Synced.'), findsOneWidget);
  });
}
