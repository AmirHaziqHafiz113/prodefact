import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/photo_guide_screen.dart';

/// A new inspection now shows the photo guide once after setup; tests
/// that drive the setup wizard continue past it the way an inspector
/// does (its own "Start Inspection").
Future<void> passPhotoGuide(WidgetTester tester) async {
  final guide = find.byType(PhotoGuideScreen);
  if (guide.evaluate().isEmpty) return;
  await tester.tap(
    find.descendant(
      of: guide,
      matching: find.widgetWithText(FilledButton, 'Start Inspection'),
    ),
  );
  await tester.pumpAndSettle();
}
