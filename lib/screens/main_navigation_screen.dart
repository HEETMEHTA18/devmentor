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
  late PageController _pageController;
  double _pageOffset = 0.0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const DiscoverReposScreen(),
    const PromptHubScreen(),
    const RoadmapScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _selectedIndex = appState.currentTabIndex;
    _pageController = PageController(initialPage: _selectedIndex);
    _pageOffset = _selectedIndex.toDouble();
    _pageController.addListener(() {
      if (_pageController.hasClients) {
        setState(() {
          _pageOffset = _pageController.page ?? 0.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
    final double diff = (_pageOffset - _pageOffset.round()).abs();
    final double transitionProgress = (diff * 2.0).clamp(0.0, 1.0);

    return LiquidGlassBackground(
      transitionProgress: transitionProgress,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: PageView(
          controller: _pageController,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          onPageChanged: (index) {
            setState(() {
              _selectedIndex = index;
            });
            Provider.of<AppState>(context, listen: false).setTabIndex(index);
          },
          children: _screens,
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 20),
            child: GlassCard(
              borderRadius: 30,
              padding: EdgeInsets.zero,
              child: SizedBox(
                height: 70,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final totalWidth = constraints.maxWidth;
                    final itemWidth = totalWidth / 5;
                    return Stack(
                      children: [
                        // Sliding Glass Pill Indicator
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutBack,
                          left: _selectedIndex * itemWidth + 8,
                          top: 8,
                          bottom: 8,
                          width: itemWidth - 16,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.accent.withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        // The Items on Top
                        Positioned.fill(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildNavItem(0, 'HOME', Icons.grid_view_rounded, itemWidth),
                              _buildNavItem(1, 'EXPLORE', Icons.explore_outlined, itemWidth),
                              _buildNavItem(2, 'PROMPTS', Icons.psychology_outlined, itemWidth),
                              _buildNavItem(3, 'ROADMAP', Icons.route_outlined, itemWidth),
                              _buildNavItem(4, 'SETTINGS', Icons.settings_outlined, itemWidth),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon, double width) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        Provider.of<AppState>(context, listen: false).setTabIndex(index);
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
        );
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
