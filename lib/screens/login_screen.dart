import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../features/auth/otp_service.dart';
import '../features/auth/sms_service.dart';
import '../features/auth/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool   _otpSent       = false;
  bool   _loading       = false;
  String _completePhone = '';
  String? _error;

  final _otpController = TextEditingController();

  // Resend cooldown
  int  _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  // ── Send OTP ──────────────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    if (_completePhone.isEmpty) {
      setState(() => _error = 'Enter a valid phone number');
      return;
    }
    setState(() { _loading = true; _error = null; });

    final otp = OtpService.instance.generateOtp(_completePhone);
    final message = 'Your OTP for Nirbhaya App is: $otp. Do not share it with anyone.';

    final sent = await SmsService.sendSms(_completePhone, message);

    if (!mounted) return;
    if (sent) {
      setState(() {
        _loading = false;
        _otpSent = true;
      });
      _startResendTimer();
    } else {
      // SMS failed (emulator / no SIM) — still allow OTP entry for testing
      setState(() {
        _loading = false;
        _otpSent = true;
        _error   = 'SMS could not be sent. If testing, use OTP shown in logs.';
      });
      _startResendTimer();
      debugPrint('🔑 DEBUG OTP for $_completePhone: $otp');
    }
  }

  void _startResendTimer() {
    _resendSeconds = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds <= 0) {
        t.cancel();
      } else {
        if (mounted) setState(() => _resendSeconds--);
      }
    });
  }

  // ── Verify OTP ────────────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final entered = _otpController.text.trim();
    if (entered.length != 6) {
      setState(() => _error = 'Enter the 6-digit OTP');
      return;
    }
    setState(() { _loading = true; _error = null; });

    final error = OtpService.instance.verifyOtp(_completePhone, entered);
    if (error != null) {
      setState(() { _loading = false; _error = error; });
      return;
    }

    // OTP correct — save session
    await AuthService.saveSession(_completePhone);

    // Check if profile exists
    final exists = await AuthService.userProfileExists(_completePhone);

    if (!mounted) return;
    if (exists) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/completeProfile');
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primary, AppColors.accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                children: [
                  const AppLogo(size: 100, withBackground: true),
                  const SizedBox(height: 20),
                  const Text('Nirbhaya',
                      style: TextStyle(color: Colors.white, fontSize: 32,
                          fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 6),
                  const Text('Smart Women Safety Application',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 40),

                  // Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.15),
                            blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _otpSent ? 'Verify OTP' : 'Login with Mobile',
                          style: const TextStyle(fontSize: 20,
                              fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _otpSent
                              ? 'Enter the 6-digit code sent to $_completePhone'
                              : 'Enter your mobile number to receive OTP',
                          style: const TextStyle(fontSize: 13, color: AppColors.textMid),
                        ),
                        const SizedBox(height: 24),

                        if (!_otpSent) ...[
                          IntlPhoneField(
                            keyboardType: TextInputType.phone,
                            initialCountryCode: 'IN',
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              hintText: '9876543210',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onChanged: (phone) =>
                                _completePhone = phone.completeNumber,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _loading ? null : _sendOtp,
                            child: _loading
                                ? const SizedBox(height: 20, width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Send OTP'),
                          ),
                        ] else ...[
                          // OTP input
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 24,
                                fontWeight: FontWeight.bold, letterSpacing: 8),
                            decoration: InputDecoration(
                              hintText: '------',
                              counterText: '',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _loading ? null : _verifyOtp,
                            child: _loading
                                ? const SizedBox(height: 20, width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Verify & Login'),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () => setState(() {
                                  _otpSent = false;
                                  _otpController.clear();
                                  _error = null;
                                  _resendTimer?.cancel();
                                }),
                                child: const Text('Change number',
                                    style: TextStyle(color: AppColors.primary)),
                              ),
                              TextButton(
                                onPressed: _resendSeconds > 0 ? null : _sendOtp,
                                child: Text(
                                  _resendSeconds > 0
                                      ? 'Resend in ${_resendSeconds}s'
                                      : 'Resend OTP',
                                  style: TextStyle(
                                    color: _resendSeconds > 0
                                        ? AppColors.textLight
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Error
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: AppColors.error, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_error!,
                                      style: const TextStyle(
                                          color: AppColors.error, fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
