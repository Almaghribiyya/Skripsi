import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // simpan atau update profil pengguna di koleksi 'users'.
  // dipanggil setelah login atau register berhasil.
  Future<void> saveUserProfile(User user) async {
    final docRef = _db.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (doc.exists) {
      // user lama, update lastLogin saja
      await docRef.update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } else {
      // user baru, buat profil lengkap
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

  // ambil data profil pengguna berdasarkan uid
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  // penyimpanan sesi obrolan ke firestore

  // referensi sub-koleksi chat_sessions milik user tertentu
  CollectionReference<Map<String, dynamic>> _sessionsRef(String uid) =>
      _db.collection('users').doc(uid).collection('chat_sessions');

  // simpan atau update satu sesi obrolan ke firestore
  Future<void> saveChatSession(String uid, ChatSession session) async {
    await _sessionsRef(uid).doc(session.id).set(session.toJson());
  }

  // muat semua sesi obrolan milik user, urut dari terbaru
  Future<List<ChatSession>> loadChatSessions(String uid) async {
    final snapshot = await _sessionsRef(uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => ChatSession.fromJson(doc.data()))
        .toList();
  }

  // hapus satu sesi obrolan dari firestore
  Future<void> deleteChatSession(String uid, String sessionId) async {
    await _sessionsRef(uid).doc(sessionId).delete();
  }
}
