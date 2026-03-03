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

// layar chat utama dengan tampilan percakapan ai.
// struktur: app bar (sticky) di atas, daftar pesan (scrollable) di tengah,
// input composer (mengambang) di bawah.
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
          // app bar sticky di atas
          ChatAppBar(
            onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
            onProfilePressed: () {
              Navigator.pushNamed(context, '/settings');
            },
            profileImageUrl: user?.photoURL,
          ),
          // daftar pesan dan input
          Expanded(
            child: Stack(
              children: [
                // area chat yang bisa di-scroll
                Consumer<ChatViewModel>(
                  builder: (context, vm, _) {
                    // tampilkan error snackbar sekali lalu clear
                    if (vm.lastError != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!context.mounted) return;
                        final error = vm.lastError;
                        final needsReLogin = vm.requiresReLogin;
                        vm.clearError();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(error ?? 'Terjadi kesalahan'),
                            backgroundColor: Colors.red[700],
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 4),
                            action: needsReLogin
                                ? SnackBarAction(
                                    label: 'Login Ulang',
                                    textColor: Colors.white,
                                    onPressed: () {
                                      Navigator.pushReplacementNamed(
                                          context, '/');
                                    },
                                  )
                                : null,
                          ),
                        );
                      });
                    }

                    final messages = vm.currentChat;
                    return ListView.builder(
                      controller: vm.scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 8,
                        bottom: 140,
                      ),
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      itemCount: messages.length + (vm.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length) {
                          return _buildTypingIndicator(context);
                        }
                        final msg = messages[index];
                        if (msg.sender == MessageSender.user) {
                          // hanya pesan user terakhir yang bisa diedit
                          // (seperti ChatGPT/Gemini mobile)
                          final isLast = _isLastUserMessage(messages, index);
                          return UserMessageBubble(
                            text: msg.text,
                            timestamp: msg.timestamp,
                            avatarUrl: user?.photoURL,
                            isLastUserMessage: isLast,
                            onEdit: (isLast && !vm.isLoading)
                                ? () => vm.editUserMessage(index)
                                : null,
                            onDelete: vm.isLoading
                                ? null
                                : () => vm.deleteMessage(index),
                          );
                        }
                        // cek apakah ini pesan AI terakhir
                        final isLastAi = _isLastAiMessage(messages, index);
                        return AiMessageBubble(
                          message: msg,
                          isLastAiMessage: isLastAi,
                          onRegenerate: (isLastAi && !vm.isLoading)
                              ? () => vm.regenerateLastResponse()
                              : null,
                          onDelete: vm.isLoading
                              ? null
                              : () => vm.deleteMessage(index),
                        );
                      },
                    );
                  },
                ),
                // input mengambang di bawah
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

  // cek apakah pesan pada index ini adalah user message terakhir di list
  bool _isLastUserMessage(List<MessageModel> messages, int index) {
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].sender == MessageSender.user) {
        return i == index;
      }
    }
    return false;
  }

  // cek apakah pesan pada index ini adalah ai message terakhir di list
  bool _isLastAiMessage(List<MessageModel> messages, int index) {
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].sender == MessageSender.ai) {
        return i == index;
      }
    }
    return false;
  }

  // indikator ketik ai (tiga titik animasi)
  static Widget _buildTypingIndicator(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // avatar ai
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

// animasi tiga titik indikator sedang mengetik
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