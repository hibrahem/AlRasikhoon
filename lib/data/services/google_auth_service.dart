import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn;

  GoogleAuthService({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ?? GoogleSignIn(
          scopes: ['email'],
          // Client ID is required for web platform
          clientId: kIsWeb
              ? '276199755113-fo1e79rl9va8d0bdvkvntmn4h15lia4b.apps.googleusercontent.com'
              : null,
        );

  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        debugPrint('Google Sign-In: User cancelled');
      }
      return account;
    } catch (e, stackTrace) {
      debugPrint('Google Sign-In Error: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow; // Rethrow so the caller can handle and show the error
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  Future<GoogleSignInAuthentication?> getAuthentication(
      GoogleSignInAccount account) async {
    return await account.authentication;
  }

  bool get isSignedIn => _googleSignIn.currentUser != null;

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
}

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});
