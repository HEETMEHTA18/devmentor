import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class DesktopScaffold extends StatefulWidget {
  final Widget centerFeed;
  final Widget rightContextPanel;
  
  const DesktopScaffold({
    super.key,
    required this.centerFeed,
    required this.rightContextPanel,
  });

  @override
  State<DesktopScaffold> createState() => _DesktopScaffoldState();
}

class _DesktopScaffoldState extends State<DesktopScaffold> {
  int _selectedIndex = 0;

  final List<String> _navItems = [
    'Home',
    'Learn',
    'Projects',
    'Career',
    'Pulse',
    'World',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          // Left Sidebar
          Container(
            width: 250,
            color: AppTheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'DevMentor',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMain,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(_navItems.length, (index) {
                  return ListTile(
                    selected: _selectedIndex == index,
                    selectedTileColor: AppTheme.accent.withValues(alpha: 0.1),
                    title: Text(
                      _navItems[index],
                      style: GoogleFonts.inter(
                        fontWeight: _selectedIndex == index ? FontWeight.w700 : FontWeight.w500,
                        color: _selectedIndex == index ? AppTheme.accent : AppTheme.textSecondary,
                      ),
                    ),
                    onTap: () => setState(() => _selectedIndex = index),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  );
                }),
              ],
            ),
          ),
          
          // Vertical Divider
          Container(width: 1, color: AppTheme.border.withValues(alpha: 0.2)),
          
          // Center Intelligence Feed
          Expanded(
            flex: 5,
            child: widget.centerFeed,
          ),
          
          // Vertical Divider
          Container(width: 1, color: AppTheme.border.withValues(alpha: 0.2)),

          // Right Context Panel (Tatvik Insights)
          Expanded(
            flex: 3,
            child: widget.rightContextPanel,
          ),
        ],
      ),
    );
  }
}
