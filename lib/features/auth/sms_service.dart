import 'package:flutter/services.dart';

/// Sends SMS via the existing native SmsManager channel.
class SmsService {
  static const _channel = MethodChannel('com.nirbhaya/sos_sms');

  static Future<bool> sendSms(String phone, String message) async {
    try {
      final result = await _channel.invokeMethod<bool>('sendSMS', {
        'phone': phone,
        'message': message,
      });
      return result == true;
    } catch (e) {
      return false;
    }
  }
}
