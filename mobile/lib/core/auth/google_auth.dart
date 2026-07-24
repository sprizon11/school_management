import 'package:google_sign_in/google_sign_in.dart';

import '../config/api_config.dart';

/// Thin wrapper over google_sign_in (v7 singleton API). Returns a Google ID
/// token whose audience is the backend's web client id, so the server can
/// verify it against GOOGLE_CLIENT_IDS.
class GoogleAuthService {
  static bool _initialized = false;

  /// Runs the interactive Google sign-in and returns the ID token, or null if
  /// Google didn't supply one. Throws if Google sign-in isn't configured, and
  /// rethrows [GoogleSignInException] (e.g. the user cancelled).
  static Future<String?> signInGetIdToken() async {
    if (!ApiConfig.googleSignInEnabled) {
      throw StateError('Google sign-in is not configured');
    }
    final signIn = GoogleSignIn.instance;
    if (!_initialized) {
      await signIn.initialize(
        serverClientId: ApiConfig.googleServerClientId,
      );
      _initialized = true;
    }
    final account = await signIn.authenticate();
    return account.authentication.idToken;
  }

  static Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Best-effort; a failed Google sign-out shouldn't block app sign-out.
    }
  }
}
