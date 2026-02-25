import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_theme.dart';
import '../models/message_model.dart';
import '../viewmodels/chat_viewmodel.dart';
import 'widgets/chat/chat_app_bar.dart';
import 'widgets/chat/user_message_bubble.dart';
import 'widgets/chat/ai_message_bubble.dart';
import 'widgets/chat/chat_input_composer.dart';
import 'widgets/sidebar_menu.dart';

/// Main chat screen with modern AI-style conversation interface.
///
/// Structure:
///   ChatAppBar (sticky) → ChatMessageList (scrollable) → ChatInputComposer (floating bottom)
///
/// Uses [StatefulWidget] to properly manage the [ScaffoldState] key
/// across rebuilds (required for drawer integration).
class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const SidebarMenu(),
      body: Column(
        children: [
          // ── Sticky App Bar ──
          ChatAppBar(
            onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
            onProfilePressed: () {
              Navigator.pushNamed(context, '/settings');
            },
            profileImageUrl: user?.photoURL,
          ),
          // ── Message list + input ──
          Expanded(
            child: Stack(
              children: [
                // Scrollable chat area
                Consumer<ChatViewModel>(
                  builder: (context, vm, _) {
                    final messages = vm.currentChat;
                    return ListView.builder(
                      controller: vm.scrollController,
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 8,
                        bottom: 140, // space for floating input
                      ),
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      itemCount: messages.length + (vm.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Typing indicator
                        if (index == messages.length) {
                          return _buildTypingIndicator(context);
                        }
                        final msg = messages[index];
                        if (msg.sender == MessageSender.user) {
                          return UserMessageBubble(
                            text: msg.text,
                            timestamp: msg.timestamp,
                            avatarUrl: user?.photoURL,
                          );
                        }
                        return AiMessageBubble(message: msg);
                      },
                    );
                  },
                ),
                // Floating input at bottom
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ChatInputComposer(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// AI typing indicator (three animated dots).
  static Widget _buildTypingIndicator(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.20),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.bubbleAi
                  : AppColors.primary.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }
}

/// Animated three-dot typing indicator.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = (_ctrl.value - delay).clamp(0.0, 1.0);
            final opacity = 0.3 + 0.7 * (1 - (2 * t - 1).abs());
            return Padding(
              padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}