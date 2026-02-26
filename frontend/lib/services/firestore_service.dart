import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Menyimpan atau memperbarui profil pengguna di koleksi 'users'.
  /// Dipanggil setelah login/register berhasil.
  Future<void> saveUserProfile(User user) async {
    final docRef = _db.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (doc.exists) {
      // User lama → update lastLogin saja
      await docRef.update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } else {
      // User baru → buat profil lengkap
      await docRef.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'photoURL': user.photoURL ?? '',
        'provider': user.providerData.isNotEmpty
            ? user.providerData.first.providerId
            : 'unknown',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Mengambil data profil pengguna berdasarkan UID.
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  // ─── Chat Session Persistence ──────────────────────────────────────

  /// Referensi sub-koleksi chat_sessions milik user tertentu.
  CollectionReference<Map<String, dynamic>> _sessionsRef(String uid) =>
      _db.collection('users').doc(uid).collection('chat_sessions');

  /// Menyimpan atau memperbarui satu sesi obrolan ke Firestore.
  Future<void> saveChatSession(String uid, ChatSession session) async {
    await _sessionsRef(uid).doc(session.id).set(session.toJson());
  }

  /// Memuat semua sesi obrolan milik user, diurutkan berdasarkan createdAt (terbaru dulu).
  Future<List<ChatSession>> loadChatSessions(String uid) async {
    final snapshot = await _sessionsRef(uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => ChatSession.fromJson(doc.data()))
        .toList();
  }

  /// Menghapus satu sesi obrolan dari Firestore.
  Future<void> deleteChatSession(String uid, String sessionId) async {
    await _sessionsRef(uid).doc(sessionId).delete();
  }
}
