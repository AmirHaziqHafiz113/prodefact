import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

class ProDefactApp extends StatefulWidget {
  const ProDefactApp({super.key});

  @override
  State<ProDefactApp> createState() => _ProDefactAppState();
}

class _ProDefactAppState extends State<ProDefactApp> {
  late final GoRouter _router = buildAppRouter();

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
