import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../models/mentor_message.dart';
import '../../providers/app_state.dart';
import '../../widgets/liquid_glass_background.dart';
import '../../widgets/animated_copy_button.dart';
import '../../utils/speech_helper.dart';
import '../../widgets/liquid_glass_button.dart';

class MentorChatScreen extends StatefulWidget {
  const MentorChatScreen({super.key});

  @override
  State<MentorChatScreen> createState() => _MentorChatScreenState();
}

class _MentorChatScreenState extends State<MentorChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isListening = false;
  bool _hasText = false;
  String _previousText = '';
  int _lastMessageCount = 0;
  bool _lastTypingState = false;

  void _toggleListening(AppState state) {
    if (_isListening) {
      SpeechHelper.stopListening();
      setState(() {
        _isListening = false;
      });
    } else {
      SpeechHelper.startListening(
        onStart: () {
          setState(() {
            _isListening = true;
          });
        },
        onEnd: () {
          setState(() {
            _isListening = false;
          });
        },
        onResult: (text) {
          if (text.isNotEmpty) {
            _showVoicePipelineConfirmation(state, text);
          }
        },
        onError: (err) {
          setState(() {
            _isListening = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err),
              backgroundColor: Colors.redAccent,
            ),
          );
        },
      );
    }
  }

  void _showVoicePipelineConfirmation(AppState state, String transcript) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology_rounded, color: Colors.blueAccent, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Voice Project Creator',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'AI parsed your voice instructions as:',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  '"$transcript"',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.textMain,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This will generate .autodev/prompt.md specifications in your repository and start the autonomous agentic implementation loop.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(color: Colors.redAccent),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      state.sendVoicePipelineCommand(transcript);
                    },
                    child: Text(
                      'Trigger Pipeline',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyPress);
    _controller.addListener(_onTextChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appState = Provider.of<AppState>(context, listen: false);
      appState.addListener(_onAppStateChanged);
      _lastMessageCount = appState.chatMessages.length;
      _lastTypingState = appState.isMentorTyping;
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyPress);
    _controller.removeListener(_onTextChanged);
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.removeListener(_onAppStateChanged);
    } catch (_) {}
    _focusNode.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final currentText = _controller.text;
    
    // Update button active state dynamically like ChatGPT
    final textNotEmpty = currentText.trim().isNotEmpty;
    if (textNotEmpty != _hasText) {
      setState(() {
        _hasText = textNotEmpty;
      });
    }

    final diff = currentText.length - _previousText.length;
    if (diff > 8) {
      final addedText = currentText.substring(currentText.length - diff);
      // Heuristic to detect a paste operation (size change + whitespace/newline/special chars)
      final isPaste = diff > 20 || 
                      addedText.contains(' ') || 
                      addedText.contains('\n') || 
                      addedText.contains('{') || 
                      addedText.contains('/') ||
                      addedText.contains('.');
      if (isPaste) {
        _previousText = currentText;
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;
          final textToSend = _controller.text.trim();
          if (textToSend.isNotEmpty) {
            final appState = Provider.of<AppState>(context, listen: false);
            appState.sendMessage(textToSend);
            _controller.clear();
            _previousText = '';
            _scrollToBottom();
            _focusNode.requestFocus();
          }
        });
        return;
      }
    }
    _previousText = currentText;
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.chatMessages.length != _lastMessageCount ||
        appState.isMentorTyping != _lastTypingState) {
      _lastMessageCount = appState.chatMessages.length;
      _lastTypingState = appState.isMentorTyping;
      _scrollToBottom();
    }
  }

  bool _handleKeyPress(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;

      if (key == LogicalKeyboardKey.escape) {
        if (_focusNode.hasFocus) {
          _focusNode.unfocus();
          return true;
        }
      }

      if (!_focusNode.hasFocus) {
        final character = event.character;
        if (character != null && character.isNotEmpty) {
          _focusNode.requestFocus();
          final text = _controller.text + character;
          _controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
          return true;
        }
      }
    }
    return false;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final messages = appState.chatMessages;

    return LiquidGlassBackground(
      child: GestureDetector(
        onTap: () {
          if (_focusNode.hasFocus) {
            _focusNode.unfocus();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppTheme.textMain,
              ),
              onPressed: () => context.pop(),
            ),
            title: Column(
              children: [
                Text(
                  'AI Mentor',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMain,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildOsStatusPill('🧠 Cognee', const Color(0xFF6C63FF)),
                    const SizedBox(width: 6),
                    _buildOsStatusPill('🤖 OpenClaw', const Color(0xFF00BFA5)),
                  ],
                ),
              ],
            ),
            centerTitle: true,
          ),
          body: Column(
            children: [
              if (appState.lastUploadedResumeText != null &&
                  appState.lastUploadedResumeText!.isNotEmpty)
                _buildResumeStatusBar(appState),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification notification) {
                    if (notification is ScrollStartNotification) {
                      if (_focusNode.hasFocus) {
                        _focusNode.unfocus();
                      }
                    }
                    return false;
                  },
                  child: messages.isEmpty
                      ? _buildEmptyState(appState)
                      : ListView.builder(
                          controller: _scrollController,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            return Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 800,
                                ),
                                child: _buildMessageRow(msg, appState),
                              ),
                            );
                          },
                        ),
                ),
              ),
              if (appState.isMentorTyping)
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 4, bottom: 4),
                  child: Row(
                    children: [
                      const BouncingDotsIndicator(),
                      const SizedBox(width: 10),
                      Text(
                        'Tatvik is thinking...',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              _buildInputArea(appState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumeStatusBar(AppState state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: state.isGoogleDriveConnected
            ? AppTheme.accent.withValues(alpha: 0.08)
            : Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: state.isGoogleDriveConnected
              ? AppTheme.accent.withValues(alpha: 0.2)
              : Colors.amber.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_rounded,
                color: state.isGoogleDriveConnected
                    ? AppTheme.accent
                    : Colors.amber,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.lastUploadedResumeFileName ?? 'Active Resume PDF',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMain,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.isGoogleDriveConnected
                          ? 'Connected to Google Drive (${state.googleDriveEmail ?? ''})'
                          : 'Google Drive disconnected (saves locally)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: LiquidGlassButton.icon(
              onPressed: () => _showTailorBottomSheet(state),
              icon: const Icon(Icons.auto_awesome_rounded, size: 14),
              label: Text(
                'Tailor & Sync',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              color: AppTheme.accent,
              padding: const EdgeInsets.symmetric(vertical: 10),
              borderRadius: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showTailorBottomSheet(AppState state) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0E15),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Colors.white10, width: 0.5),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: AppTheme.accent),
                      const SizedBox(width: 12),
                      Text(
                        'Tailor Resume',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppTheme.textMain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Provide the target job details to automatically tailor your resume and sync the output to Google Drive.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: titleController,
                    style: TextStyle(color: AppTheme.textMain, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Job Title',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.accent),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Please enter job title'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descController,
                    style: TextStyle(color: AppTheme.textMain, fontSize: 14),
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Job Description',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      alignLabelWithHint: true,
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.accent),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Please enter job description'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      LiquidGlassButton(
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            Navigator.pop(context);
                            state.generateAndSyncResumeFromChat(
                              jobTitle: titleController.text.trim(),
                              jobDescription: descController.text.trim(),
                            );
                            _scrollToBottom();
                          }
                        },
                        color: AppTheme.accent,
                        borderRadius: 16,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: const Text('Tailor & Sync'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAttachmentOptions(AppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xEE0D0E15),
      elevation: 10,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Attachment Options',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.textMain,
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.accent.withValues(alpha: 0.15),
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: AppTheme.accent,
                    ),
                  ),
                  title: Text(
                    'Upload PDF Resume',
                    style: TextStyle(
                      color: AppTheme.textMain,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Upload a new resume to guide the mentoring sessions',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf'],
                      withData: true,
                    );
                    if (result != null && result.files.isNotEmpty) {
                      final file = result.files.first;
                      if (file.bytes != null) {
                        await state.sendPdfMessage(file.bytes!, file.name);
                        _scrollToBottom();
                      }
                    }
                  },
                ),
                const Divider(color: Colors.white12, height: 24),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: state.isGoogleDriveConnected
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.amber.withValues(alpha: 0.15),
                    child: Icon(
                      state.isGoogleDriveConnected
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                      color: state.isGoogleDriveConnected
                          ? Colors.green
                          : Colors.amber,
                    ),
                  ),
                  title: Text(
                    state.isGoogleDriveConnected
                        ? 'Google Drive Connected'
                        : 'Connect Google Drive',
                    style: TextStyle(
                      color: AppTheme.textMain,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    state.isGoogleDriveConnected
                        ? 'Email: ${state.googleDriveEmail ?? ''}'
                        : 'Connect Google Drive to auto-sync tailored resumes',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: state.isGoogleDriveConnected
                      ? null
                      : Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.textSecondary,
                        ),
                  onTap: () async {
                    Navigator.pop(context);
                    if (!state.isGoogleDriveConnected) {
                      final url = state.getGoogleDriveAuthorizeUrl();
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(AppState state) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.accent, AppTheme.secondaryAccent],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome_rounded, size: 24, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                'How can I help you?',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain,
                ),
                textAlign: TextAlign.center,
              ),
              _buildSuggestionGrid(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionGrid(AppState state) {
    final suggestions = [
      ('🔥', 'Roast my code', 'Get critical feedback on your repository style.'),
      ('🗺️', 'Explain my roadmap', 'Understand the next milestone in your career.'),
      ('💼', 'Mock interview prep', 'Challenge yourself with high-impact tech questions.'),
      ('💻', 'Suggest a project', 'Get real-world recommendations matching your stack.'),
      ('⚡', 'Execute a task', 'Let OpenClaw write code or create a PR for you.'),
      ('🖥️', 'Run terminal', 'Run a command in the agent sandbox environment.'),
    ];

    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: suggestions.map((s) {
            return _buildSuggestionChip(state, s.$1, s.$2, s.$3);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSuggestionChip(AppState state, String icon, String title, String desc) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          String cleanText = title;
          if (title == 'Roast my code') {
            cleanText = 'Roast my current code quality';
          } else if (title == 'Explain my roadmap') {
            cleanText = 'Explain my current roadmap milestone and what to do next';
          } else if (title == 'Mock interview prep') {
            cleanText = 'Give me a challenging technical mock interview question';
          } else if (title == 'Suggest a project') {
            cleanText = 'Suggest a real-world coding project based on my stack';
          } else if (title == 'Execute a task') {
            cleanText = 'Execute a task: add a /health endpoint that returns {status: ok} to my first synced repository';
          } else if (title == 'Run terminal') {
            cleanText = 'Run terminal command: echo Hello from OpenClaw agent';
          }
          state.sendMessage(cleanText);
          _scrollToBottom();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMain,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageRow(MentorMessage msg, AppState state) {
    final isUser = msg.role == MessageRole.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final userBubbleColor = isDark ? const Color(0xFF2A2A32) : const Color(0xFFF0F0F0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accent,
                          AppTheme.accent.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, size: 12, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Tatvik',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.accent.withValues(alpha: isDark ? 0.85 : 1.0)
                    : userBubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                border: isUser
                    ? null
                    : Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: msg.content,
                    onTapLink: (text, href, title) async {
                      if (href != null) {
                        final url = Uri.parse(href);
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      }
                    },
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: TextStyle(
                        color: isUser ? Colors.white : AppTheme.textMain,
                        fontSize: 15,
                        height: 1.5,
                      ),
                      a: TextStyle(
                        color: isUser ? Colors.white.withValues(alpha: 0.9) : AppTheme.accent,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.bold,
                      ),
                      code: TextStyle(
                        backgroundColor: isUser
                            ? Colors.white.withValues(alpha: 0.15)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05)),
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: isUser ? Colors.white : AppTheme.textMain,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: isUser
                            ? Colors.white.withValues(alpha: 0.05)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.03)
                                : Colors.black.withValues(alpha: 0.02)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.1)
                              : AppTheme.border,
                        ),
                      ),
                      h4: TextStyle(
                        color: isUser ? Colors.white : AppTheme.textMain,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      h3: TextStyle(
                        color: isUser ? Colors.white : AppTheme.textMain,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      h2: TextStyle(
                        color: isUser ? Colors.white : AppTheme.textMain,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                      h1: TextStyle(
                        color: isUser ? Colors.white : AppTheme.textMain,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      blockquote: TextStyle(
                        color: isUser
                            ? Colors.white.withValues(alpha: 0.8)
                            : AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      listBullet: TextStyle(
                        color: isUser ? Colors.white : AppTheme.textMain,
                      ),
                      strong: TextStyle(
                        color: isUser ? Colors.white : AppTheme.textMain,
                        fontWeight: FontWeight.bold,
                      ),
                      em: TextStyle(
                        color: isUser ? Colors.white : AppTheme.textMain,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  if (!isUser) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        AnimatedCopyButton(
                          text: msg.content,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.volume_up_rounded, size: 14),
                          color: AppTheme.textSecondary,
                          tooltip: 'Read Aloud',
                          onPressed: () => SpeechHelper.speak(msg.content),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    if (msg.openclawTask != null) ...[
                      const SizedBox(height: 12),
                      _buildOpenClawResultCard(msg.openclawTask!),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(AppState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isMobileBrowser =
        kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: isMobileBrowser ? 0.0 : 20.0,
              sigmaY: isMobileBrowser ? 0.0 : 20.0,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0x330D0E15)
                    : const Color(0x40FFFFFF),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppTheme.border, width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.attach_file_rounded,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                    tooltip: 'Attachment Options',
                    onPressed: () => _showAttachmentOptions(state),
                  ),
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: _isListening ? Colors.redAccent : AppTheme.textSecondary,
                      size: 20,
                    ),
                    tooltip: 'Voice Project Creator',
                    onPressed: () => _toggleListening(state),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: TextStyle(color: AppTheme.textMain, fontSize: 15),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText:
                            'Message AI Mentor or say "execute a task"...',
                        hintStyle: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          state.sendMessage(val.trim());
                          _controller.clear();
                          _scrollToBottom();
                          _focusNode.requestFocus();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                   GestureDetector(
                    onTap: () {
                      final text = _controller.text.trim();
                      if (text.isNotEmpty) {
                        state.sendMessage(text);
                        _controller.clear();
                        _scrollToBottom();
                        _focusNode.requestFocus();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _hasText ? AppTheme.accent : Colors.white10,
                        shape: BoxShape.circle,
                        boxShadow: _hasText
                            ? [
                                BoxShadow(
                                  color: AppTheme.accent.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: _hasText ? Colors.white : Colors.white38,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOsStatusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenClawResultCard(Map<String, dynamic> task) {
    final bool isStub = task['stub'] == true;
    final bool success = task['success'] == true;
    final String? prUrl = task['pull_request_url'];
    final String? output = task['output'];
    final String? error = task['error'];
    final Color cardColor = isStub
        ? const Color(0xFF00BFA5)
        : success
        ? const Color(0xFF00BFA5)
        : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smart_toy_rounded, color: cardColor, size: 16),
              const SizedBox(width: 8),
              Text(
                isStub
                    ? '🤖 OpenClaw (Stub Mode)'
                    : success
                    ? '🤖 OpenClaw Executed'
                    : '🤖 OpenClaw Error',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: cardColor,
                ),
              ),
            ],
          ),
          if (prUrl != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final uri = Uri.parse(prUrl);
                if (await canLaunchUrl(uri))
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: Text(
                '📎 View Pull Request: $prUrl',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: cardColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
          if (output != null) ...[
            const SizedBox(height: 8),
            Text(
              'Output: $output',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              'Error: $error',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.redAccent),
            ),
          ],
        ],
      ),
    );
  }
}

class BouncingDotsIndicator extends StatefulWidget {
  const BouncingDotsIndicator({super.key});

  @override
  State<BouncingDotsIndicator> createState() => _BouncingDotsIndicatorState();
}

class _BouncingDotsIndicatorState extends State<BouncingDotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double delay = index * 0.2;
            final double value = (sin((_controller.value * 2 * pi) - (delay * 2 * pi)) + 1) / 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.3 + 0.7 * value),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}
