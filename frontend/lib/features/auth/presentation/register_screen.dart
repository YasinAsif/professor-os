/// ProfessorOS – Register Screen (split-screen, role pills, strength meter).

import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../data/auth_repository.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  String _role  = 'professor';
  bool _obscure = true;
  bool _loading = false;
  bool _done    = false;
  String? _error;
  bool _resending = false;
  bool _verifyingInstantly = false;
  String? _verificationToken;

  late final AnimationController _auroraCtrl;
  late final AnimationController _enterCtrl;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  int get _strength => Validators.passwordStrength(_passCtrl.text);

  @override
  void initState() {
    super.initState();
    _auroraCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat();
    _enterCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade  = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _auroraCtrl.dispose(); _enterCtrl.dispose();
    _nameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      _verificationToken = await AuthRepository().register(_emailCtrl.text.trim(), _nameCtrl.text.trim(), _passCtrl.text, _role);
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
    final wide = MediaQuery.of(context).size.width >= 860;
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Row(children: [
        if (wide) Expanded(flex: 55, child: _RegisterHero(aurora: _auroraCtrl)),
        Expanded(
          flex: wide ? 45 : 100,
          child: FadeTransition(opacity: _fade, child: SlideTransition(position: _slide,
            child: Container(color: AppColors.bgPage,
              child: Center(child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440),
                  child: _done ? _buildSuccess() : _buildForm(),
                ),
              )),
            ),
          )),
        ),
      ]),
    );
  }

  Widget _buildSuccess() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.elasticOut,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            gradient: AppGradients.primaryButton,
            shape: BoxShape.circle,
            boxShadow: AppShadows.buttonGlow,
          ),
          child: const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 36),
        ),
      ),
      const SizedBox(height: 28),
      Text('Check your inbox!', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5)),
      const SizedBox(height: 10),
      Text('We sent a verification link to\n${_emailCtrl.text}',
        style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary, height: 1.6),
        textAlign: TextAlign.center),
      const SizedBox(height: 24),

      if (_verificationToken != null) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.successGreen.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.successGreen.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text('⚡ Demo Direct Access', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.successGreen)),
              const SizedBox(height: 6),
              ElevatedButton.icon(
                icon: _verifyingInstantly
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.flash_on_rounded, size: 18),
                label: Text(_verifyingInstantly ? 'Verifying...' : 'Verify Account Instantly'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.successGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _verifyingInstantly ? null : () async {
                  setState(() => _verifyingInstantly = true);
                  try {
                    await AuthRepository().verifyEmail(_verificationToken!);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Account verified successfully! You can now sign in.'),
                        backgroundColor: AppColors.successGreen,
                      ));
                      context.go('/auth/login');
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Verification error: ${e.toString()}'),
                        backgroundColor: AppColors.dangerRose,
                      ));
                    }
                  } finally {
                    if (mounted) setState(() => _verifyingInstantly = false);
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],

      _GlowButton(label: 'Go to Sign In', loading: false, onPressed: () => context.go('/auth/login')),
      const SizedBox(height: 14),
      TextButton(
        onPressed: _resending ? null : () async {
          setState(() => _resending = true);
          try {
            await AuthRepository().resendVerification(_emailCtrl.text.trim());
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Verification email resent!'),
                backgroundColor: AppColors.successGreen,
              ));
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Resending failed: ${e.toString()}'),
                backgroundColor: AppColors.dangerRose,
              ));
            }
          } finally {
            if (mounted) setState(() => _resending = false);
          }
        },
        child: _resending
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryIndigo),
              )
            : Text("Didn't receive email? Resend link",
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: AppColors.primaryIndigo)),
      ),
    ]);
  }

  Widget _buildForm() {
    final strengthColors = [AppColors.dangerRose, Color(0xFFEA580C), AppColors.accentAmber, AppColors.successGreen, AppColors.successGreen];
    final strengthLabels = ['Too weak', 'Weak', 'Fair', 'Strong', 'Very strong'];

    return Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Header
      Text('Create account', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -1)),
      const SizedBox(height: 6),
      Text('Join ProfessorOS and elevate your academic workflow.', style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary)),
      const SizedBox(height: 32),

      // Error banner
      if (_error != null) Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.dangerRose.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.dangerRose.withOpacity(0.25)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.dangerRose, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.dangerRose))),
        ]),
      ),

      // Full name
      TextFormField(
        controller: _nameCtrl,
        validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your full name' : null,
        decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline_rounded)),
      ),
      const SizedBox(height: 14),

      // Email
      TextFormField(
        controller: _emailCtrl,
        validator: Validators.email,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.alternate_email_rounded)),
      ),
      const SizedBox(height: 20),

      // Role pills
      Text('I am a…', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      const SizedBox(height: 10),
      Row(children: [
        for (final r in [('professor', 'Professor', '🎓'), ('student', 'Student', '📚'), ('ta', 'TA', '✏️')])
          Expanded(child: Padding(
            padding: EdgeInsets.only(right: r.$1 != 'ta' ? 8 : 0),
            child: _RolePill(label: r.$2, emoji: r.$3, selected: _role == r.$1, onTap: () => setState(() => _role = r.$1)),
          )),
      ]),
      const SizedBox(height: 20),

      // Password
      TextFormField(
        controller: _passCtrl,
        validator: Validators.password,
        obscureText: _obscure,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),

      // Strength meter
      if (_passCtrl.text.isNotEmpty) ...[
        const SizedBox(height: 10),
        Row(children: List.generate(4, (i) => Expanded(child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 4, margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: i < _strength ? strengthColors[_strength] : AppColors.border,
          ),
        )))),
        const SizedBox(height: 6),
        Text(_strength > 0 ? strengthLabels[_strength] : '',
          style: GoogleFonts.inter(fontSize: 12, color: strengthColors[_strength.clamp(0, 4)], fontWeight: FontWeight.w500)),
      ],

      const SizedBox(height: 28),

      _GlowButton(label: 'Create Account', loading: _loading, onPressed: _loading ? null : _submit),

      const SizedBox(height: 22),
      Center(child: GestureDetector(
        onTap: () => context.go('/auth/login'),
        child: RichText(text: TextSpan(
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
          children: [
            const TextSpan(text: 'Already have an account? '),
            TextSpan(text: 'Sign in', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryIndigo)),
          ],
        )),
      )),
    ]));
  }
}

