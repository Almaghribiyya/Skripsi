import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/message_model.dart';
import '../services/nlp_service.dart';
import '../services/firestore_service.dart';

/// ViewModel utama untuk fitur chat.
///
/// Mengelola: multi-sesi, pengiriman pesan, loading state,
/// error handling yang terdiferensiasi, dan persistensi Firestore.
class ChatViewModel extends ChangeNotifier {
  final TextEditingController textController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final NlpService _nlpService = NlpService();
  final FirestoreService _firestoreService = FirestoreService();
  
  List<ChatSession> sessions = [];
  String? activeSessionId;
  bool isLoading = false;

  /// Pesan error terakhir — di-consume oleh UI untuk menampilkan SnackBar.
  /// Setelah ditampilkan, UI harus memanggil [clearError].
  String? lastError;

  /// Flag apakah error terakhir memerlukan re-login.
  bool requiresReLogin = false;

  /// Flag edit mode — true saat pengguna mengedit prompt lama.
  bool isEditingMessage = false;

  /// HTTP client aktif — untuk membatalkan request yang sedang berjalan.
  http.Client? _activeClient;

  String? _currentUid;

  List<MessageModel> get currentChat {
    if (activeSessionId == null) return [];
    final idx = sessions.indexWhere((s) => s.id == activeSessionId);
    if (idx == -1) return [];
    return sessions[idx].messages;
  }

  ChatViewModel() {
    createNewSession();
  }

  /// Reset error state setelah ditampilkan oleh UI.
  void clearError() {
    lastError = null;
    requiresReLogin = false;
  }

  /// Dipanggil setelah login berhasil. Memuat sesi obrolan dari Firestore.
  Future<void> loadUserSessions(String uid) async {
    _currentUid = uid;
    try {
      final loaded = await _firestoreService.loadChatSessions(uid);
      if (loaded.isNotEmpty) {
        sessions = loaded;
        activeSessionId = sessions.first.id;
      } else {
        if (sessions.isNotEmpty) {
          await _firestoreService.saveChatSession(uid, sessions.first);
        }
      }
    } catch (e) {
      debugPrint('Gagal memuat sesi obrolan: $e');
    }
    notifyListeners();
  }

