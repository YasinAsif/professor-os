import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_parser.dart';
import '../../../shared/widgets/prof_button.dart';
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
    setState(() {
      _verifying = true;
      _error = null;
    });
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
        if (_resendCooldown <= 0) {
          t.cancel();
          return;
        }
        setState(() => _resendCooldown--);
      });
    } catch (e) {
      setState(() => _error = _extractError(e));
    }
  }

  String _extractError(Object e) {
    return ErrorParser.parse(e);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgPage = isDark ? AppColors.bgPage : AppColorsLight.bgPage;
    final surfaceColor = isDark ? AppColors.surface : AppColorsLight.surface;
    final ruleColor = isDark ? AppColors.rule : AppColorsLight.rule;
    final inkPrimary = isDark ? AppColors.inkPrimary : AppColorsLight.inkPrimary;
    final inkSecondary = isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary;

    return Scaffold(
      backgroundColor: bgPage,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ruleColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: _verified
                              ? AppColors.verified.withOpacity(0.12)
                              : AppColors.signal.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _verified
                                ? AppColors.verified.withOpacity(0.3)
                                : AppColors.signal.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          _verified
                              ? Icons.mark_email_read_rounded
                              : Icons.mark_email_unread_rounded,
                          size: 32,
                          color: _verified ? AppColors.verified : AppColors.signal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _verified ? 'Email Verified' : 'Check Your Inbox',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: inkPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _verified
                          ? 'Your academic email address has been verified successfully. You may now sign in.'
                          : 'We sent a verification link to:\n${widget.email ?? "your registered email"}',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        color: inkSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppColors.feedbackRed.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.feedbackRed.withOpacity(0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 16, color: AppColors.feedbackRed),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.feedbackRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_verifying) ...[
                      const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.academicTeal,
                          strokeWidth: 2.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (_verified)
                      ProfButton(
                        label: 'Continue to Sign In',
                        icon: Icons.login_rounded,
                        variant: ProfButtonVariant.cta,
                        size: ProfButtonSize.lg,
                        isExpanded: true,
                        onPressed: () => context.go('/auth/login'),
                      )
                    else ...[
                      ProfButton(
                        label: _resendCooldown > 0
                            ? 'Resend in ${_resendCooldown ~/ 60}:${(_resendCooldown % 60).toString().padLeft(2, '0')}'
                            : 'Resend Verification Email',
                        icon: Icons.send_rounded,
                        variant: ProfButtonVariant.outline,
                        size: ProfButtonSize.lg,
                        isExpanded: true,
                        onPressed: _resendCooldown > 0 ? null : _resend,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () => context.go('/auth/login'),
                          child: Text(
                            'Back to Sign In',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: inkSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
