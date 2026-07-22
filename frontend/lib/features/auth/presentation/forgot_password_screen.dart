/// ProfessorOS – Forgot Password Screen.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../data/auth_repository.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _done    = false;
  String? _error;

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
  }

  @override
  void dispose() { _enterCtrl.dispose(); _emailCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await AuthRepository().forgotPassword(_emailCtrl.text.trim());
      if (mounted) setState(() => _done = true);
    } catch (e) {
      String msg = e.toString();
      if (e is DioException) {
        final d = e.response?.data;
        if (d is Map && d['detail'] is String) msg = d['detail'];
      }
      if (mounted) setState(() => _error = msg.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Stack(children: [
        // Ambient blob
        Positioned(top: -120, right: -120,
          child: Container(width: 400, height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppColors.primaryIndigo.withOpacity(0.12), Colors.transparent]),
            ))),
        Positioned(bottom: -80, left: -80,
          child: Container(width: 300, height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppColors.accentPink.withOpacity(0.08), Colors.transparent]),
            ))),
        // Content
        Center(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: FadeTransition(opacity: _fade, child: SlideTransition(position: _slide,
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.elevated,
                ),
                child: _done ? _buildSuccess() : _buildForm(),
              ),
            ),
          )),
        )),
      ]),
    );
  }

  Widget _buildSuccess() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.elasticOut,
        builder: (_, v, c) => Transform.scale(scale: v, child: c),
        child: Container(width: 72, height: 72,
          decoration: BoxDecoration(gradient: AppGradients.primaryButton, shape: BoxShape.circle,
            boxShadow: AppShadows.buttonGlow),
          child: const Icon(Icons.send_rounded, color: Colors.white, size: 32)),
      ),
      const SizedBox(height: 24),
      Text('Email sent!', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 10),
      Text('If that email exists in our system,\nyou\'ll receive a reset link shortly.',
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.6), textAlign: TextAlign.center),
      const SizedBox(height: 28),
      OutlinedButton(
        onPressed: () => context.go('/auth/login'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryIndigo,
          side: const BorderSide(color: AppColors.primaryIndigo),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text('Back to Sign In', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
    ]);
  }

  Widget _buildForm() {
    return Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Back button
      Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => context.go('/auth/login'),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text('Back', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
          ]),
        ),
      ),
      const SizedBox(height: 28),

      // Icon
      Container(width: 56, height: 56,
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.lock_reset_rounded, color: AppColors.primaryIndigo, size: 28)),
      const SizedBox(height: 20),

      Text('Reset your password', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5)),
      const SizedBox(height: 8),
      Text("Enter your email and we'll send you a reset link.", style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.6)),
      const SizedBox(height: 28),

      if (_error != null) Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.dangerRose.withOpacity(0.06), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.dangerRose.withOpacity(0.25))),
        child: Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.dangerRose)),
      ),

      TextFormField(
        controller: _emailCtrl,
        validator: Validators.email,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.alternate_email_rounded)),
      ),
      const SizedBox(height: 24),

      _GlowButton(label: 'Send Reset Link', loading: _loading, onPressed: _loading ? null : _submit),
    ]));
  }
}

class _GlowButton extends StatefulWidget {
  final String label; final bool loading; final VoidCallback? onPressed;
  const _GlowButton({required this.label, required this.loading, this.onPressed});
  @override State<_GlowButton> createState() => _GlowButtonState();
}
class _GlowButtonState extends State<_GlowButton> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit:  (_) => setState(() => _hovered = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(gradient: AppGradients.primaryButton, borderRadius: BorderRadius.circular(12),
        boxShadow: _hovered ? [const BoxShadow(color: Color(0x804F46E5), blurRadius: 28, offset: Offset(0, 8))]
            : [const BoxShadow(color: Color(0x404F46E5), blurRadius: 16, offset: Offset(0, 4))]),
      child: AnimatedScale(scale: _hovered ? 1.01 : 1.0, duration: const Duration(milliseconds: 150),
        child: ElevatedButton(
          onPressed: widget.onPressed,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
            foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
          child: widget.loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Text(widget.label),
        ),
      ),
    ),
  );
}
