import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VerifyEmailScreen extends StatefulWidget {
  final VoidCallback onVerified;
  final VoidCallback onBack;

  const VerifyEmailScreen({
    super.key,
    required this.onVerified,
    required this.onBack,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _resending = false;
  bool _checking = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  Future<void> _startPolling() async {
    for (int i = 0; i < 60; i++) {
      if (!mounted) return;

      await FirebaseAuth.instance.currentUser?.reload();
      final freshUser = FirebaseAuth.instance.currentUser;

      if (freshUser == null) {
        widget.onBack();
        return;
      }

      if (freshUser.emailVerified) {
        if (mounted) {
          setState(() => _checking = false);
          widget.onVerified();
        }
        return;
      }

      await Future.delayed(const Duration(seconds: 2));
    }
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _handleResend() async {
    setState(() {
      _resending = true;
      _message = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();
      if (mounted) {
        setState(() => _message = 'Verification email sent again.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _message = 'Failed to resend. Try again.');
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF7F6F4),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mail icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B5FE3).withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mail_outline_rounded,
                    size: 32,
                    color: Color(0xFF3B5FE3),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Verify Your Email',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'We sent a verification link to',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFF98989D) : const Color(0xFF6E6E73),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? 'your email',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Click the link in your inbox to continue.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFF98989D) : const Color(0xFF6E6E73),
                  ),
                ),
                const SizedBox(height: 24),
                // Checking indicator
                if (_checking)
                  Column(
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF3B5FE3),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Waiting for verification...',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? const Color(0xFF98989D) : const Color(0xFF6E6E73),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 32),
                // Resend
                Text(
                  "Didn't receive the email?",
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFF98989D) : const Color(0xFF6E6E73),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _resending ? null : _handleResend,
                  child: Text(
                    _resending ? 'Sending...' : 'Resend Email',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3B5FE3),
                    ),
                  ),
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _message!,
                      style: TextStyle(
                        fontSize: 14,
                        color: _message!.contains('sent')
                            ? const Color(0xFF34C759)
                            : const Color(0xFFFF3B30),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: _checking ? null : widget.onBack,
                  child: Text(
                    'Back to Sign In',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF98989D) : const Color(0xFF6E6E73),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
