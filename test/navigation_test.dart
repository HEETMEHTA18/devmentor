import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:devmentor/providers/app_state.dart';
import 'package:devmentor/routes/route_paths.dart';
import 'package:devmentor/screens/main_navigation_screen.dart';

void main() {
  testWidgets('Navigation tab query renders prompts tab', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'has_completed_walkthrough': true});
    final appState = AppState();

    final router = GoRouter(
      initialLocation: '/app?tab=prompts',
      routes: [
        GoRoute(
          path: '/app',
          builder: (context, state) {
            final tabName = state.uri.queryParameters['tab'];
            final tabIndex = RoutePaths.tabIndexFromName(tabName);
            return MainNavigationScreen(
              key: const ValueKey('main_nav'),
              initialTabIndex: tabIndex,
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    debugPrint(
      'PageView size in test: ${tester.getSize(find.byType(PageView))}',
    );

    expect(find.byType(PageView), findsOneWidget);
    final promptsTab = find.text('PROMPTS');
    expect(promptsTab, findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify that the prompts route mapping shows the prompts screen.
    expect(find.text('PROMPT INTELLIGENCE'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
  });
}
