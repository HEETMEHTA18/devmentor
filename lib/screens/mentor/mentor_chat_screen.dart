import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
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
  bool _showContextPanel = false;
  int _contextWindowTokens = 8000;

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
            title: Text(
              'AI Mentor',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: AppTheme.textMain,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(
                  _showContextPanel
                      ? Icons.memory_rounded
                      : Icons.memory_outlined,
                  color: _showContextPanel
                      ? AppTheme.accent
                      : AppTheme.textSecondary,
                ),
                tooltip: 'Context window',
                onPressed: () {
                  setState(() {
                    _showContextPanel = !_showContextPanel;
                  });
                },
              ),
            ],
          ),
          body: Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _showContextPanel
                    ? _buildContextWindowPanel(appState)
                    : const SizedBox.shrink(),
              ),
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
                            horizontal: 24,
                            vertical: 16,
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
              _buildInputArea(appState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppState state) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.accent, width: 2),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 36,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'How can I help you grow today?',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMain,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Ask about your roadmap, request a code roast, or practice interviews.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _buildSuggestionGrid(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionGrid(AppState state) {
    final suggestions = [
      {
        'icon': '🔥',
        'title': 'Roast my code',
        'desc': 'Get critical feedback on your repository style.',
      },
      {
        'icon': '🗺️',
        'title': 'Explain my roadmap',
        'desc': 'Understand the next milestone in your career.',
      },
      {
        'icon': '💼',
        'title': 'Mock interview prep',
        'desc': 'Challenge yourself with high-impact tech questions.',
      },
      {
        'icon': '💻',
        'title': 'Suggest a project',
        'desc': 'Get real-world recommendations matching your stack.',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2,
      ),
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final item = suggestions[index];
        return InkWell(
          onTap: () {
            String cleanText = item['title']!;
            if (cleanText == 'Roast my code') {
              cleanText = 'Roast my current code quality';
            } else if (cleanText == 'Explain my roadmap') {
              cleanText =
                  'Explain my current roadmap milestone and what to do next';
            } else if (cleanText == 'Mock interview prep') {
              cleanText =
                  'Give me a challenging technical mock interview question';
            } else if (cleanText == 'Suggest a project') {
              cleanText =
                  'Suggest a real-world coding project based on my stack';
            }
            state.sendMessage(
              cleanText,
              contextWindowTokens: _contextWindowTokens,
              clientContext: _buildClientContext(state),
            );
            _scrollToBottom();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: AppTheme.border, width: 1.0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Text(item['icon']!, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item['title']!,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    item['desc']!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageRow(MentorMessage msg, AppState state) {
    final isUser = msg.role == MessageRole.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isUser
                    ? Colors.white24
                    : AppTheme.accent.withValues(alpha: 0.5),
              ),
              gradient: isUser
                  ? const LinearGradient(
                      colors: [Color(0xFF2D3748), Color(0xFF1A202C)],
                    )
                  : LinearGradient(
                      colors: [
                        AppTheme.accent,
                        AppTheme.accent.withValues(alpha: 0.7),
                      ],
                    ),
            ),
            child: Center(
              child: isUser
                  ? Text(
                      state.username.isNotEmpty
                          ? state.username[0].toUpperCase()
                          : 'U',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
            ),
          ),
          const SizedBox(width: 16),
          // Content Area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sender Name
                Text(
                  isUser ? 'You' : 'DevMentor AI',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isUser ? AppTheme.textSecondary : AppTheme.accent,
                  ),
                ),
                const SizedBox(height: 6),
                // Markdown Content (ChatGPT styled: clean full-width, no card bubble background)
                MarkdownBody(
                  data: msg.content,
                  onTapLink: (text, href, title) async {
                    if (href != null) {
                      final url = Uri.parse(href);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    }
                  },
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                      .copyWith(
                        p: TextStyle(
                          color: AppTheme.textMain,
                          fontSize: 15,
                          height: 1.5,
                        ),
                        a: TextStyle(
                          color: AppTheme.accent,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.bold,
                        ),
                        code: TextStyle(
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05),
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: AppTheme.textMain,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.black.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                      ),
                ),
                if (!isUser) ...[
                  const SizedBox(height: 12),
                  // Chat Action Buttons (translucent, clean ChatGPT style)
                  Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.copy_rounded, size: 15),
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
                      const SizedBox(width: 8),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.volume_up_rounded, size: 15),
                        color: AppTheme.textSecondary,
                        tooltip: 'Read Aloud',
                        onPressed: () {
                          SpeechHelper.speak(msg.content);
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(AppState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0x0F0A0A0F) : const Color(0x0CFFFFFF),
            border: Border(top: BorderSide(color: AppTheme.border, width: 1.0)),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: TextStyle(color: AppTheme.textMain, fontSize: 15),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: 'Message AI Mentor...',
                        hintStyle: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 15,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0x1AFFFFFF)
                            : const Color(0x08000000),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          state.sendMessage(
                            val.trim(),
                            contextWindowTokens: _contextWindowTokens,
                            clientContext: _buildClientContext(state),
                          );
                          _controller.clear();
                          _scrollToBottom();
                          _focusNode.requestFocus();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      final text = _controller.text.trim();
                      if (text.isNotEmpty) {
                        state.sendMessage(
                          text,
                          contextWindowTokens: _contextWindowTokens,
                          clientContext: _buildClientContext(state),
                        );
                        _controller.clear();
                        _scrollToBottom();
                        _focusNode.requestFocus();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
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

  Widget _buildContextWindowPanel(AppState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tokenOptions = [4000, 8000, 32000, 128000];
    final recentMessages = state.chatMessages.reversed
        .take(6)
        .toList()
        .reversed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0x26111118)
                      : const Color(0x66FFFFFF),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.memory_rounded,
                          color: AppTheme.accent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Context Window',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMain,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${state.chatMessages.length} msgs',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tokenOptions.map((tokens) {
                        final selected = tokens == _contextWindowTokens;
                        return ChoiceChip(
                          label: Text(_formatTokens(tokens)),
                          selected: selected,
                          selectedColor: AppTheme.accent.withValues(
                            alpha: 0.22,
                          ),
                          backgroundColor: isDark
                              ? const Color(0x12FFFFFF)
                              : const Color(0x22FFFFFF),
                          side: BorderSide(
                            color: selected
                                ? AppTheme.accent
                                : AppTheme.border.withValues(alpha: 0.8),
                          ),
                          labelStyle: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AppTheme.accent
                                : AppTheme.textSecondary,
                          ),
                          onSelected: (_) {
                            setState(() {
                              _contextWindowTokens = tokens;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sent with every message: selected token budget, synced profile context, and the last few chat turns.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.4,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.key_rounded,
                          size: 15,
                          color: AppTheme.secondaryAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Free-key tip: use Gemini Flash-Lite for the best limited free quota, Groq for very fast chat, or OpenRouter when you want many free model choices.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              height: 1.4,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (recentMessages.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0x22000000)
                              : const Color(0x33FFFFFF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.border.withValues(alpha: 0.65),
                          ),
                        ),
                        child: Text(
                          recentMessages
                              .map(
                                (msg) =>
                                    '${msg.role == MessageRole.user ? 'You' : 'AI'}: ${_oneLine(msg.content)}',
                              )
                              .join('\n'),
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.firaCode(
                            fontSize: 11,
                            height: 1.35,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _buildClientContext(AppState state) {
    final recentMessages = state.chatMessages.reversed
        .take(8)
        .toList()
        .reversed
        .map(
          (msg) =>
              '${msg.role == MessageRole.user ? 'User' : 'Assistant'}: ${msg.content}',
        )
        .join('\n');

    return [
      'Preferred context window: $_contextWindowTokens tokens',
      if (state.githubUsername.isNotEmpty)
        'GitHub user: ${state.githubUsername}',
      if (state.roadmapTitle.isNotEmpty)
        'Current roadmap: ${state.roadmapTitle}',
      if (state.strengths.isNotEmpty)
        'Strengths: ${state.strengths.take(5).join(', ')}',
      if (state.gaps.isNotEmpty) 'Gaps: ${state.gaps.take(5).join(', ')}',
      if (recentMessages.isNotEmpty) 'Recent chat:\n$recentMessages',
    ].join('\n');
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000) return '${tokens ~/ 1000}K tokens';
    return '$tokens tokens';
  }

  String _oneLine(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 120) return compact;
    return '${compact.substring(0, 117)}...';
  }
}