// ── Register hero (different copy from login) ────────────────────────────────

class _RegisterHero extends StatelessWidget {
  final AnimationController aurora;
  const _RegisterHero({required this.aurora});

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      Container(decoration: const BoxDecoration(gradient: LinearGradient(
        colors: [Color(0xFF0D1117), Color(0xFF0A0617), Color(0xFF130B2B)],
        begin: Alignment.topRight, end: Alignment.bottomLeft,
      ))),
      AnimatedBuilder(animation: aurora, builder: (_, __) => CustomPaint(painter: _RegisterAurora(aurora.value))),
      CustomPaint(painter: _DotGrid()),
      LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(gradient: AppGradients.aurora, borderRadius: BorderRadius.circular(40),
                        boxShadow: [const BoxShadow(color: Color(0x50EC4899), blurRadius: 20, offset: Offset(0, 4))]),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.school_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text('ProfessorOS', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                      ]),
                    ),
                    const Spacer(flex: 2),
                    const SizedBox(height: 24),
                    Text('Your academic\nsuperpower\nawaits.', style: GoogleFonts.outfit(
                      color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -1.5)),
                    const SizedBox(height: 16),
                    Text('Set up in under 2 minutes.\nNo credit card. No nonsense.',
                      style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 15, height: 1.5)),
                    const SizedBox(height: 28),
                    ...[
                      ('🚀', 'Go live in minutes'),
                      ('🧠', 'Smart rubric generation'),
                      ('📱', 'Works on any device'),
                      ('🔒', 'Your data stays yours'),
                    ].map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(children: [
                        Container(width: 34, height: 34,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(10)),
                          child: Center(child: Text(f.$1, style: const TextStyle(fontSize: 15)))),
                        const SizedBox(width: 12),
                        Text(f.$2, style: GoogleFonts.inter(color: const Color(0xFFCBD5E1), fontSize: 14)),
                      ]),
                    )),
                    const Spacer(flex: 3),
                    const SizedBox(height: 24),
                    Text('© 2026 ProfessorOS', style: GoogleFonts.inter(color: const Color(0xFF475569), fontSize: 12)),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    ]);
  }
}

// ── Role pill chip ───────────────────────────────────────────────────────────

class _RolePill extends StatelessWidget {
  final String label, emoji;
  final bool selected;
  final VoidCallback onTap;
  const _RolePill({required this.label, required this.emoji, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.bgInput,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.primaryIndigo : AppColors.border, width: selected ? 2 : 1),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
            color: selected ? AppColors.primaryIndigo : AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

// ── Shared gradient button ───────────────────────────────────────────────────

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
              backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
              foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 52),
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

// ── Painters ────────────────────────────────────────────────────────────────

class _RegisterAurora extends CustomPainter {
  final double t;
  _RegisterAurora(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _o(canvas, size, 0.80 + 0.06 * math.sin(t * 2 * math.pi), 0.20 + 0.08 * math.cos(t * 2 * math.pi * 0.8), 0.38, const Color(0xFF6366F1), 0.4);
    _o(canvas, size, 0.20 + 0.07 * math.cos(t * 2 * math.pi * 1.2), 0.55 + 0.08 * math.sin(t * 2 * math.pi * 0.6), 0.30, const Color(0xFFEC4899), 0.30);
    _o(canvas, size, 0.55 + 0.09 * math.sin(t * 2 * math.pi * 0.7), 0.80 + 0.05 * math.cos(t * 2 * math.pi), 0.25, const Color(0xFF8B5CF6), 0.28);
  }

  void _o(Canvas canvas, Size size, double cx, double cy, double r, Color c, double op) {
    final center = Offset(size.width * cx, size.height * cy);
    final radius = size.width * r;
    canvas.drawCircle(center, radius, Paint()
      ..shader = RadialGradient(colors: [c.withOpacity(op), c.withOpacity(0)]).createShader(Rect.fromCircle(center: center, radius: radius)));
  }

  @override
  bool shouldRepaint(_RegisterAurora old) => old.t != t;
}

class _DotGrid extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.03);
    for (double x = 0; x < size.width; x += 36) {
      for (double y = 0; y < size.height; y += 36) {
        canvas.drawCircle(Offset(x, y), 1.2, p);
      }
    }
  }
  @override bool shouldRepaint(_DotGrid _) => false;
}
