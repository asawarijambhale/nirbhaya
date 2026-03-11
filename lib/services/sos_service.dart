import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sms_sender.dart';

class EmergencyContact {
  final String id;
  final String name;
  final String phoneNumber;
  final bool isPrimary;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.isPrimary = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'isPrimary': isPrimary,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      isPrimary: map['isPrimary'] ?? false,
    );
  }
}

class SOSService {
  static final SOSService _instance = SOSService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  SOSService._internal();

  factory SOSService() {
    return _instance;
  }

  String get userId => _auth.currentUser?.uid ?? '';

  /// Get user name from Firestore
  Future<String> getUserName() async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      return userData?['fullName'] ?? 'User';
    } catch (e) {
      print('Error loading user name: $e');
      return 'User';
    }
  }

  /// Add emergency contact
  Future<void> addEmergencyContact(EmergencyContact contact) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergencyContacts')
          .doc(contact.id)
          .set(contact.toMap());
    } catch (e) {
      throw Exception('Failed to add emergency contact: $e');
    }
  }

  /// Update emergency contact
  Future<void> updateEmergencyContact(EmergencyContact contact) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergencyContacts')
          .doc(contact.id)
          .update(contact.toMap());
    } catch (e) {
      throw Exception('Failed to update emergency contact: $e');
    }
  }

  /// Delete emergency contact
  Future<void> deleteEmergencyContact(String contactId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergencyContacts')
          .doc(contactId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete emergency contact: $e');
    }
  }

  /// Get all emergency contacts
  Stream<List<EmergencyContact>> getEmergencyContacts() {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('emergencyContacts')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => EmergencyContact.fromMap(doc.data()))
              .toList();
        });
  }

  /// Get current user location
  Future<Position> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
    } catch (e) {
      throw Exception('Failed to get location: $e');
    }
  }

  /// Generate Google Maps link from coordinates
  String generateMapsLink(double latitude, double longitude) {
    return 'https://maps.google.com/?q=$latitude,$longitude';
  }

  /// Validate and format phone number
  String cleanPhoneNumber(String phone) {
    // Remove all non-digit characters except + at the start
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // If it doesn't start with +, assume it's a local number
    if (!cleaned.startsWith('+')) {
      // Remove leading zeros if present
      if (cleaned.startsWith('0')) {
        cleaned = cleaned.substring(1);
      }
      // Add country code for India (default)
      cleaned = '+91$cleaned';
    }

    if (cleaned.isEmpty || cleaned.length < 10) {
      throw Exception('Invalid phone number format');
    }

    return cleaned;
  }

  /// Initiate emergency call - opens phone dialer
  Future<bool> initiateEmergencyCall(String phoneNumber) async {
    try {
      // Clean and validate phone number
      final cleanedNumber = cleanPhoneNumber(phoneNumber);
      print('Initiating call to: $cleanedNumber');

      // Create tel URI - this opens the phone dialer with pre-filled number
      final Uri launchUri = Uri(scheme: 'tel', path: cleanedNumber);

      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
        return true;
      } else {
        throw Exception('Phone dialer not available');
      }
    } catch (e) {
      print('Error initiating call: $e');
      return false;
    }
  }

  /// Send emergency SMS automatically (no user interaction)
  Future<bool> sendEmergencySMSAuto(
    String phoneNumber,
    String userName,
    double latitude,
    double longitude,
  ) async {
    try {
      final cleanedNumber = cleanPhoneNumber(phoneNumber);
      final mapsLink = generateMapsLink(latitude, longitude);

      final message =
          '🚨 EMERGENCY ALERT 🚨\n\n'
          'Name: $userName\n'
          'Status: I need IMMEDIATE help!\n\n'
          '📍 Location: $mapsLink\n\n'
          'Coordinates:\n'
          'Latitude: ${latitude.toStringAsFixed(6)}\n'
          'Longitude: ${longitude.toStringAsFixed(6)}\n\n'
          'Please contact me immediately or send help to this location!';

      final success = await SmsSender.sendSMS(
        phoneNumber: cleanedNumber,
        message: message,
      );

      print('SMS to $phoneNumber: ${success ? 'SUCCESS' : 'FAILED'}');
      return success;
    } catch (e) {
      print('Error sending SMS: $e');
      return false;
    }
  }

  /// Send emergency SMS to multiple contacts automatically
  Future<Map<String, bool>> sendEmergencySMSBatch(
    List<EmergencyContact> contacts,
    String userName,
    double latitude,
    double longitude,
  ) async {
    final results = <String, bool>{};
    final mapsLink = generateMapsLink(latitude, longitude);

    final message =
        '🚨 EMERGENCY ALERT 🚨\n\n'
        'Name: $userName\n'
        'Status: I need IMMEDIATE help!\n\n'
        '📍 Location: $mapsLink\n\n'
        'Coordinates:\n'
        'Latitude: ${latitude.toStringAsFixed(6)}\n'
        'Longitude: ${longitude.toStringAsFixed(6)}\n\n'
        'Please contact me immediately or send help to this location!';

    for (EmergencyContact contact in contacts) {
      try {
        final cleanedNumber = cleanPhoneNumber(contact.phoneNumber);
        final success = await SmsSender.sendSMS(
          phoneNumber: cleanedNumber,
          message: message,
        );
        results[contact.name] = success;
        print('SMS to ${contact.name}: ${success ? 'SUCCESS' : 'FAILED'}');
      } catch (e) {
        results[contact.name] = false;
        print('Exception sending to ${contact.name}: $e');
      }
    }

    return results;
  }

  /// Send emergency SMS via native app (shows UI)
  Future<void> sendEmergencySMS(
    String phoneNumber,
    String userName,
    double latitude,
    double longitude,
  ) async {
    try {
      final String message =
          'EMERGENCY ALERT from $userName!\nI am in danger. Please help.\nLocation: ${generateMapsLink(latitude, longitude)}';

      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        throw Exception('Could not launch SMS');
      }
    } catch (e) {
      throw Exception('Failed to send SMS: $e');
    }
  }

  /// Log SOS activity
  Future<void> logSOSActivity({
    required String status,
    required List<String> contactsNotified,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('sosLogs')
          .add({
            'timestamp': FieldValue.serverTimestamp(),
            'status': status,
            'contactsNotified': contactsNotified,
            'latitude': latitude,
            'longitude': longitude,
          });
    } catch (e) {
      throw Exception('Failed to log SOS activity: $e');
    }
  }

  /// Get SOS logs
  Stream<List<Map<String, dynamic>>> getSOSLogs() {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('sosLogs')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => doc.data()).toList();
        });
  }

  /// Trigger complete SOS alert - AUTO SMS + Backup calls
  Future<Map<String, dynamic>> triggerSOSAlert({
    required List<EmergencyContact> contacts,
    required String userName,
  }) async {
    final results = {
      'success': false,
      'sms_sent': <String>[],
      'sms_failed': <String>[],
      'calls_initiated': <String>[],
      'calls_failed': <String>[],
      'location': <double>[],
      'timestamp': DateTime.now().toString(),
    };

    try {
      if (contacts.isEmpty) {
        throw Exception('No emergency contacts available');
      }

      // Get current location
      Position position = await getCurrentLocation();
      results['location'] = [position.latitude, position.longitude];

      print('=== SOS ALERT TRIGGERED ===');
      print('Location: ${position.latitude}, ${position.longitude}');
      print('Total contacts: ${contacts.length}');

      // ===== STEP 1: SEND SMS AUTOMATICALLY (NO USER INTERACTION) =====
      print('\n--- STEP 1: Sending SMS automatically ---');
      final smsResults = await sendEmergencySMSBatch(
        contacts,
        userName,
        position.latitude,
        position.longitude,
      );

      List<String> smsSent = [];
      List<String> smsFailed = [];

      for (var entry in smsResults.entries) {
        if (entry.value) {
          smsSent.add(entry.key);
          print('✓ SMS sent to ${entry.key}');
        } else {
          smsFailed.add(entry.key);
          print('✗ SMS failed to ${entry.key}');
        }
      }

      results['sms_sent'] = smsSent;
      results['sms_failed'] = smsFailed;

      // ===== STEP 2: OPEN PHONE DIALERS AS BACKUP =====
      print('\n--- STEP 2: Opening phone dialers as backup ---');
      List<String> successfulCalls = [];
      List<String> failedCalls = [];

      for (EmergencyContact contact in contacts) {
        try {
          print('Opening dialer for: ${contact.name}');
          bool callSuccess = await initiateEmergencyCall(contact.phoneNumber);

          if (callSuccess) {
            successfulCalls.add(contact.name);
            print('✓ Dialer opened for ${contact.name}');
          } else {
            failedCalls.add(contact.name);
            print('✗ Failed to open dialer for ${contact.name}');
          }

          // Delay between dialers
          await Future.delayed(const Duration(seconds: 1));
        } catch (e) {
          failedCalls.add(contact.name);
          print('✗ Exception with ${contact.name}: $e');
        }
      }

      results['calls_initiated'] = successfulCalls;
      results['calls_failed'] = failedCalls;

      // ===== STEP 3: LOG TO FIREBASE =====
      print('\n--- STEP 3: Logging to Firebase ---');

      final mapsLink = generateMapsLink(position.latitude, position.longitude);

      // Log detailed SOS event with SMS delivery status
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('sosLogs')
          .add({
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'TRIGGERED',
            'smsStatus': smsSent.isNotEmpty ? 'SENT' : 'FAILED',
            'smsSent': smsSent,
            'smsFailed': smsFailed,
            'contactsNotified': smsSent,
            'callsInitiated': successfulCalls,
            'callsFailed': failedCalls,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'totalContacts': contacts.length,
            'successfulSMS': smsSent.length,
            'failedSMS': smsFailed.length,
            'successfulCalls': successfulCalls.length,
            'failedCalls': failedCalls.length,
            'mapsLink': mapsLink,
          });

      // Also log to sos_events for Twilio cloud function backup
      await _firestore.collection('sos_events').add({
        'timestamp': FieldValue.serverTimestamp(),
        'userId': userId,
        'userName': userName,
        'location': mapsLink,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'contacts': contacts
            .map((c) => {'name': c.name, 'phone': c.phoneNumber})
            .toList(),
        'status': 'triggered',
        'nativeSMSSent': smsSent.isNotEmpty,
        'smsSentCount': smsSent.length,
        'smsFailedCount': smsFailed.length,
      });

      results['success'] = smsSent.isNotEmpty || successfulCalls.isNotEmpty;

      print('\n=== SOS ALERT COMPLETE ===');
      print('SMS sent: ${smsSent.length}/${contacts.length}');
      print('Dialers opened: ${successfulCalls.length}/${contacts.length}');

      return results;
    } catch (e) {
      print('❌ Error in triggerSOSAlert: $e');
      results['failed'] = contacts.map((c) => c.name).toList();
      return results;
    }
  }
}
