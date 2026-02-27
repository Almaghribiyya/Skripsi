import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../config/app_theme.dart';
import '../../../viewmodels/chat_viewmodel.dart';

// area input pesan mengambang dengan backdrop blur dan auto-resize
class ChatInputComposer extends StatefulWidget {
  const ChatInputComposer({super.key});

  @override
  State<ChatInputComposer> createState() => _ChatInputComposerState();
}

class _ChatInputComposerState extends State<ChatInputComposer> {
  late final FocusNode _focusNode;
  bool _hasText = false;
  ChatViewModel? _vm;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _vm = context.read<ChatViewModel>();
      _vm!.textController.addListener(_onTextChanged);
      _hasText = _vm!.textController.text.trim().isNotEmpty;
    });
  }

  void _onTextChanged() {
    final has = (_vm?.textController.text.trim().isNotEmpty) ?? false;
    if (has != _hasText) {
      setState(() => _hasText = has);
    }
  }

  @override
  void dispose() {
    _vm?.textController.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final vm = context.read<ChatViewModel>();
    if (vm.textController.text.trim().isEmpty) return;
    vm.sendMessage();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.backgroundDark.withValues(alpha: 0.90)
            : AppColors.backgroundLight.withValues(alpha: 0.90),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 12 + (bottomInset > 0 ? 0 : MediaQuery.of(context).padding.bottom),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // banner mode edit
                Consumer<ChatViewModel>(
                  builder: (context, vm, _) {
                    if (!vm.isEditingMessage) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mengedit pesan',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => vm.cancelEditMode(),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: isDark
                                    ? AppColors.gray400
                                    : AppColors.gray500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // kontainer input
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.inputSurface : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.gray600 : AppColors.gray200,
                    ),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // kolom teks
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 128),
                          child: TextField(
                            controller:
                                context.read<ChatViewModel>().textController,
                            focusNode: _focusNode,
                            maxLines: null,
                            textInputAction: TextInputAction.newline,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: isDark ? Colors.white : AppColors.textDark,
                              height: 1.4,
                            ),
                            decoration: InputDecoration(
                              hintText: "Tanya Qur'an RAG",
                              hintStyle: GoogleFonts.inter(
                                fontSize: 16,
                                color: isDark
                                    ? AppColors.gray500
                                    : AppColors.gray400,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // tombol kirim / stop
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Consumer<ChatViewModel>(
                          builder: (context, vm, _) {
                            if (vm.isLoading) {
                              return _StopButton(
                                onPressed: () => vm.stopResponse(),
                              );
                            }
                            return _SendButton(
                              enabled: _hasText,
                              onPressed: _send,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // disclaimer
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Jawaban dihasilkan dari dataset Al-Qur\'an LPMQ Kemenag.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.gray500 : AppColors.gray400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// tombol kirim dengan animasi tekan
class _SendButton extends StatefulWidget {
  const _SendButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails _) {
    if (!widget.enabled) return;
    setState(() => _scale = 0.95);
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _scale = 1.0);
    if (widget.enabled) widget.onPressed();
  }

  void _onTapCancel() => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.enabled
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(8),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: const Icon(Icons.send, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// tombol stop saat AI sedang generate jawaban, ada animasi pulse
class _StopButton extends StatefulWidget {
  const _StopButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_StopButton> createState() => _StopButtonState();
}

class _StopButtonState extends State<_StopButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.15, end: 0.45).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => setState(() => _scale = 0.90);
  void _onTapUp(TapUpDetails _) {
    setState(() => _scale = 1.0);
    widget.onPressed();
  }

  void _onTapCancel() => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 80),
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, child) {
            return Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: _pulseAnim.value),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.stop, color: Colors.white, size: 22),
            );
          },
        ),
      ),
    );
  }
}
