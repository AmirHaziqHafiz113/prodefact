import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home_inspection/providers/custom_catalogue_providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class ProDefactApp extends ConsumerStatefulWidget {
  const ProDefactApp({super.key});

  @override
  ConsumerState<ProDefactApp> createState() => _ProDefactAppState();
}

class _ProDefactAppState extends ConsumerState<ProDefactApp> {
  late final GoRouter _router = buildAppRouter(ref);

  @override
  Widget build(BuildContext context) {
    // Loads (and, per account, scopes) the company's custom catalogue as
    // soon as the app starts, so reports and selectors can resolve a
    // custom defect id from the first frame the data allows.
    ref.watch(customCatalogueProvider);
    return MaterialApp.router(
      title: 'ProDefact',
      theme: AppTheme.light,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
