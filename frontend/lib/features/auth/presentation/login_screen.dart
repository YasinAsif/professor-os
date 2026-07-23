/// ProfessorOS – Login Screen (Split-screen, aurora hero, staggered animations).

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';
import '../data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey  = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  bool _isUnverified = false;

  late final AnimationController _enterCtrl;
  late final AnimationController _auroraCtrl;

  late final Animation<double> _fadeCard;
  late final Animation<Offset> _slideCard;
  late final List<Animation<double>> _fieldFades;
  late final List<Animation<Offset>> _fieldSlides;

  @override
  void initState() {
    super.initState();

    // Aurora: slow continuous loop
    _auroraCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat();

    // Entrance: one-shot on load
    _enterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

    _fadeCard  = CurvedAnimation(parent: _enterCtrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _slideCard = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic)));

    final intervals = [
      const Interval(0.15, 0.70),
      const Interval(0.25, 0.80),
      const Interval(0.35, 0.90),
      const Interval(0.45, 1.00),
      const Interval(0.55, 1.00),
    ];

    _fieldFades = intervals.map((iv) =>
        CurvedAnimation(parent: _enterCtrl, curve: iv)).toList();
    _fieldSlides = intervals.map((iv) =>
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
            .animate(CurvedAnimation(parent: _enterCtrl, curve: Interval(iv.begin, iv.end, curve: Curves.easeOutCubic)))
    ).toList();

    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _auroraCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── Submit ──────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; _isUnverified = false; });

    await ref.read(authProvider.notifier).login(_emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;

    final authState = ref.read(authProvider);
    if (authState.hasError) {
      String msg = authState.error.toString();
      final m = RegExp(r'"detail"\s*:\s*"([^"]+)"').firstMatch(msg);
      if (m != null) msg = m.group(1)!;
      msg = msg.replaceFirst('Exception: ', '');
      setState(() { _error = msg; _isUnverified = msg.toLowerCase().contains('verify'); _loading = false; });
    } else {
      setState(() => _loading = false);
      context.go('/courses');
    }
  }

  Future<void> _resendVerification() async {
    try {
      await AuthRepository().resendVerification(_emailCtrl.text.trim());
      if (mounted) _showSnack('Verification email sent!', success: true);
    } catch (_) {}
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.successGreen : AppColors.dangerRose,
    ));
  }

  // ── Build ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final showHero = w >= 860;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Row(
        children: [
          if (showHero) Expanded(flex: 55, child: _HeroPanel(aurora: _auroraCtrl)),
          Expanded(
            flex: showHero ? 45 : 100,
            child: _FormPanel(
              fadeCard: _fadeCard, slideCard: _slideCard,
              fieldFades: _fieldFades, fieldSlides: _fieldSlides,
              formKey: _formKey, emailCtrl: _emailCtrl, passCtrl: _passCtrl,
              obscure: _obscure, loading: _loading,
              error: _error, isUnverified: _isUnverified,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              onSubmit: _submit,
              onResendVerification: _resendVerification,
              onForgotPassword: () => context.go('/auth/forgot-password'),
              onRegister: () => context.go('/auth/register'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero left panel ─────────────────────────────────────────────────────────

class _HeroPanel extends StatelessWidget {
  final AnimationController aurora;
  const _HeroPanel({required this.aurora});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Dark gradient base
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A0617), Color(0xFF130B2B), Color(0xFF0D1330)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
        ),
        // Animated aurora orbs
        AnimatedBuilder(
          animation: aurora,
          builder: (_, __) => CustomPaint(painter: _AuroraPainter(aurora.value)),
        ),
        // Noise-like grid overlay
        CustomPaint(painter: _GridPainter()),
        // Content
        LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: AppGradients.primaryButton,
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [const BoxShadow(color: Color(0x504F46E5), blurRadius: 24, offset: Offset(0, 6))],
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.school_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text('ProfessorOS', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                          ]),
                        ),
                        const Spacer(flex: 2),
                        const SizedBox(height: 24),
                        // Tagline
                        Text('Grade smarter,\nnot harder.',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 42, fontWeight: FontWeight.w800,
                            height: 1.1, letterSpacing: -1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Pakistan\'s academic platform built for\nprofessors who care about outcomes.',
                          style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 15, height: 1.5)),
                        const SizedBox(height: 28),
                        // Feature bullets
                        ...[
                          ('⚡', 'AI-assisted rubric builder'),
                          ('📊', 'Real-time CLO analytics'),
                          ('🛡️', 'HEC-compliant grading'),
                          ('📧', 'Automated student alerts'),
                        ].map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(children: [
                            Container(
                              width: 34, height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(child: Text(f.$1, style: const TextStyle(fontSize: 15))),
                            ),
                            const SizedBox(width: 12),
                            Text(f.$2, style: GoogleFonts.inter(color: const Color(0xFFCBD5E1), fontSize: 14)),
                          ]),
                        )),
                        const Spacer(flex: 3),
                        const SizedBox(height: 24),
                        // Footer
                        Text('© 2026 ProfessorOS  •  Built for Pakistani HEIs',
                          style: GoogleFonts.inter(color: const Color(0xFF475569), fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Form right panel ────────────────────────────────────────────────────────

class _FormPanel extends StatelessWidget {
  final Animation<double> fadeCard;
  final Animation<Offset> slideCard;
  final List<Animation<double>> fieldFades;
  final List<Animation<Offset>> fieldSlides;

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl, passCtrl;
  final bool obscure, loading, isUnverified;
  final String? error;
  final VoidCallback onToggleObscure, onSubmit, onForgotPassword, onRegister;
  final VoidCallback onResendVerification;

  const _FormPanel({
    required this.fadeCard, required this.slideCard,
    required this.fieldFades, required this.fieldSlides,
    required this.formKey, required this.emailCtrl, required this.passCtrl,
    required this.obscure, required this.loading, required this.isUnverified,
    this.error, required this.onToggleObscure, required this.onSubmit,
    required this.onForgotPassword, required this.onRegister,
    required this.onResendVerification,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgPage,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: FadeTransition(
              opacity: fadeCard,
              child: SlideTransition(
                position: slideCard,
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      _Animated(fade: fieldFades[0], slide: fieldSlides[0], child:
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Welcome back', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -1)),
                          const SizedBox(height: 6),
                          Text('Sign in to your ProfessorOS account', style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary)),
                        ]),
                      ),
                      const SizedBox(height: 32),

                      // Error banner
                      if (error != null)
                        _Animated(fade: fieldFades[0], slide: fieldSlides[0], child:
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.dangerRose.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.dangerRose.withOpacity(0.25)),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                const Icon(Icons.error_outline_rounded, color: AppColors.dangerRose, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(error!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.dangerRose))),
                              ]),
                              if (isUnverified) ...[
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: onResendVerification,
                                  child: Text('Resend verification email →',
                                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.primaryIndigo, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ]),
                          ),
                        ),

                      // Email
                      _Animated(fade: fieldFades[1], slide: fieldSlides[1], child:
                        TextFormField(
                          controller: emailCtrl,
                          validator: Validators.email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.alternate_email_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Password
                      _Animated(fade: fieldFades[2], slide: fieldSlides[2], child:
                        TextFormField(
                          controller: passCtrl,
                          validator: Validators.password,
                          obscureText: obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!loading) onSubmit();
                          },
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                              onPressed: onToggleObscure,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Forgot password
                      _Animated(fade: fieldFades[2], slide: fieldSlides[2], child:
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: onForgotPassword,
                            style: TextButton.styleFrom(foregroundColor: AppColors.primaryIndigo, padding: EdgeInsets.zero),
                            child: Text('Forgot password?', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sign In button
                      _Animated(fade: fieldFades[3], slide: fieldSlides[3], child:
                        _GradientButton(
                          label: 'Sign In',
                          loading: loading,
                          onPressed: loading ? null : onSubmit,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Divider
                      _Animated(fade: fieldFades[4], slide: fieldSlides[4], child:
                        Row(children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                          ),
                          const Expanded(child: Divider()),
                        ]),
                      ),
                      const SizedBox(height: 20),

                      // Register link
                      _Animated(fade: fieldFades[4], slide: fieldSlides[4], child:
                        Center(
                          child: RichText(text: TextSpan(
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
                            children: [
                              const TextSpan(text: "Don't have an account? "),
                              WidgetSpan(child: GestureDetector(
                                onTap: onRegister,
                                child: Text('Sign up', style: GoogleFonts.inter(
                                  fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryIndigo)),
                              )),
                            ],
                          )),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reusable animated wrapper ───────────────────────────────────────────────

class _Animated extends StatelessWidget {
  final Animation<double> fade;
  final Animation<Offset> slide;
  final Widget child;
  const _Animated({required this.fade, required this.slide, required this.child});

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: fade,
    child: SlideTransition(position: slide, child: child),
  );
}

// ── Gradient button with hover glow ─────────────────────────────────────────

class _GradientButton extends StatefulWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  const _GradientButton({required this.label, required this.loading, this.onPressed});

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
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
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text(widget.label),
          ),
        ),
      ),
    );
  }
}

