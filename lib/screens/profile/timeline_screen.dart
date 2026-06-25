import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../widgets/glass_card.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  bool _isLoading = true;
  List<dynamic> _timeline = [];

  @override
  void initState() {
    super.initState();
    _fetchTimeline();
  }

  Future<void> _fetchTimeline() async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.token == null || appState.token!.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/timeline/?limit=50'),
        headers: {'Authorization': 'Bearer ${appState.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _timeline = data['timeline'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'prompt':
        return Icons.auto_awesome;
      case 'coding_session':
        return Icons.code;
      case 'repository':
        return Icons.book_outlined;
      case 'memory_graph':
        return Icons.memory;
      default:
        return Icons.history;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'prompt':
        return AppTheme.accent;
      case 'coding_session':
        return AppTheme.peach;
      case 'repository':
        return AppTheme.blue;
      case 'memory_graph':
        return AppTheme.success;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.isDark ? const Color(0xFF141414) : const Color(0xFFF0F0F5),
      appBar: AppBar(
        title: Text('Developer Timeline', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textMain)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textMain),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _timeline.isEmpty
              ? Center(
                  child: Text(
                    'No timeline events found.\nStart chatting or coding to build your history!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: _timeline.length,
                  itemBuilder: (context, index) {
                    final item = _timeline[index];
                    final type = item['type'] ?? 'unknown';
                    final dateStr = item['timestamp'] ?? '';
                    String displayDate = '';
                    if (dateStr.isNotEmpty) {
                      try {
                        final dt = DateTime.parse(dateStr).toLocal();
                        displayDate = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                      } catch (_) {
                        displayDate = dateStr;
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _getColorForType(type).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getIconForType(type),
                                  color: _getColorForType(type),
                                  size: 20,
                                ),
                              ),
                              if (index != _timeline.length - 1)
                                Container(
                                  width: 2,
                                  height: 60,
                                  color: AppTheme.border,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item['title'] ?? 'Event',
                                          style: TextStyle(
                                            color: AppTheme.textMain,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        displayDate,
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item['description'] ?? '',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                  if (type == 'prompt' && item['technologies'] != null && (item['technologies'] as List).isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12.0),
                                      child: Wrap(
                                        spacing: 8,
                                        children: (item['technologies'] as List).take(3).map((tech) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppTheme.accent.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              tech.toString(),
                                              style: TextStyle(color: AppTheme.accent, fontSize: 10),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
