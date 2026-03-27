import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Manages session persistence and user existence check.
class AuthService {
  static const _keyPhone     = 'auth_phone';
  static const _keyLoggedIn  = 'auth_logged_in';
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Session ──────────────────────────────────────────────────────────────

  static Future<void> saveSession(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPhone, phone);
    await prefs.setBool(_keyLoggedIn, true);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPhone);
    await prefs.remove(_keyLoggedIn);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLoggedIn) ?? false;
  }

  static Future<String?> getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPhone);
  }

  static String _sanitizePhoneAsDocId(String phone) {
    // Keep consistent with existing usage across the app
    return phone.replaceAll(RegExp(r'[^\w]'), '_');
  }

  /// Returns the current Firestore `users/<docId>` id.
  ///
  /// - Prefers FirebaseAuth uid (email auth flow).
  /// - Falls back to saved phone session (OTP flow).
  /// - Returns null if neither is available.
  static Future<String?> getCurrentUserDocId() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null && uid.trim().isNotEmpty) return uid.trim();

    final phone = await getPhone();
    if (phone == null || phone.trim().isEmpty) return null;
    return _sanitizePhoneAsDocId(phone.trim());
  }

  // ── Firestore user check ─────────────────────────────────────────────────

  /// Returns true if a user document exists and profile is completed.
  static Future<bool> userProfileExists(String phone) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .where('profileCompleted', isEqualTo: true)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Returns the Firestore doc id for a phone number, or null.
  static Future<String?> getUserDocId(String phone) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      return query.docs.isNotEmpty ? query.docs.first.id : null;
    } catch (_) {
      return null;
    }
  }
}
