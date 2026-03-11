import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();

  PermissionService._internal();

  factory PermissionService() {
    return _instance;
  }

  /// Request phone permission
  Future<bool> requestPhonePermission() async {
    final status = await Permission.phone.request();
    return status.isGranted || status.isDenied;
  }

  /// Request SMS permission
  Future<bool> requestSMSPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted || status.isDenied;
  }

  /// Request location permission
  Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted || status.isDenied;
  }

  /// Request all emergency SOS permissions
  Future<Map<String, bool>> requestSOSPermissions() async {
    final phoneStatus = await Permission.phone.request();
    final smsStatus = await Permission.sms.request();
    final locationStatus = await Permission.location.request();

    return {
      'phone': phoneStatus.isGranted,
      'sms': smsStatus.isGranted,
      'location': locationStatus.isGranted,
    };
  }

  /// Check if all SOS permissions are granted
  Future<bool> hasSOSPermissions() async {
    final phoneGranted = await Permission.phone.isDenied;
    final smsGranted = await Permission.sms.isDenied;
    final locationGranted = await Permission.location.isDenied;

    return !phoneGranted && !smsGranted && !locationGranted;
  }

  /// Show permission denied dialog
  static void showPermissionDialog(
    BuildContext context,
    String title,
    String message,
    VoidCallback onOpenSettings,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onOpenSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
