import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';

void main() {
  testWidgets('app boots to the shell and can navigate into Home Inspection', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ProDefactApp()));
    await tester.pumpAndSettle();

    expect(find.text('ProDefact'), findsOneWidget);
    expect(find.text('Start Home Inspection'), findsOneWidget);

    await tester.tap(find.text('Start Home Inspection'));
    await tester.pumpAndSettle();

    expect(find.text('Select property type'), findsOneWidget);
    expect(find.text('High Rise'), findsOneWidget);
    expect(find.text('Landed'), findsOneWidget);
  });

  testWidgets(
    'selecting a property type shows its default areas, plumbing first',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: ProDefactApp()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Home Inspection'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Landed'));
      await tester.pumpAndSettle();

      expect(find.text('Landed Areas'), findsOneWidget);
      expect(find.text('Master Bathroom'), findsOneWidget);

      final firstListTile = tester.widget<ListTile>(
        find.byType(ListTile).first,
      );
      expect(firstListTile.subtitle, isNotNull);
      final subtitle = firstListTile.subtitle! as Text;
      expect(subtitle.data, 'Plumbing area — inspect first');

      await tester.scrollUntilVisible(
        find.text('Staircase'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Staircase'), findsOneWidget);
    },
  );
}
