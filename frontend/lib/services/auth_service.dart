import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    serverClientId:
        '890020745806-6pbkspf5cfqsr8aajtgqeh8qkt16dvg6.apps.googleusercontent.com',
  );

  // 1. Pendaftaran dengan Email & Password
  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
    } catch (e) {
      rethrow;
    }
  }

  // 2. Login dengan Email & Password
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
    } catch (e) {
      rethrow;
    }
  }

  // 3. Login dengan Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Mulai proses login Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // Jika pengguna membatalkan dialog login
      if (googleUser == null) return null;

      // Dapatkan token autentikasi
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      // Buat credential Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Login ke Firebase menggunakan credential Google
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  // 4. Logout
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}