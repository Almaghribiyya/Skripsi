import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    serverClientId:
        '890020745806-6pbkspf5cfqsr8aajtgqeh8qkt16dvg6.apps.googleusercontent.com',
  );

  // pendaftaran dengan email dan password
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

  // login dengan email dan password
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

  // login dengan google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // mulai proses login google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // kalau pengguna membatalkan dialog login
      if (googleUser == null) return null;

      // dapatkan token autentikasi
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      // buat credential firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // login ke firebase pakai credential google
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  // logout
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}