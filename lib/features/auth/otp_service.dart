import 'dart:math';

/// Stores OTP records in memory. Sufficient for single-session use.
class OtpRecord {
  final String otp;
  final DateTime createdAt;
  int attempts;

  OtpRecord({required this.otp, required this.createdAt, this.attempts = 0});

  bool get isExpired =>
      DateTime.now().difference(createdAt).inSeconds > 300; // 5 min
}

class OtpService {
  OtpService._();
  static final OtpService instance = OtpService._();

  final Map<String, OtpRecord> _store = {};

  static const int maxAttempts = 3;

  /// Generates a 6-digit OTP, stores it, and returns it.
  String generateOtp(String phone) {
    final otp = (100000 + Random().nextInt(900000)).toString();
    _store[phone] = OtpRecord(otp: otp, createdAt: DateTime.now());
    return otp;
  }

  /// Returns null on success, or an error string on failure.
  String? verifyOtp(String phone, String entered) {
    final record = _store[phone];
    if (record == null) return 'No OTP sent for this number';
    if (record.isExpired) {
      _store.remove(phone);
      return 'OTP expired. Please request a new one';
    }
    if (record.attempts >= maxAttempts) {
      return 'Too many attempts. Please request a new OTP';
    }
    record.attempts++;
    if (record.otp != entered.trim()) return 'Incorrect OTP';
    _store.remove(phone); // consume on success
    return null;
  }

  void clear(String phone) => _store.remove(phone);
}
