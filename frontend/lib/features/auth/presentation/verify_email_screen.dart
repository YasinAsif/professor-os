/// ProfessorOS – Email Verification Screen.

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

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with SingleTickerProviderStateMixin {
  bool _verifying = false;
  bool _verified = false;
  String? _error;
  int _resendCooldown = 0;
  Timer? _timer;

  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade  = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _enterCtrl.forward();

    if (widget.token != null) _verify();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _enterCtrl.dispose();
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
      body: Stack(
        children: [
          // Ambient background glow
          Positioned(
            top: -100, left: -100,
            child: Container(
              width: 380, height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.primaryIndigo.withOpacity(0.12), Colors.transparent]),
              ),
            ),
          ),
          Positioned(
            bottom: -100, right: -100,
            child: Container(
              width: 380, height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.accentCyan.withOpacity(0.10), Colors.transparent]),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppShadows.elevated,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.elasticOut,
                            builder: (_, v, child) => Transform.scale(scale: v, child: child),
                            child: Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                color: _verified
                                    ? AppColors.successGreen.withOpacity(0.12)
                                    : AppColors.primarySoft,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _verified ? Icons.check_circle_rounded : Icons.mark_email_unread_rounded,
                                size: 36,
                                color: _verified ? AppColors.successGreen : AppColors.primaryIndigo,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _verified ? 'Email Verified!' : 'Check your inbox',
                            style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _verified
                              ? 'Your email address has been verified. You can now access all features.'
                              : 'We sent a verification link to\n${widget.email ?? "your email address"}.',
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.6),
                            textAlign: TextAlign.center,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.dangerRose.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.dangerRose.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.dangerRose),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.dangerRose))),
                                ],
                              ),
                            ),
                          ],
                          if (_verifying) ...[
                            const SizedBox(height: 24),
                            const CircularProgressIndicator(color: AppColors.primaryIndigo, strokeWidth: 2.5),
                          ],
                          const SizedBox(height: 28),
                          if (_verified)
                            _GlowButton(
                              label: 'Continue to Sign In',
                              loading: false,
                              onPressed: () => context.go('/auth/login'),
                            )
                          else ...[
                            _GlowOutlinedButton(
                              label: _resendCooldown > 0
                                  ? 'Resend in ${_resendCooldown ~/ 60}:${(_resendCooldown % 60).toString().padLeft(2, '0')}'
                                  : 'Resend Email',
                              onPressed: _resendCooldown > 0 ? null : _resend,
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => context.go('/auth/login'),
                              child: Text('Back to Sign In', style: GoogleFonts.inter(color: AppColors.primaryIndigo, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowButton extends StatefulWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  const _GlowButton({required this.label, required this.loading, this.onPressed});

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: AppGradients.primaryButton,
          borderRadius: BorderRadius.circular(12),
          boxShadow: _hovered
              ? [const BoxShadow(color: Color(0x804F46E5), blurRadius: 28, offset: Offset(0, 8))]
              : [const BoxShadow(color: Color(0x404F46E5), blurRadius: 16, offset: Offset(0, 4))],
        ),
        child: AnimatedScale(
          scale: _hovered ? 1.01 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: ElevatedButton(
            onPressed: widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            child: widget.loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text(widget.label),
          ),
        ),
      ),
    );
  }
}

class _GlowOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const _GlowOutlinedButton({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryIndigo,
        side: const BorderSide(color: AppColors.primaryIndigo),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}
