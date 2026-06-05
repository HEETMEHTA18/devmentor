import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../widgets/liquid_glass_background.dart';
import '../widgets/glass_card.dart';
import '../providers/app_state.dart';
import 'home/home_screen.dart';
import 'repositories/discover_repos_screen.dart';
import 'roadmap/roadmap_screen.dart';
import 'profile/profile_screen.dart';
import 'prompts/prompt_hub_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const DiscoverReposScreen(),
    const PromptHubScreen(),
    const RoadmapScreen(),
    const ProfileScreen(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final state = GoRouterState.of(context);
      final username = state.uri.queryParameters['username'];
      final token = state.uri.queryParameters['token'];
      if (username != null && username.isNotEmpty && token != null && token.isNotEmpty) {
        final appState = Provider.of<AppState>(context, listen: false);
        if (appState.githubUsername != username) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            appState.setGithubSession(username, token);
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: _screens[_selectedIndex],
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 20),
            child: GlassCard(
              borderRadius: 30,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, 'HOME', Icons.grid_view_rounded),
                  _buildNavItem(1, 'EXPLORE', Icons.explore_outlined),
                  _buildNavItem(2, 'PROMPTS', Icons.psychology_outlined),
                  _buildNavItem(3, 'ROADMAP', Icons.route_outlined),
                  _buildNavItem(4, 'SETTINGS', Icons.settings_outlined),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildNavItem(int index, String label, IconData icon) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
            size: 24,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
