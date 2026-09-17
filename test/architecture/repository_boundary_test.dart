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
      // Phase 8 additions — same rule: only the data layer may depend
      // on these SDKs directly.
      'package:firebase_analytics/firebase_analytics.dart',
      'package:firebase_crashlytics/firebase_crashlytics.dart',
      'package:firebase_app_check/firebase_app_check.dart',
      'package:cloud_functions/cloud_functions.dart',
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
      // PDF construction (Phase 7) — only PdfReportRenderer may build
      // PDF documents directly; UI/providers go through the
      // ReportCoordinator/ReportRenderer abstractions instead.
      // (report_screen.dart's use of package:printing's PdfPreview
      // widget to *display* an already-generated PDF is a UI concern,
      // not a domain leak, and is intentionally allowed.)
      'package:pdf/pdf.dart',
      'package:pdf/widgets.dart',
      // Real device connectivity (product-flow-closure pass) — UI/
      // providers depend on ConnectivityService (the abstraction),
      // never `connectivity_plus` directly.
      'package:connectivity_plus/connectivity_plus.dart',
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
    // an obvious "someone hardcoded a key" naming pattern, plus a
    // hardcoded `Authorization: Bearer ...` header. This is a pattern
    // scan, not a guarantee — but it fails loudly on the mistakes that
    // actually happen in practice.
    final aiProviderSecretPatterns = [
      RegExp(r'sk-[A-Za-z0-9]{20,}'), // OpenAI-style secret key
      RegExp(r'\bapiKey\s*[:=]\s*["\x27]sk-'),
      RegExp(
        r'(OPENAI|GEMINI|ANTHROPIC|DEEPSEEK)_API_KEY\s*[:=]\s*["\x27][^"\x27]+["\x27]',
        caseSensitive: false,
      ),
      // A hardcoded bearer token anywhere in app source — a real
      // provider/backend call must never embed one directly.
      RegExp(r'''Authorization['"]?\s*[:=]\s*['"]Bearer\s+[^'"$]{8,}'''),
    ];

    // `AIzaSy...`-shaped strings are Firebase/Google Cloud **client**
    // API keys — generated by `flutterfire configure`, meant to ship
    // inside a public app binary, and not a secret by Google's own
    // documentation (unlike every pattern above, which is always a
    // real, sensitive provider credential). `firebase_options.dart` is
    // the one file allowed to contain this shape; anywhere else, it
    // would be unexpected and still worth flagging.
    final googleClientKeyPattern = RegExp(r'AIzaSy[A-Za-z0-9_-]{33}');
    const firebaseClientConfigFile = 'firebase_options.dart';

    await for (final entity in libDir.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final relativePath = p.relative(entity.path, from: 'lib');
      final contents = await entity.readAsString();

      final hasAiProviderSecret = aiProviderSecretPatterns.any(
        (pattern) => pattern.hasMatch(contents),
      );
      final hasUnexpectedGoogleClientKey =
          relativePath != firebaseClientConfigFile &&
          googleClientKeyPattern.hasMatch(contents);

      if (hasAiProviderSecret || hasUnexpectedGoogleClientKey) {
        offenders.add(relativePath);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These files appear to contain a hardcoded AI provider API '
          'key, a hardcoded bearer token, or an unexpected Firebase/'
          'Google client key — provider secrets belong only in a '
          'backend gateway, never in Flutter source: $offenders',
    );
  });

  group('secret-scan pattern behavior (Part J regression coverage)', () {
    final googleClientKeyPattern = RegExp(r'AIzaSy[A-Za-z0-9_-]{33}');
    final deepseekKeyPattern = RegExp(
      r'(OPENAI|GEMINI|ANTHROPIC|DEEPSEEK)_API_KEY\s*[:=]\s*["\x27][^"\x27]+["\x27]',
      caseSensitive: false,
    );
    final bearerPattern = RegExp(
      r'''Authorization['"]?\s*[:=]\s*['"]Bearer\s+[^'"$]{8,}''',
    );

    test('a Firebase/Google client key shape is recognized (allowed only '
        'for firebase_options.dart, per the outer test)', () {
      expect(
        googleClientKeyPattern.hasMatch(
          "apiKey: 'AIzaSyCUbxMbg9Az0K1_u8HGbBO4NzbVT7mWLF8',",
        ),
        isTrue,
      );
    });

    test('a DeepSeek/OpenAI/Anthropic/Gemini key assignment is still '
        'blocked everywhere', () {
      expect(
        deepseekKeyPattern.hasMatch("DEEPSEEK_API_KEY = 'sk-fake-value-here'"),
        isTrue,
      );
      expect(
        deepseekKeyPattern.hasMatch(
          "const OPENAI_API_KEY: 'sk-fake-value-here'",
        ),
        isTrue,
      );
    });

    test('a hardcoded Authorization bearer token is still blocked', () {
      expect(
        bearerPattern.hasMatch(
          "headers: {'Authorization': 'Bearer sk-fake-token-value'}",
        ),
        isTrue,
      );
    });

    test('ordinary app code containing none of these shapes is not '
        'flagged', () {
      const ordinaryCode = '''
        class Example {
          final String label = 'Sign in';
          Future<void> call() async {}
        }
      ''';
      expect(googleClientKeyPattern.hasMatch(ordinaryCode), isFalse);
      expect(deepseekKeyPattern.hasMatch(ordinaryCode), isFalse);
      expect(bearerPattern.hasMatch(ordinaryCode), isFalse);
    });
  });
}
