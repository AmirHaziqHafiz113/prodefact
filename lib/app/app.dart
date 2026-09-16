import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    return MaterialApp.router(
      title: 'ProDefact',
      theme: AppTheme.light,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
