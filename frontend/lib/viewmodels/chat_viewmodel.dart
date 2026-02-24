import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../services/nlp_service.dart';

class ChatViewModel extends ChangeNotifier {
  final TextEditingController textController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final NlpService _nlpService = NlpService();
  
  List<MessageModel> currentChat = [];
  bool isLoading = false;

  void sendMessage() async {
    final text = textController.text.trim();
    if (text.isEmpty) return;

    // Tambah pesan user
    currentChat.add(MessageModel(
      id: DateTime.now().toString(),
      text: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    ));
    
    textController.clear();
    isLoading = true;
    notifyListeners();
    _scrollToBottom();

    try {
      // Panggil NLP Service
      final response = await _nlpService.getAnswerFromVectorDB(text);
      
      List<VerseReference> refs = [];
      if (response['references'] != null) {
        refs = (response['references'] as List)
            .map((data) => VerseReference.fromJson(data))
            .toList();
      }

      // Tambah balasan AI
      currentChat.add(MessageModel(
        id: DateTime.now().toString(),
        text: response['answer'],
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
        verseReferences: refs,
      ));
    } catch (e) {
      currentChat.add(MessageModel(
        id: DateTime.now().toString(),
        text: "Maaf, terjadi kesalahan saat menghubungi server.",
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      ));
    } finally {
      isLoading = false;
      notifyListeners();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    textController.dispose();
    scrollController.dispose();
    super.dispose();
  }
}