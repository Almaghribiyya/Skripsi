import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // Stream untuk mendengarkan perubahan status login (Login/Logout)
  Stream<User?> get userStateStream => _auth.authStateChanges();

  // Inisialisasi GoogleSignIn (panggil sekali saat app startup)
  Future<void> initializeGoogleSignIn() async {
    await _googleSignIn.initialize();
  }

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
      // Mulai proses login Google (authenticate menggantikan signIn di v7)
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email'],
      );

      // Dapatkan idToken dari authentication
      final googleAuth = googleUser.authentication;

      // Dapatkan accessToken melalui authorizationClient
      final GoogleSignInClientAuthorization clientAuth =
          await googleUser.authorizationClient.authorizeScopes(['email']);

      // Buat credential Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: clientAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Login ke Firebase menggunakan credential Google
      return await _auth.signInWithCredential(credential);
    } on GoogleSignInException {
      // Jika pengguna membatalkan dialog login atau error lainnya
      return null;
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