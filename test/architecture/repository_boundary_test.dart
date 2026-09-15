import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Asserts the architectural rules from the task: "UI/providers should
/// not query Drift directly" (Phase 4), "Firebase SDK types [must] not
/// leak through domain entities" (Phase 5), and "AI service/provider
/// types do not leak into UI/domain" / concrete AI provider SDKs must
/// never be called directly from Flutter UI (Phase 6).
///
/// Everything outside `lib/data/` must go through `InspectionRepository`
/// / `CloudInspectionRepository` / `AuthService` / `AiInspectionService`
/// / `AiReviewCoordinator`, never a concrete Drift, Firebase, or AI
/// provider implementation directly. `lib/main.dart` is the one
/// accepted exception: it's the composition root, and its only
/// Firebase-specific line is the single `Firebase.initializeApp(...)`
/// bootstrap call.
void main() {
  test('nothing outside lib/data (and the main.dart bootstrap) imports '
      'Drift, a Firebase SDK package, or a concrete AI implementation '
      'directly', () async {
    final libDir = Directory('lib');
    final offenders = <String>[];

    const disallowedImports = [
      'package:drift/drift.dart',
      'package:drift/native.dart',
      "'database.dart'",
      '"database.dart"',
      'package:firebase_core/firebase_core.dart',
      'package:firebase_auth/firebase_auth.dart',
      'package:cloud_firestore/cloud_firestore.dart',
      'package:firebase_storage/firebase_storage.dart',
      // Concrete AI implementations — UI/providers depend on
      // AiInspectionService/AiReviewCoordinator (the abstractions) or
      // the Riverpod provider file that wires them, never these.
      "'fake_ai_inspection_service.dart'",
      '"fake_ai_inspection_service.dart"',
      "'default_ai_review_coordinator.dart'",
      '"default_ai_review_coordinator.dart"',
      // No real AI provider SDK has been added yet — this fails loudly
      // the moment one is, if it's wired in from outside lib/data.
      'package:openai',
      'package:google_generative_ai',
      'package:dart_openai',
    ];

    const exemptPaths = {'main.dart', 'firebase_options.dart'};

    await for (final entity in libDir.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final relativePath = p.relative(entity.path, from: 'lib');
      // The data layer itself is allowed to depend on Drift/Firebase/AI
      // implementations directly — that's the whole point of the
      // boundary.
      if (p.split(relativePath).first == 'data') {
        continue;
      }
      if (exemptPaths.contains(relativePath)) {
        continue;
      }

      final contents = await entity.readAsString();
      final hasDisallowedImport = disallowedImports.any(contents.contains);
      if (hasDisallowedImport) {
        offenders.add(relativePath);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These files depend on Drift, a Firebase SDK package, or a '
          'concrete AI implementation directly instead of going '
          'through the repository/service abstractions: $offenders',
    );
  });

  test('no AI provider API key or secret exists anywhere in lib/', () async {
    final libDir = Directory('lib');
    final offenders = <String>[];

    // Recognizable secret-shaped prefixes for common AI providers, plus
    // an obvious "someone hardcoded a key" naming pattern. This is a
    // pattern scan, not a guarantee — but it fails loudly on the
    // mistakes that actually happen in practice.
    final suspiciousPatterns = [
      RegExp(r'sk-[A-Za-z0-9]{20,}'), // OpenAI-style secret key
      RegExp(r'AIzaSy[A-Za-z0-9_-]{33}'), // Google API key
      RegExp(r'\bapiKey\s*[:=]\s*["\x27]sk-'),
      RegExp(
        r'(OPENAI|GEMINI|ANTHROPIC|DEEPSEEK)_API_KEY\s*[:=]\s*["\x27][^"\x27]+["\x27]',
        caseSensitive: false,
      ),
    ];

    await for (final entity in libDir.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final contents = await entity.readAsString();
      if (suspiciousPatterns.any((pattern) => pattern.hasMatch(contents))) {
        offenders.add(p.relative(entity.path, from: 'lib'));
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These files appear to contain a hardcoded AI provider API '
          'key — provider keys belong only in a backend gateway, never '
          'in Flutter source: $offenders',
    );
  });
}
