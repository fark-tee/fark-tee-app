import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/debug/network_debug_button.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final GoRouter _router = buildAppRouter(context.read<AuthController>());

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'fark-tee',
      theme: AppTheme.dark,
      routerConfig: _router,
      builder: (context, child) {
        if (child == null || !kDebugMode) return child ?? const SizedBox.shrink();
        return Stack(children: [child, const NetworkDebugButton()]);
      },
    );
  }
}