  void createNewSession() {
    final newSession = ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: "Obrolan Baru",
      messages: [],
      createdAt: DateTime.now(),
    );
    sessions.insert(0, newSession);
    activeSessionId = newSession.id;
    notifyListeners();
    _saveSessionToFirestore(newSession);
  }

  void switchSession(String sessionId) {
    activeSessionId = sessionId;
    notifyListeners();
    _scrollToBottom();
  }

  void renameSession(String sessionId, String newTitle) {
    final sessionIndex = sessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex != -1 && newTitle.isNotEmpty) {
      sessions[sessionIndex].title = newTitle;
      notifyListeners();
      _saveSessionToFirestore(sessions[sessionIndex]);
    }
  }

  void deleteSession(String sessionId) {
    sessions.removeWhere((s) => s.id == sessionId);
    _deleteSessionFromFirestore(sessionId);
    if (sessions.isEmpty) {
      createNewSession();
    } else if (activeSessionId == sessionId) {
      activeSessionId = sessions.first.id;
    }
    notifyListeners();
  }

  void clearAllSessions() {
    sessions.clear();
    activeSessionId = null;
    _currentUid = null;
    textController.clear();
    isEditingMessage = false;
    createNewSession();
  }

  /// Edit prompt pengguna terakhir — mirip Gemini/ChatGPT mobile.
  ///
  /// Menghapus pesan user terakhir beserta respons AI-nya (jika ada),
  /// lalu memasukkan teks prompt ke input field agar bisa diedit.
  void editLastUserMessage() {
    if (activeSessionId == null) return;
    final sessionIndex = sessions.indexWhere((s) => s.id == activeSessionId);
    if (sessionIndex == -1) return;

    final messages = sessions[sessionIndex].messages;
    if (messages.isEmpty) return;

    // Cari user message paling akhir
    int lastUserIdx = -1;
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].sender == MessageSender.user) {
        lastUserIdx = i;
        break;
      }
    }
    if (lastUserIdx == -1) return;

    final editText = messages[lastUserIdx].text;

    // Hapus pesan dari lastUserIdx sampai akhir (user msg + AI response)
    messages.removeRange(lastUserIdx, messages.length);

    // Masukkan teks ke input field
    textController.text = editText;
    textController.selection = TextSelection.fromPosition(
      TextPosition(offset: editText.length),
    );

    isEditingMessage = true;
    notifyListeners();

    // Simpan perubahan ke Firestore
    _saveSessionToFirestore(sessions[sessionIndex]);
  }

  /// Batalkan mode edit.
  void cancelEditMode() {
    isEditingMessage = false;
    textController.clear();
    notifyListeners();
  }

  /// Menghentikan response yang sedang di-generate — mirip Gemini/ChatGPT.
  ///
  /// Menutup HTTP client aktif sehingga request dibatalkan,
  /// lalu menambahkan pesan AI partial "Response dihentikan".
  void stopResponse() {
    if (!isLoading || _activeClient == null) return;
    _activeClient!.close();
    _activeClient = null;
    // State akan di-update oleh catch block di sendMessage
  }

  void sendMessage() async {
    final text = textController.text.trim();
    if (text.isEmpty || activeSessionId == null) return;

    final targetSessionId = activeSessionId!;
    int sessionIndex = sessions.indexWhere((s) => s.id == targetSessionId);
    if (sessionIndex == -1) return;

    // Auto-title dari pesan pertama
    if (sessions[sessionIndex].messages.isEmpty) {
      sessions[sessionIndex].title =
          text.length > 25 ? "${text.substring(0, 25)}..." : text;
    }

    sessions[sessionIndex].messages.add(MessageModel(
      id: DateTime.now().toString(),
      text: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    ));
    
    textController.clear();
    isLoading = true;
    isEditingMessage = false;
    lastError = null;
    requiresReLogin = false;
    notifyListeners();
    _scrollToBottom();

    // Buat client baru untuk request ini (agar bisa di-cancel)
    _activeClient = http.Client();

    try {
      final response = await _nlpService.getAnswerFromVectorDB(
        text,
        client: _activeClient,
      );

      sessionIndex = sessions.indexWhere((s) => s.id == targetSessionId);
      if (sessionIndex == -1) return;

      List<VerseReference> refs = [];
      if (response['references'] != null) {
        refs = (response['references'] as List)
            .map((data) => VerseReference.fromJson(data))
            .toList();
      }

      sessions[sessionIndex].messages.add(MessageModel(
        id: DateTime.now().toString(),
        text: response['answer'],
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
        verseReferences: refs,
      ));

    } on NlpCancelledException {
      // User menekan tombol stop — tidak perlu menambah pesan error
      sessionIndex = sessions.indexWhere((s) => s.id == targetSessionId);
      if (sessionIndex == -1) return;

      sessions[sessionIndex].messages.add(MessageModel(
        id: DateTime.now().toString(),
        text: 'Response dihentikan.',
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      ));

    } on NlpException catch (e) {
      // Error terdiferensiasi dari NlpService
      sessionIndex = sessions.indexWhere((s) => s.id == targetSessionId);
      if (sessionIndex == -1) return;

      // Jika 401, flag untuk re-login
      if (e.statusCode == 401) {
        requiresReLogin = true;
        lastError = e.message;
      } else {
        lastError = e.message;
      }

      sessions[sessionIndex].messages.add(MessageModel(
        id: DateTime.now().toString(),
        text: e.message,
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      ));

    } catch (e) {
      // Fallback untuk error tak terduga
      sessionIndex = sessions.indexWhere((s) => s.id == targetSessionId);
      if (sessionIndex == -1) return;

      const fallbackMsg = "Maaf, terjadi kesalahan yang tidak terduga. "
          "Silakan coba lagi.";
      lastError = fallbackMsg;

      sessions[sessionIndex].messages.add(MessageModel(
        id: DateTime.now().toString(),
        text: fallbackMsg,
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      ));

    } finally {
      _activeClient = null;
      isLoading = false;
      notifyListeners();
      _scrollToBottom();

      sessionIndex = sessions.indexWhere((s) => s.id == targetSessionId);
      if (sessionIndex != -1) {
        _saveSessionToFirestore(sessions[sessionIndex]);
      }
    }
  }

  // ─── Firestore Helpers ──────────────────────────────────────────────

  /// Simpan satu sesi ke Firestore (non-blocking)
  void _saveSessionToFirestore(ChatSession session) {
    if (_currentUid == null) return;
    _firestoreService.saveChatSession(_currentUid!, session).catchError((e) {
      debugPrint('Gagal menyimpan sesi ke Firestore: $e');
    });
  }

  /// Hapus satu sesi dari Firestore (non-blocking)
  void _deleteSessionFromFirestore(String sessionId) {
    if (_currentUid == null) return;
    _firestoreService.deleteChatSession(_currentUid!, sessionId).catchError((e) {
      debugPrint('Gagal menghapus sesi dari Firestore: $e');
    });
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