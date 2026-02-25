import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../services/nlp_service.dart';

class ChatViewModel extends ChangeNotifier {
  final TextEditingController textController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final NlpService _nlpService = NlpService();
  
  // Perubahan: Mengelola multi-sesi
  List<ChatSession> sessions = [];
  String? activeSessionId;
  bool isLoading = false;

  // Mendapatkan percakapan untuk sesi yang sedang aktif
  List<MessageModel> get currentChat {
    if (activeSessionId == null) return [];
    final idx = sessions.indexWhere((s) => s.id == activeSessionId);
    if (idx == -1) return [];
    return sessions[idx].messages;
  }

  ChatViewModel() {
    // Buat sesi default saat aplikasi pertama kali dibuka
    createNewSession();
  }

  // Fitur 1: Membuat percakapan baru
  void createNewSession() {
    final newSession = ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: "Obrolan Baru",
      messages: [],
      createdAt: DateTime.now(),
    );
    sessions.insert(0, newSession); // Tambahkan di atas
    activeSessionId = newSession.id;
    notifyListeners();
  }

  // Berpindah sesi dari Sidebar
  void switchSession(String sessionId) {
    activeSessionId = sessionId;
    notifyListeners();
    _scrollToBottom();
  }

  // Fitur 2: Ganti nama sesi
  void renameSession(String sessionId, String newTitle) {
    final sessionIndex = sessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex != -1 && newTitle.isNotEmpty) {
      sessions[sessionIndex].title = newTitle;
      notifyListeners();
    }
  }

  // Fitur 2: Hapus sesi
  void deleteSession(String sessionId) {
    sessions.removeWhere((s) => s.id == sessionId);
    if (sessions.isEmpty) {
      createNewSession(); // Pastikan selalu ada minimal 1 sesi
    } else if (activeSessionId == sessionId) {
      activeSessionId = sessions.first.id; // Pindah ke sesi teratas
    }
    notifyListeners();
  }

  // Reset semua data saat logout
  void clearAllSessions() {
    sessions.clear();
    activeSessionId = null;
    textController.clear();
    createNewSession();
  }

  void sendMessage() async {
    final text = textController.text.trim();
    if (text.isEmpty || activeSessionId == null) return;

    // Capture the target session ID — use ID-based lookup throughout
    // to stay safe across async boundaries.
    final targetSessionId = activeSessionId!;

    int sessionIndex = sessions.indexWhere((s) => s.id == targetSessionId);
    if (sessionIndex == -1) return;

    // Ganti judul otomatis jika ini pesan pertama
    if (sessions[sessionIndex].messages.isEmpty) {
      sessions[sessionIndex].title = text.length > 20 ? "${text.substring(0, 20)}..." : text;
    }

    sessions[sessionIndex].messages.add(MessageModel(
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
      final response = await _nlpService.getAnswerFromVectorDB(text);

      // Re-lookup after async gap — session may have been deleted/reordered
      sessionIndex = sessions.indexWhere((s) => s.id == targetSessionId);
      if (sessionIndex == -1) return; // Session was deleted during request

      List<VerseReference> refs = [];
      if (response['references'] != null) {
        refs = (response['references'] as List).map((data) => VerseReference.fromJson(data)).toList();
      }

      sessions[sessionIndex].messages.add(MessageModel(
        id: DateTime.now().toString(),
        text: response['answer'],
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
        verseReferences: refs,
      ));
    } catch (e) {
      // Re-lookup after async gap
      sessionIndex = sessions.indexWhere((s) => s.id == targetSessionId);
      if (sessionIndex == -1) return;

      sessions[sessionIndex].messages.add(MessageModel(
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