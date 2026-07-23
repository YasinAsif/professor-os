import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_repository.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String? token;
  final String? email;
  const VerifyEmailScreen({super.key, this.token, this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _verifying = false;
  bool _verified = false;
  String? _error;
  int _resendCooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.token != null) _verify();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() { _verifying = true; _error = null; });
    try {
      await AuthRepository().verifyEmail(widget.token!);
      setState(() => _verified = true);
    } catch (e) {
      final msg = _extractError(e);
      if (msg.toLowerCase().contains('already verified')) {
        setState(() => _verified = true);
      } else {
        setState(() => _error = msg);
      }
    } finally {
      setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0 || widget.email == null) return;
    try {
      await AuthRepository().resendVerification(widget.email!);
      setState(() => _resendCooldown = 300);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_resendCooldown <= 0) { t.cancel(); return; }
        setState(() => _resendCooldown--);
      });
    } catch (e) {
      setState(() => _error = _extractError(e));
    }
  }

  String _extractError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['detail'] is String) return data['detail'] as String;
      if (data is String && data.isNotEmpty) return data;
      return 'Server error (${e.response?.statusCode ?? 'no response'}). Please try again.';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 64, height: 64,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: _verified ? AppColors.verified.withOpacity(0.1) : AppColors.signal.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _verified ? Icons.check_circle_rounded : Icons.mark_email_unread_rounded,
                    size: 32,
                    color: _verified ? AppColors.verified : AppColors.signal,
                  ),
                ),
                Text(
                  _verified ? 'Email Verified' : 'Check your inbox',
                  style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.inkPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _verified
                    ? 'Your email address has been verified. You can now access all features.'
                    : 'We sent a verification link to\n${widget.email ?? "your email address"}.',
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.inkSecondary, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.feedbackRed.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.feedbackRed),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkPrimary))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                if (_verifying) ...[
                  const Center(child: CircularProgressIndicator(color: AppColors.signal, strokeWidth: 2.5)),
                  const SizedBox(height: 24),
                ],

                if (_verified)
                  ElevatedButton(
                    onPressed: () => context.go('/auth/login'),
                    child: const Text('Continue to Sign In'),
                  )
                else ...[
                  OutlinedButton(
                    onPressed: _resendCooldown > 0 ? null : _resend,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.signal,
                      side: const BorderSide(color: AppColors.signal),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: Text(_resendCooldown > 0
                      ? 'Resend in ${_resendCooldown ~/ 60}:${(_resendCooldown % 60).toString().padLeft(2, '0')}'
                      : 'Resend Email'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/auth/login'),
                    child: const Text('Back to Sign In'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
