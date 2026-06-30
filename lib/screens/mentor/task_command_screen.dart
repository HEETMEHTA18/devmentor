import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/liquid_glass_button.dart';

class TaskCommandScreen extends StatefulWidget {
  const TaskCommandScreen({super.key});

  @override
  State<TaskCommandScreen> createState() => _TaskCommandScreenState();
}

enum TaskState { idle, planning, coding, testing, prCreation, done }

class _TaskCommandScreenState extends State<TaskCommandScreen> {
  final TextEditingController _taskController = TextEditingController();
  TaskState _currentState = TaskState.idle;
  String _selectedRepo = 'HeetMehta18/AutoDevs'; // Mock repo for now

  final List<String> _repos = [
    'HeetMehta18/AutoDevs',
    'HeetMehta18/DevMentor',
    'HeetMehta18/Portfolio',
  ];

  Future<void> _startTask() async {
    if (_taskController.text.isEmpty) return;
    
    final appState = Provider.of<AppState>(context, listen: false);

    setState(() {
      _currentState = TaskState.planning;
    });

    // Simulate agentic loop UI while calling the actual backend
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _currentState = TaskState.coding);
      
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() => _currentState = TaskState.testing);
      });
    });

    try {
      // Set the repo in AppState if needed or pass directly
      final parts = _selectedRepo.split('/');
      if (parts.length == 2) {
        appState.selectedRepoOwner = parts[0];
        appState.selectedRepoName = parts[1];
      }

      await appState.sendVoicePipelineCommand(_taskController.text);
      
      if (mounted) {
        setState(() {
          _currentState = TaskState.prCreation;
        });
        
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() => _currentState = TaskState.done);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentState = TaskState.idle;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to execute task: $e')),
        );
      }
    }
  }

  void _cancelTask() {
    setState(() {
      _currentState = TaskState.idle;
      _taskController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Tatvik Command Center',
          style: GoogleFonts.spaceMono(
            color: AppTheme.neonPurple,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textMain),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildContextSelector(),
            const SizedBox(height: 24),
            _buildPromptInput(),
            const SizedBox(height: 32),
            if (_currentState != TaskState.idle) _buildExecutionPlan(),
          ],
        ),
      ),
    );
  }

  Widget _buildContextSelector() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.folder_open_rounded, color: AppTheme.neonGreen),
          const SizedBox(width: 16),
          Text(
            'Target Context:',
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRepo,
                dropdownColor: AppTheme.surfaceElevated,
                isExpanded: true,
                icon: Icon(Icons.keyboard_arrow_down, color: AppTheme.accent),
                style: GoogleFonts.jetBrainsMono(color: AppTheme.textMain),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedRepo = newValue;
                    });
                  }
                },
                items: _repos.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptInput() {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Autonomous Task',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _taskController,
            maxLines: 4,
            enabled: _currentState == TaskState.idle,
            style: GoogleFonts.inter(color: AppTheme.textMain),
            decoration: InputDecoration(
              hintText: 'e.g., Add a dark mode toggle to the settings page...',
              hintStyle: GoogleFonts.inter(color: AppTheme.textSecondary),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.neonPurple),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              LiquidGlassButton(
                onPressed: _currentState == TaskState.idle ? _startTask : null,
                color: AppTheme.accent,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Execute Autonomously',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExecutionPlan() {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EXECUTION PLAN',
                style: GoogleFonts.spaceMono(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: AppTheme.neonGreen,
                ),
              ),
              if (_currentState != TaskState.done)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          _buildPlanStep(
            '① Analyze repo structure (.autodevs/prompt.md)',
            _currentState.index >= TaskState.planning.index,
            _currentState == TaskState.planning,
          ),
          const SizedBox(height: 16),
          _buildPlanStep(
            '② Generate implementation plan',
            _currentState.index >= TaskState.coding.index,
            _currentState == TaskState.coding,
          ),
          const SizedBox(height: 16),
          _buildPlanStep(
            '③ Write code changes autonomously',
            _currentState.index >= TaskState.testing.index,
            _currentState == TaskState.testing,
          ),
          const SizedBox(height: 16),
          _buildPlanStep(
            '④ Create PR with AI summary',
            _currentState.index >= TaskState.prCreation.index,
            _currentState == TaskState.prCreation,
          ),
          const SizedBox(height: 32),
          if (_currentState == TaskState.done)
            LiquidGlassButton(
              onPressed: _cancelTask,
              color: AppTheme.success.withValues(alpha: 0.2),
              child: Text(
                'View Pull Request',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.success,
                ),
              ),
            )
          else
            LiquidGlassButton(
              onPressed: _cancelTask,
              color: AppTheme.destructive.withValues(alpha: 0.2),
              child: Text(
                'Cancel Execution',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.destructive,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlanStep(String title, bool isCompleted, bool isActive) {
    Color textColor = AppTheme.textSecondary;
    IconData icon = Icons.circle_outlined;
    Color iconColor = AppTheme.textSecondary.withValues(alpha: 0.5);

    if (isCompleted && !isActive) {
      textColor = AppTheme.textMain;
      icon = Icons.check_circle_rounded;
      iconColor = AppTheme.neonGreen;
    } else if (isActive) {
      textColor = AppTheme.neonPurple;
      icon = Icons.play_circle_filled_rounded;
      iconColor = AppTheme.neonPurple;
    }

    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              color: textColor,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
