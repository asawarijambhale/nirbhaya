import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/sos_service.dart';

class SOSScreenNew extends StatefulWidget {
  const SOSScreenNew({super.key});

  @override
  State<SOSScreenNew> createState() => _SOSScreenNewState();
}

class _SOSScreenNewState extends State<SOSScreenNew>
    with TickerProviderStateMixin {
  final SOSService _sosService = SOSService();
  bool _isCountdownActive = false;
  int _countdownSeconds = 15;
  late AnimationController _pulseController;
  late AnimationController _countdownController;
  Timer? _countdownTimer;
  List<EmergencyContact> _emergencyContacts = [];
  String _userName = '';

  @override
void initState() {
  super.initState();
  _initializePulseAnimation();
  _requestPermissions();
  _loadEmergencyContacts();
  _loadUserName();
}

  void _initializePulseAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _countdownController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    );
  }

  Future<void> _requestPermissions() async {
    await Permission.sms.request();
    await Permission.location.request();
  }

  Future<void> _loadUserName() async {
    try {
      final userName = await _sosService.getUserName();
      setState(() {
        _userName = userName;
      });
    } catch (e) {
      print('Error loading user name: $e');
    }
  }

  Future<void> _loadEmergencyContacts() async {
    _sosService.getEmergencyContacts().listen((contacts) {
      setState(() {
        _emergencyContacts = contacts;
      });
    });
  }

  void _startCountdown() {
    if (_emergencyContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add emergency contacts first'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isCountdownActive = true;
      _countdownSeconds = 15;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdownSeconds--;
      });

      if (_countdownSeconds <= 0) {
        _cancelCountdown();
        _triggerSOSAlert();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _isCountdownActive = false;
      _countdownSeconds = 15;
    });
  }
  

  Future<void> _triggerSOSAlert() async {
    try {
      // Ensure SMS permission is granted
      final smsPermission = await Permission.sms.request();
      if (!smsPermission.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'SMS permission is required to send emergency alerts',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('🚨 SOS ALERT ACTIVATED 🚨'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Sending emergency SMS...'),
            ],
          ),
        ),
      );

      final results = await _sosService.triggerSOSAlert(
        contacts: _emergencyContacts,
        userName: _userName,
      );

      if (mounted) {
        Navigator.pop(context); // Close progress dialog

        final smsSent = List<String>.from(results['sms_sent'] as List? ?? []);
        final smsFailed = List<String>.from(
          results['sms_failed'] as List? ?? [],
        );

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              smsSent.isNotEmpty
                  ? '✓ Emergency Alert SENT'
                  : '⚠ Alert Triggered',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SMS Results
                  if (smsSent.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'SMS SENT',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...smsSent.map(
                      (name) => Padding(
                        padding: const EdgeInsets.only(left: 32, bottom: 6),
                        child: Text(
                          '📱 $name',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],

                  // SMS Failed
                  if (smsFailed.isNotEmpty) ...[
                    if (smsSent.isNotEmpty) const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.warning,
                          color: Colors.orange,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'SMS FAILED',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...smsFailed.map(
                      (name) => Padding(
                        padding: const EdgeInsets.only(left: 32, bottom: 6),
                        child: Text(
                          '⚠ $name',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],

                  // Info box
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '✓ Emergency SMS Sent Successfully!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Two SMS were sent: (1) Emergency alert, (2) Live location link.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check),
                label: const Text('OK'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Alert', style: TextStyle(color: Colors.red)),
            content: Text('Error triggering SOS: $e'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVoiceTriggered =
      ModalRoute.of(context)?.settings.arguments as bool? ?? false;

  if (isVoiceTriggered && !_isCountdownActive) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_emergencyContacts.isNotEmpty) {
        _startCountdown();
      }
    });
  }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/sosSettings'),
            tooltip: 'SOS Settings',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              color: Colors.deepPurple.withOpacity(0.1),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Emergency Alert System',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _emergencyContacts.length == 0
                        ? 'Add emergency contacts in settings'
                        : '${_emergencyContacts.length} contact${_emergencyContacts.length != 1 ? 's' : ''} configured',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // Main SOS Button or Countdown
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: _isCountdownActive
                    ? _buildCountdownUI()
                    : _buildSOSButton(),
              ),
            ),

            // Emergency Contacts Preview
            if (_emergencyContacts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Emergency Contacts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._emergencyContacts
                        .take(3)
                        .map(
                          (contact) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.deepPurple,
                                  child: Text(
                                    contact.name[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contact.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        contact.phoneNumber,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    if (_emergencyContacts.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          '+${_emergencyContacts.length - 3} more',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // Info Section
            Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'How it works',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '1. Press the big red SOS button to start the alert\n'
                    '2. You have 15 seconds to cancel the alert\n'
                    '3. If you don\'t cancel, emergency contacts will be notified\n'
                    '4. Your location will be shared with emergency services',
                    style: TextStyle(fontSize: 13, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSOSButton() {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
      ),
      child: GestureDetector(
        onTap: _emergencyContacts.isEmpty ? null : _startCountdown,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red[600],
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _emergencyContacts.isEmpty ? null : _startCountdown,
              customBorder: const CircleBorder(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emergency, size: 80, color: Colors.white),
                  const SizedBox(height: 8),
                  const Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Press to Alert',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownUI() {
    return Column(
      children: [
        // Countdown Ring
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background Ring
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[300]!, width: 4),
                ),
              ),
              // Animated Ring
              CustomPaint(
                size: const Size(200, 200),
                painter: CountdownPainter(progress: _countdownSeconds / 15),
              ),
              // Center Circle with Countdown
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red[600],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _countdownSeconds.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'seconds',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Cancel Button
        ElevatedButton.icon(
          onPressed: _cancelCountdown,
          icon: const Icon(Icons.close),
          label: const Text('Cancel Alert'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Alert will be sent when timer reaches 0',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

class CountdownPainter extends CustomPainter {
  final double progress;

  CountdownPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 4.0;
    final paint = Paint()
      ..color = Colors.red[600]!
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      (3.14159 * 2) * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CountdownPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
