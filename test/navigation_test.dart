import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:devmentor/providers/app_state.dart';
import 'package:devmentor/routes/route_paths.dart';
import 'package:devmentor/screens/main_navigation_screen.dart';

void main() {
  testWidgets('Navigation tab switching test', (WidgetTester tester) async {
    final appState = AppState();
    
    final router = GoRouter(
      initialLocation: '/app',
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
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    debugPrint('PageView size in test: ${tester.getSize(find.byType(PageView))}');
    
    // Expect Home screen to render
    expect(find.text('Dashboard'), findsOneWidget);
    
    await tester.pump(const Duration(seconds: 1));
    
    // Expect Home screen to render
    expect(find.text('Dashboard'), findsOneWidget);
    
    // Tap EXPLORE
    final exploreTab = find.text('EXPLORE');
    expect(exploreTab, findsOneWidget);
    await tester.tap(exploreTab);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    
    // Tap PROMPTS
    final promptsTab = find.text('PROMPTS');
    expect(promptsTab, findsOneWidget);
    await tester.tap(promptsTab);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    // Verify that the prompts screen is now showing
    expect(find.text('PROMPT INTELLIGENCE'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
  });
}
