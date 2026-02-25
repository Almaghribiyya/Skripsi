import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/message_model.dart';
import 'reference_card.dart';

class ChatBubble extends StatelessWidget {
  final MessageModel message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    bool isUser = message.sender == MessageSender.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0FB345).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF0FB345).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Color(0xFF0FB345), size: 16),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFF1A2E22)
                        : const Color(0xFF0FB345),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
          
          // Tombol Copy & Share untuk AI
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 8),
              child: Row(
                children: [
                  _actionButton(Icons.content_copy, "Copy", () {
                    Clipboard.setData(ClipboardData(text: message.text));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Teks berhasil disalin'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }),
                  const SizedBox(width: 12),
                  _actionButton(Icons.share, "Share", () {
                    Clipboard.setData(ClipboardData(text: message.text));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Teks disalin ke clipboard untuk dibagikan'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }),
                ],
              ),
            ),

          // Reference Card
          if (!isUser &&
              message.verseReferences != null &&
              message.verseReferences!.isNotEmpty)
            ...message.verseReferences!
                .map((ref) => ReferenceCard(reference: ref))
                ,
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}