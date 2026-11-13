import 'package:clerk_flutter/clerk_flutter.dart';

/// Supplies a fresh Clerk session token at request time.
abstract final class ClerkSessionProvider {
  static ClerkAuthState? _auth;

  static void bind(ClerkAuthState auth) => _auth = auth;

  static void clear() => _auth = null;

  static Future<String?> token() async {
    final auth = _auth;
    if (auth == null || !auth.isSignedIn) return null;
    final session = auth.session;
    if (session == null || !session.isActive ||
        !session.expireAt.isAfter(DateTime.now())) return null;
    try {
      final sessionToken = await auth.sessionToken();
      return sessionToken.isNotExpired ? sessionToken.jwt : null;
    } catch (_) {
      return null;
    }
  }
}
