import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sms_sender.dart';
import '../features/auth/auth_service.dart';

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

class PoliceOfficer {
  final String id;
  final String name;
  final String phoneNumber;
  final String city;
  final String vehicleNumber;

  PoliceOfficer({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.city,
    required this.vehicleNumber,
  });

  factory PoliceOfficer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PoliceOfficer(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      phoneNumber: (data['phoneNumber'] ?? '').toString(),
      city: (data['city'] ?? '').toString(),
      vehicleNumber: (data['vehicleNumber'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'city': city,
      'vehicleNumber': vehicleNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    };
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

  static const List<Map<String, String>> _dummyPoliceSeed = [
    {'name': 'Inspector Aarav', 'phoneNumber': '+919000000001', 'city': 'Solapur', 'vehicleNumber': 'MH01AB1001'},
    {'name': 'Inspector Diya', 'phoneNumber': '+919000000002', 'city': 'Delhi', 'vehicleNumber': 'DL01CD1002'},
    {'name': 'Inspector Kabir', 'phoneNumber': '+919000000003', 'city': 'Bengaluru', 'vehicleNumber': 'KA01EF1003'},
    {'name': 'Inspector Meera', 'phoneNumber': '+919000000004', 'city': 'Chennai', 'vehicleNumber': 'TN01GH1004'},
    {'name': 'Inspector Rohan', 'phoneNumber': '+919000000005', 'city': 'Kolkata', 'vehicleNumber': 'WB01IJ1005'},
    {'name': 'Inspector Nisha', 'phoneNumber': '+919000000006', 'city': 'Hyderabad', 'vehicleNumber': 'TS01KL1006'},
    {'name': 'Inspector Arjun', 'phoneNumber': '+919000000007', 'city': 'Pune', 'vehicleNumber': 'MH12MN1007'},
    {'name': 'Inspector Sana', 'phoneNumber': '+919000000008', 'city': 'Ahmedabad', 'vehicleNumber': 'GJ01OP1008'},
    {'name': 'Inspector Vihaan', 'phoneNumber': '+919000000009', 'city': 'Jaipur', 'vehicleNumber': 'RJ01QR1009'},
    {'name': 'Inspector Isha', 'phoneNumber': '+919000000010', 'city': 'Lucknow', 'vehicleNumber': 'UP32ST1010'},
    {'name': 'Inspector Reyansh', 'phoneNumber': '+919000000011', 'city': 'Bhopal', 'vehicleNumber': 'MP04UV1011'},
    {'name': 'Inspector Pooja', 'phoneNumber': '+919000000012', 'city': 'Indore', 'vehicleNumber': 'MP09WX1012'},
    {'name': 'Inspector Dev', 'phoneNumber': '+919000000013', 'city': 'Surat', 'vehicleNumber': 'GJ05YZ1013'},
    {'name': 'Inspector Neha', 'phoneNumber': '+919000000014', 'city': 'Nagpur', 'vehicleNumber': 'MH31AA1014'},
    {'name': 'Inspector Aditya', 'phoneNumber': '+919000000015', 'city': 'Patna', 'vehicleNumber': 'BR01BB1015'},
    {'name': 'Inspector Ananya', 'phoneNumber': '+919000000016', 'city': 'Kanpur', 'vehicleNumber': 'UP78CC1016'},
    {'name': 'Inspector Karan', 'phoneNumber': '+919000000017', 'city': 'Chandigarh', 'vehicleNumber': 'CH01DD1017'},
    {'name': 'Inspector Riya', 'phoneNumber': '+919000000018', 'city': 'Bhubaneswar', 'vehicleNumber': 'OD02EE1018'},
    {'name': 'Inspector Aman', 'phoneNumber': '+919000000019', 'city': 'Ranchi', 'vehicleNumber': 'JH01FF1019'},
    {'name': 'Inspector Tara', 'phoneNumber': '+919000000020', 'city': 'Guwahati', 'vehicleNumber': 'AS01GG1020'},
  ];

  Future<String> _requireUserDocId() async {
    final docId = await AuthService.getCurrentUserDocId();
    if (docId == null || docId.trim().isEmpty) {
      throw Exception('User not logged in');
    }
    return docId;
  }

  Future<String> _getUserPhone() async {
    final fromSession = await AuthService.getPhone();
    if (fromSession != null && fromSession.trim().isNotEmpty) {
      return fromSession.trim();
    }
    try {
      final userDocId = await _requireUserDocId();
      final userDoc = await _firestore.collection('users').doc(userDocId).get();
      final phone = userDoc.data()?['phone'];
      if (phone is String && phone.trim().isNotEmpty) return phone.trim();
    } catch (_) {}
    return '';
  }

  Future<void> seedPoliceTestDataIfNeeded() async {
    final existing = await _firestore.collection('police').limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = _firestore.batch();
    for (var i = 0; i < _dummyPoliceSeed.length; i++) {
      final data = _dummyPoliceSeed[i];
      final docRef = _firestore.collection('police').doc('police_${i + 1}');
      batch.set(docRef, {
        'name': data['name'],
        'phoneNumber': data['phoneNumber'],
        'city': data['city'],
        'vehicleNumber': data['vehicleNumber'],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Maps common geocoder spellings → seed `city` string in Firestore.
  static const Map<String, String> _cityAliasToCanonical = {
    'bangalore': 'Bengaluru',
    'bengaluru': 'Bengaluru',
    'new delhi': 'Delhi',
    'delhi': 'Delhi',
    'greater mumbai': 'Mumbai',
    'mumbai': 'Mumbai',
    'bombay': 'Mumbai',
    'gurugram': 'Delhi',
    'gurgaon': 'Delhi',
    'noida': 'Delhi',
    'thane': 'Mumbai',
    'solapur': 'Solapur',
  };

  static String _normCity(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Best-effort canonical city label for matching against `police.city`.
  String? _canonicalCityLabel(String raw) {
    final n = _normCity(raw);
    if (n.isEmpty) return null;
    if (_cityAliasToCanonical.containsKey(n)) {
      return _cityAliasToCanonical[n];
    }
    for (final prefix in ['greater ', 'new ']) {
      if (n.startsWith(prefix)) {
        final rest = n.substring(prefix.length);
        if (_cityAliasToCanonical.containsKey(rest)) {
          return _cityAliasToCanonical[rest];
        }
      }
    }
    // Title-case words for display / equality with seed data
    return raw.trim();
  }

  /// Returns distinct location strings from reverse geocoding to match police.
  Future<List<String>> _getCityCandidatesFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final places = await placemarkFromCoordinates(latitude, longitude);
      if (places.isEmpty) return [];
      final p = places.first;
      final out = <String>{};
      void add(String? s) {
        final t = (s ?? '').trim();
        if (t.isNotEmpty) out.add(t);
      }

      add(p.locality);
      add(p.subLocality);
      add(p.subAdministrativeArea);
      add(p.administrativeArea);
      // Some Android builds put city-like text here
      add(p.name);

      return out.toList();
    } catch (_) {
      return [];
    }
  }

  /// If reverse geocoding returns nothing, use city from user profile (testing / poor GPS).
  Future<List<String>> _mergeCityCandidatesWithUserProfile(
    List<String> fromGps,
  ) async {
    if (fromGps.isNotEmpty) return fromGps;
    try {
      final userDocId = await _requireUserDocId();
      final userDoc =
          await _firestore.collection('users').doc(userDocId).get();
      final data = userDoc.data();
      final homeCity = data?['homeCity'] ?? data?['city'];
      if (homeCity is String && homeCity.trim().isNotEmpty) {
        return [homeCity.trim()];
      }
      final addr = data?['homeAddress'];
      if (addr is String && addr.trim().isNotEmpty) {
        // Last comma-separated segment is often city (best-effort)
        final parts = addr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        if (parts.length >= 2) return [parts[parts.length - 2]];
      }
    } catch (_) {}
    return [];
  }

  Future<PoliceOfficer?> _findPoliceOfficerForCityCandidates(
    List<String> candidates,
  ) async {
    if (candidates.isEmpty) return null;

    final snap = await _firestore.collection('police').get();
    if (snap.docs.isEmpty) return null;

    final officers = snap.docs.map(PoliceOfficer.fromDoc).toList();

    bool cityMatches(String a, String b) {
      final ca = _canonicalCityLabel(a);
      final cb = _canonicalCityLabel(b);
      if (ca != null && cb != null && _normCity(ca) == _normCity(cb)) {
        return true;
      }
      final na = _normCity(a);
      final nb = _normCity(b);
      if (na.isEmpty || nb.isEmpty) return false;
      if (na == nb) return true;
      // "Solapur" vs "Solapur district" style
      if (na.contains(nb) || nb.contains(na)) return true;
      return false;
    }

    for (final c in candidates) {
      for (final o in officers) {
        if (cityMatches(c, o.city)) return o;
      }
    }
    return null;
  }

  Future<bool> _sendTwoSOSMessages({
    required String phoneNumber,
    required String userName,
    required String userPhone,
    required String mapsLink,
  }) async {
    final cleanedNumber = cleanPhoneNumber(phoneNumber);
    final alertMsg =
        'Emergency !! $userName ${userPhone.isNotEmpty ? "($userPhone) " : ""}is in danger , help her as early as possible';
    final locationMsg = 'Location - $mapsLink';

    final success1 = await SmsSender.sendSMS(
      phoneNumber: cleanedNumber,
      message: alertMsg,
    );
    await Future.delayed(const Duration(milliseconds: 120));
    final success2 = await SmsSender.sendSMS(
      phoneNumber: cleanedNumber,
      message: locationMsg,
    );
    return success1 && success2;
  }

  Future<void> _sendPoliceDetailsToUser({
    required PoliceOfficer officer,
    required String userPhone,
  }) async {
    if (userPhone.trim().isEmpty) return;
    final cleanedUser = cleanPhoneNumber(userPhone);
    final msg =
        'Police Assigned: ${officer.name}, Phone: ${officer.phoneNumber}, Vehicle: ${officer.vehicleNumber}';
    await SmsSender.sendSMS(
      phoneNumber: cleanedUser,
      message: msg,
    );
  }

  /// Get user name from Firestore
  Future<String> getUserName() async {
    try {
      final userDocId = await _requireUserDocId();
      final userDoc = await _firestore.collection('users').doc(userDocId).get();
      final userData = userDoc.data();
      final name = userData?['name'];
      if (name is String && name.trim().isNotEmpty) return name.trim();
      final fullName = userData?['fullName'];
      if (fullName is String && fullName.trim().isNotEmpty) return fullName.trim();
      final username = userData?['username'];
      if (username is String && username.trim().isNotEmpty) return username.trim();
      return 'User';
    } catch (e) {
      print('Error loading user name: $e');
      return 'User';
    }
  }

  /// Add emergency contact
  Future<void> addEmergencyContact(EmergencyContact contact) async {
    try {
      final userDocId = await _requireUserDocId();
      await _firestore
          .collection('users')
          .doc(userDocId)
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
      final userDocId = await _requireUserDocId();
      await _firestore
          .collection('users')
          .doc(userDocId)
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
      final userDocId = await _requireUserDocId();
      await _firestore
          .collection('users')
          .doc(userDocId)
          .collection('emergencyContacts')
          .doc(contactId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete emergency contact: $e');
    }
  }

  /// Get all emergency contacts
  Stream<List<EmergencyContact>> getEmergencyContacts() async* {
    final docId = await AuthService.getCurrentUserDocId();
    if (docId == null || docId.trim().isEmpty) {
      yield const <EmergencyContact>[];
      return;
    }

    yield* _firestore
        .collection('users')
        .doc(docId)
        .collection('emergencyContacts')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EmergencyContact.fromMap(doc.data()))
            .toList());
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
      final mapsLink = generateMapsLink(latitude, longitude);
      final userPhone = await _getUserPhone();
      final success = await _sendTwoSOSMessages(
        phoneNumber: phoneNumber,
        userName: userName,
        userPhone: userPhone,
        mapsLink: mapsLink,
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
    final userPhone = await _getUserPhone();

    for (EmergencyContact contact in contacts) {
      try {
        final success = await _sendTwoSOSMessages(
          phoneNumber: contact.phoneNumber,
          userName: userName,
          userPhone: userPhone,
          mapsLink: mapsLink,
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

  /// Send emergency SMS using the same standard SOS format.
  Future<void> sendEmergencySMS(
    String phoneNumber,
    String userName,
    double latitude,
    double longitude,
  ) async {
    try {
      final mapsLink = generateMapsLink(latitude, longitude);
      final userPhone = await _getUserPhone();
      await _sendTwoSOSMessages(
        phoneNumber: phoneNumber,
        userName: userName,
        userPhone: userPhone,
        mapsLink: mapsLink,
      );
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
      final userDocId = await _requireUserDocId();
      await _firestore
          .collection('users')
          .doc(userDocId)
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
  Stream<List<Map<String, dynamic>>> getSOSLogs() async* {
    final docId = await AuthService.getCurrentUserDocId();
    if (docId == null || docId.trim().isEmpty) {
      yield const <Map<String, dynamic>>[];
      return;
    }

    yield* _firestore
        .collection('users')
        .doc(docId)
        .collection('sosLogs')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Trigger SOS alert - SMS only (two messages)
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
      'user_city': '',
      'police_notified': null,
      'police_sms_sent': false,
      'timestamp': DateTime.now().toString(),
    };

    try {
      final userDocId = await _requireUserDocId();
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

      // ===== STEP 2: LOG TO FIREBASE =====
      print('\n--- STEP 2: Logging to Firebase ---');

      final mapsLink = generateMapsLink(position.latitude, position.longitude);
      await seedPoliceTestDataIfNeeded();
      results['user_city'] = '';

      PoliceOfficer? assignedPolice;
      bool policeSmsSent = false;

      // Randomly pick one police officer from DB (no city check).
      final policeSnap = await _firestore.collection('police').get();
      if (policeSnap.docs.isNotEmpty) {
        final officers = policeSnap.docs.map(PoliceOfficer.fromDoc).toList();
        officers.shuffle();
        assignedPolice = officers.first;

        results['police_notified'] = {
          'name': assignedPolice.name,
          'phoneNumber': assignedPolice.phoneNumber,
          'city': assignedPolice.city,
          'vehicleNumber': assignedPolice.vehicleNumber,
        };

        final userPhone = await _getUserPhone();
        policeSmsSent = await _sendTwoSOSMessages(
          phoneNumber: assignedPolice.phoneNumber,
          userName: userName,
          userPhone: userPhone,
          mapsLink: mapsLink,
        );
        results['police_sms_sent'] = policeSmsSent;

        // Send selected police details to the SOS sender by SMS.
        await _sendPoliceDetailsToUser(
          officer: assignedPolice,
          userPhone: userPhone,
        );
      }

      // Log detailed SOS event with SMS delivery status
      await _firestore
          .collection('users')
          .doc(userDocId)
          .collection('sosLogs')
          .add({
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'TRIGGERED',
            'smsStatus': smsSent.isNotEmpty ? 'SENT' : 'FAILED',
            'smsSent': smsSent,
            'smsFailed': smsFailed,
            'contactsNotified': smsSent,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'totalContacts': contacts.length,
            'successfulSMS': smsSent.length,
            'failedSMS': smsFailed.length,
            'mapsLink': mapsLink,
            'userCity': null,
            'userCityCandidates': const <String>[],
            'policeNotified': policeSmsSent,
            'police': assignedPolice == null
                ? null
                : {
                    'name': assignedPolice.name,
                    'phoneNumber': assignedPolice.phoneNumber,
                    'city': assignedPolice.city,
                    'vehicleNumber': assignedPolice.vehicleNumber,
                  },
          });

      // Also log to sos_events for Twilio cloud function backup
      await _firestore.collection('sos_events').add({
        'timestamp': FieldValue.serverTimestamp(),
        'userId': userDocId,
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
        'userCity': null,
        'userCityCandidates': const <String>[],
        'policeNotified': policeSmsSent,
        'police': assignedPolice == null
            ? null
            : {
                'name': assignedPolice.name,
                'phoneNumber': assignedPolice.phoneNumber,
                'city': assignedPolice.city,
                'vehicleNumber': assignedPolice.vehicleNumber,
              },
      });

      results['calls_initiated'] = <String>[];
      results['calls_failed'] = <String>[];
      results['success'] = smsSent.isNotEmpty;

      print('\n=== SOS ALERT COMPLETE ===');
      print('SMS sent: ${smsSent.length}/${contacts.length}');

      return results;
    } catch (e) {
      print('❌ Error in triggerSOSAlert: $e');
      results['failed'] = contacts.map((c) => c.name).toList();
      return results;
    }
  }
}
