import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../models/mentor_message.dart';
import '../../providers/app_state.dart';
import '../../widgets/liquid_glass_background.dart';
import '../../utils/speech_helper.dart';

class MentorChatScreen extends StatefulWidget {
  const MentorChatScreen({super.key});

  @override
  State<MentorChatScreen> createState() => _MentorChatScreenState();
}

class _MentorChatScreenState extends State<MentorChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyPress);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyPress);
    _focusNode.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
            title: Text('AI Mentor', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
          body: Column(
            children: [
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
                  child: ListView.builder(
                    controller: _scrollController,
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(24),
                    itemCount: appState.chatMessages.length,
                    itemBuilder: (context, index) {
                      final msg = appState.chatMessages[index];
                      return _buildMessageBubble(msg);
                    },
                  ),
                ),
              ),
              _buildSuggestionChips(appState),
              _buildInputArea(appState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionChips(AppState state) {
    final suggestions = [
      '🔥 Roast my code',
      '🗺️ Explain my roadmap',
      '💼 Mock interview prep',
      '💻 Suggest a project',
      '📐 Explain design patterns',
    ];

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final text = suggestions[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              visualDensity: VisualDensity.compact,
              label: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMain,
                ),
              ),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppTheme.border,
                  width: 1.0,
                ),
              ),
              onPressed: () {
                String cleanText = text;
                if (text.startsWith('🔥 ')) {
                  cleanText = 'Roast my current code quality';
                } else if (text.startsWith('🗺️ ')) {
                  cleanText = 'Explain my current roadmap milestone and what to do next';
                } else if (text.startsWith('💼 ')) {
                  cleanText = 'Give me a challenging technical mock interview question';
                } else if (text.startsWith('💻 ')) {
                  cleanText = 'Suggest a real-world coding project based on my stack';
                } else if (text.startsWith('📐 ')) {
                  cleanText = 'Explain a key software engineering design pattern with an example';
                }
                state.sendMessage(cleanText);
                _scrollToBottom();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(MentorMessage msg) {
    final isUser = msg.role == MessageRole.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isUser ? 20 : 0),
          bottomRight: Radius.circular(isUser ? 0 : 20),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: isUser ? 0 : 15, sigmaY: isUser ? 0 : 15),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              gradient: isUser
                  ? LinearGradient(
                      colors: [AppTheme.accent, AppTheme.accent.withValues(alpha: 0.85)],
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: isDark ? 0.08 : 0.45),
                        Colors.white.withValues(alpha: isDark ? 0.04 : 0.25),
                      ],
                    ),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isUser ? 20 : 0),
                bottomRight: Radius.circular(isUser ? 0 : 20),
              ),
              border: Border.all(
                color: isUser 
                    ? AppTheme.accent.withValues(alpha: 0.3) 
                    : AppTheme.border,
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                      height: 1.4,
                    ),
                    a: TextStyle(
                      color: isUser ? Colors.white : AppTheme.accent,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                    code: TextStyle(
                      backgroundColor: isUser 
                          ? Colors.white.withValues(alpha: 0.2) 
                          : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: isUser ? Colors.white : AppTheme.textMain,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: isUser 
                          ? Colors.white.withValues(alpha: 0.1) 
                          : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isUser 
                            ? Colors.white.withValues(alpha: 0.2) 
                            : AppTheme.border,
                      ),
                    ),
                  ),
                ),
                if (!isUser) ...[
                  const SizedBox(height: 6),
                  const Divider(color: Colors.white24, height: 1),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          color: AppTheme.textSecondary,
                          tooltip: 'Copy Response',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: msg.content));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied response to clipboard'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.volume_up_rounded, size: 14),
                          color: AppTheme.textSecondary,
                          tooltip: 'Read Aloud',
                          onPressed: () {
                            SpeechHelper.speak(msg.content);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(AppState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: isDark ? 0.08 : 0.45),
                Colors.white.withValues(alpha: isDark ? 0.04 : 0.25),
              ],
            ),
            border: Border(top: BorderSide(color: AppTheme.border, width: 1.0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: TextStyle(color: AppTheme.textMain),
                  decoration: InputDecoration(
                    hintText: 'Ask anything...',
                    hintStyle: TextStyle(color: AppTheme.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  onSubmitted: (val) {
                    state.sendMessage(val);
                    _controller.clear();
                    _scrollToBottom();
                    _focusNode.requestFocus();
                  },
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  state.sendMessage(_controller.text);
                  _controller.clear();
                  _scrollToBottom();
                  _focusNode.requestFocus();
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
