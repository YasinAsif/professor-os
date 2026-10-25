import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/error_parser.dart';
import '../../../core/utils/validators.dart';
import '../data/auth_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _role = 'professor';
  bool _obscure = true;
  bool _loading = false;
  bool _done = false;
  String? _error;

  int get _strength => Validators.passwordStrength(_passCtrl.text);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthRepository().register(
        _emailCtrl.text.trim(),
        _nameCtrl.text.trim(),
        _passCtrl.text,
        _role,
      );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) setState(() => _error = ErrorParser.parse(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeStateProvider);
    final isDark = themeState.themeMode == JournalThemeMode.dark;
    final bgPage = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final ruleColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inkPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final inkSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgPage,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 920;

          if (isWide) {
            return Row(
              children: [
                Expanded(
                  flex: 5,
                  child: _buildShowcasePanel(),
                ),
                Expanded(
                  flex: 6,
                  child: Container(
                    color: surfaceColor,
                    height: double.infinity,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 24,
                          right: 24,
                          child: _buildThemeToggle(isDark),
                        ),
                        Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: _done
                                  ? _buildSuccess(inkPrimary, inkSecondary)
                                  : _buildForm(isDark, inkPrimary, inkSecondary, ruleColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return Stack(
            children: [
              Positioned(
                top: 16,
                right: 16,
                child: _buildThemeToggle(isDark),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ruleColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                      child: _done
                          ? _buildSuccess(inkPrimary, inkSecondary)
                          : _buildForm(isDark, inkPrimary, inkSecondary, ruleColor),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildThemeToggle(bool isDark) {
    return InkWell(
      onTap: () => ref.read(themeStateProvider.notifier).toggleThemeMode(),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 15,
              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF4F46E5),
            ),
            const SizedBox(width: 6),
            Text(
              isDark ? 'Light Mode' : 'Dark Mode',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShowcasePanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF090D16),
            Color(0xFF0F172A),
            Color(0xFF1E1B4B),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF0D9488)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Text(
                'ProfessorOS',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Institutional\nAccount Registration.',
                style: GoogleFonts.outfit(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Join your university\'s academic assessment network. Roles are verified by faculty administrators before exam and grading permissions are provisioned.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF94A3B8),
                  height: 1.6,
                ),
              ),
            ],
          ),
          Text(
            'Shifa Tameer-e-Millat University • Department of Computing',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(Color inkPrimary, Color inkSecondary) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFD97706).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              color: Color(0xFFD97706),
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Registration Submitted',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: inkPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Your $_role account request has been recorded.\nAn administrator will review and approve your credentials before sign in.',
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: inkSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => context.go('/auth/login'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Return to Sign In'),
        ),
      ],
    );
  }

  Widget _buildForm(
    bool isDark,
    Color inkPrimary,
    Color inkSecondary,
    Color ruleColor,
  ) {
    final strengthColors = [
      AppColors.feedbackRed,
      const Color(0xFFD97706),
      AppColors.pending,
      AppColors.verified,
      AppColors.verified,
    ];
    final strengthLabels = [
      'Too weak',
      'Weak',
      'Fair',
      'Strong',
      'Very strong',
    ];

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create Account',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: inkPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sign up with your university email address.',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: inkSecondary,
            ),
          ),
          const SizedBox(height: 24),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.feedbackRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.feedbackRed.withOpacity(0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.feedbackRed),
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
            const SizedBox(height: 16),
          ],

          // Full Name
          Text(
            'Full Name',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: inkPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameCtrl,
            validator: (v) => (v == null || v.trim().length < 2)
                ? 'Enter your full name'
                : null,
            textInputAction: TextInputAction.next,
            style: GoogleFonts.inter(fontSize: 14, color: inkPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. Dr. Muhammad Tariq',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: inkSecondary.withOpacity(0.5)),
              prefixIcon: Icon(Icons.person_outline_rounded, size: 18, color: inkSecondary),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: ruleColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Email
          Text(
            'Institutional Email',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: inkPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailCtrl,
            validator: Validators.email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: GoogleFonts.inter(fontSize: 14, color: inkPrimary),
            decoration: InputDecoration(
              hintText: 'name@university.edu.pk',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: inkSecondary.withOpacity(0.5)),
              prefixIcon: Icon(Icons.alternate_email_rounded, size: 18, color: inkSecondary),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: ruleColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Role selection
          Text(
            'Academic Role',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: inkPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final r in [
                ('professor', 'Professor', Icons.school_outlined),
                ('student', 'Student', Icons.person_outline_rounded),
                ('ta', 'TA', Icons.co_present_outlined),
              ])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: r.$1 != 'ta' ? 8 : 0),
                    child: InkWell(
                      onTap: () => setState(() => _role = r.$1),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _role == r.$1
                              ? const Color(0xFF4F46E5).withOpacity(0.12)
                              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _role == r.$1
                                ? const Color(0xFF4F46E5)
                                : ruleColor,
                            width: _role == r.$1 ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              r.$3,
                              size: 18,
                              color: _role == r.$1
                                  ? const Color(0xFF4F46E5)
                                  : inkSecondary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              r.$2,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: _role == r.$1 ? FontWeight.w600 : FontWeight.w500,
                                color: _role == r.$1
                                    ? const Color(0xFF4F46E5)
                                    : inkPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Password
          Text(
            'Password',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: inkPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passCtrl,
            validator: Validators.password,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_loading) _submit();
            },
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.inter(fontSize: 14, color: inkPrimary),
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: inkSecondary.withOpacity(0.5)),
              prefixIcon: Icon(Icons.lock_outline_rounded, size: 18, color: inkSecondary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: inkSecondary,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: ruleColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
              ),
            ),
          ),

          if (_passCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: List.generate(
                4,
                (i) => Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: i < _strength
                          ? strengthColors[_strength]
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _strength > 0 ? strengthLabels[_strength] : '',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: strengthColors[_strength.clamp(0, 4)],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Register Button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Create Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 24),

          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Already have an account? ', style: GoogleFonts.inter(fontSize: 13.5, color: inkSecondary)),
                GestureDetector(
                  onTap: () => context.go('/auth/login'),
                  child: Text('Sign in', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF4F46E5))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
