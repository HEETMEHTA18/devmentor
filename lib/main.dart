import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_state.dart';
import 'routes/app_router.dart';

void main() {
  runApp(
    ProviderScope(
      child: p.ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const DevMentorApp(),
      ),
    ),
  );
}

class DevMentorApp extends StatelessWidget {
  const DevMentorApp({super.key});

  static final GoRouter _router = createAppRouter();

  @override
  Widget build(BuildContext context) {
    final appState = p.Provider.of<AppState>(context);
    AppTheme.isDark = appState.isDarkTheme;

    return MaterialApp.router(
      title: 'DevMentor',
      debugShowCheckedModeBanner: false,
      theme: appState.isDarkTheme ? AppTheme.darkTheme : AppTheme.lightTheme,
      routerConfig: _router,
    );
  }
}
