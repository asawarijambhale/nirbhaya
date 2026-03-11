import 'package:flutter/services.dart';

class SmsSender {
  static const platform = MethodChannel('com.nirbhaya/sos_sms');

  /// Send SMS automatically using native Android SmsManager
  static Future<bool> sendSMS({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final result = await platform.invokeMethod<bool>('sendSMS', {
        'phone': phoneNumber,
        'message': message,
      });
      return result ?? false;
    } catch (e) {
      print('Error sending SMS: $e');
      return false;
    }
  }

  /// Send SMS to multiple recipients
  static Future<Map<String, bool>> sendSMSBatch(
    List<String> phoneNumbers,
    String message,
  ) async {
    final results = <String, bool>{};

    for (String phone in phoneNumbers) {
      try {
        final success = await sendSMS(phoneNumber: phone, message: message);
        results[phone] = success;
      } catch (e) {
        print('Error sending to $phone: $e');
        results[phone] = false;
      }
    }

    return results;
  }
}