// ── Aurora background CustomPainter ─────────────────────────────────────────

class _AuroraPainter extends CustomPainter {
  final double t;
  _AuroraPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _orb(canvas, size,
      cx: 0.15 + 0.08 * math.sin(t * 2 * math.pi),
      cy: 0.25 + 0.07 * math.cos(t * 2 * math.pi * 0.7),
      r: 0.40, color: const Color(0xFF6366F1), opacity: 0.45);
    _orb(canvas, size,
      cx: 0.75 + 0.06 * math.cos(t * 2 * math.pi * 1.3),
      cy: 0.40 + 0.08 * math.sin(t * 2 * math.pi * 0.9),
      r: 0.33, color: const Color(0xFF8B5CF6), opacity: 0.35);
    _orb(canvas, size,
      cx: 0.45 + 0.10 * math.sin(t * 2 * math.pi * 0.5),
      cy: 0.80 + 0.06 * math.cos(t * 2 * math.pi * 1.1),
      r: 0.28, color: const Color(0xFFEC4899), opacity: 0.28);
  }

  void _orb(Canvas canvas, Size size, {required double cx, required double cy,
      required double r, required Color color, required double opacity}) {
    final center = Offset(size.width * cx, size.height * cy);
    final radius = size.width * r;
    canvas.drawCircle(center, radius, Paint()
      ..shader = RadialGradient(
        colors: [color.withOpacity(opacity), color.withOpacity(0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius)));
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t;
}

// ── Subtle dot-grid overlay ──────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.03)..strokeWidth = 1;
    const step = 36.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.2, p);
      }
    }
  }
  @override
  bool shouldRepaint(_GridPainter _) => false;
}
