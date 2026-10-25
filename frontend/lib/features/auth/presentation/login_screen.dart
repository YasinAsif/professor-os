import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/error_parser.dart';
import '../../../core/utils/validators.dart';
import '../data/auth_repository.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  bool _isUnverified = false;
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    if (kIsWeb) return;
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final creds = await DioClient.getBiometricCreds();
      if (canCheck && isDeviceSupported && creds != null) {
        setState(() => _canUseBiometrics = true);
      }
    } catch (_) {}
  }

  Future<void> _authenticateBiometrics() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Scan your fingerprint or face to sign in securely',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (authenticated) {
        final creds = await DioClient.getBiometricCreds();
        if (creds != null) {
          setState(() {
            _loading = true;
            _error = null;
          });
          final newAccess = await DioClient.refreshToken();
          if (newAccess != null) {
            await ref.read(authProvider.notifier).refreshUser();
            final authState = ref.read(authProvider);
            if (mounted && authState.valueOrNull != null) {
              final role = authState.valueOrNull?['role'];
              context.go(role == 'admin' ? '/admin' : '/courses');
              return;
            }
          }
          if (mounted) {
            setState(() => _loading = false);
            _emailCtrl.text = creds['email'] ?? '';
            _showSnack('Biometric session expired. Please enter your password to sign in.');
          }
        }
      }
    } catch (e) {
      _showSnack('Biometric authentication failed or canceled.');
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _quickFill(String email, String password) {
    setState(() {
      _emailCtrl.text = email;
      _passCtrl.text = password;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _isUnverified = false;
    });

    await ref
        .read(authProvider.notifier)
        .login(_emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;

    final authState = ref.read(authProvider);
    if (authState.hasError) {
      final msg = ErrorParser.parse(authState.error!);
      setState(() {
        _error = msg;
        _isUnverified = msg.toLowerCase().contains('verify');
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      final refresh = await DioClient.getRefreshToken();
      if (refresh != null) {
        await DioClient.saveBiometricRefreshToken(
            _emailCtrl.text.trim(), refresh);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed in successfully!'),
            backgroundColor: AppColors.verified,
            duration: Duration(seconds: 2),
          ),
        );
        final role = authState.valueOrNull?['role'];
        context.go(role == 'admin' ? '/admin' : '/courses');
      }
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
      backgroundColor: success ? AppColors.verified : AppColors.feedbackRed,
    ));
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
                // Left Showcase Panel (Hero & Institutional Identity)
                Expanded(
                  flex: 5,
                  child: _buildShowcasePanel(isDark),
                ),
                // Right Authentication Form
                Expanded(
                  flex: 6,
                  child: Container(
                    color: surfaceColor,
                    height: double.infinity,
                    child: Stack(
                      children: [
                        // Theme toggle at top right
                        Positioned(
                          top: 24,
                          right: 24,
                          child: _buildThemeToggle(isDark),
                        ),
                        // Scrollable form container
                        Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: _buildForm(isDark, inkPrimary, inkSecondary, ruleColor),
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

          // Mobile / Narrow layout
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
                      child: _buildForm(isDark, inkPrimary, inkSecondary, ruleColor),
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

  Widget _buildShowcasePanel(bool isDark) {
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
          // Institutional Logo & Brand
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ProfessorOS',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Assessment & Examination Intelligence',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Main Hero Showcase
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF0D9488).withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, size: 13, color: Color(0xFF2DD4BF)),
                    const SizedBox(width: 6),
                    Text(
                      'HEC PAKISTAN OBE COMPLIANT',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: const Color(0xFF2DD4BF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Objective Grading,\nProctored Security & OBE Attainment.',
                style: GoogleFonts.outfit(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'A unified assessment platform engineered for modern higher education institutions, aligning Bloom\'s taxonomy, automated rubric grading, and real-time proctoring.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF94A3B8),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 36),

              // 3 Value Pillars
              _buildFeatureRow(
                icon: Icons.psychology_rounded,
                title: 'AI-Assisted SpeedGrader',
                subtitle: 'Automated criterion evaluation with strict professor approval gating.',
              ),
              const SizedBox(height: 16),
              _buildFeatureRow(
                icon: Icons.security_rounded,
                title: 'Zero-Trust Proctoring',
                subtitle: 'Biometric verification, tab-switch forensic logs & strike adjudication.',
              ),
              const SizedBox(height: 16),
              _buildFeatureRow(
                icon: Icons.assessment_rounded,
                title: 'Instant OBE Attainment Matrices',
                subtitle: 'Live CLO/PLO cohort attainment calculations and HEC dossier exports.',
              ),
            ],
          ),

          // Footer Accreditation
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(color: Color(0xFF1E293B)),
              const SizedBox(height: 12),
              Text(
                'Shifa Tameer-e-Millat University (STMU) • Department of Computing',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF818CF8)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8),
                  height: 1.4,
                ),
              ),
            ],
          ),
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
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            'Sign In',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: inkPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your university credentials to access the academic workspace.',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: inkSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),

          // Error banner
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: AppColors.feedbackRed,
                      ),
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
                  if (_isUnverified) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _resendVerification,
                      child: Text(
                        'Resend verification email →',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: const Color(0xFF4F46E5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Email Field
          Text(
            'Email Address',
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
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.feedbackRed),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.feedbackRed, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Password Field
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Password',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: inkPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/auth/forgot-password'),
                child: Text(
                  'Forgot password?',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF4F46E5),
                  ),
                ),
              ),
            ],
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
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.feedbackRed),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.feedbackRed, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Primary Sign In Button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Sign In',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
            ),
          ),

          if (_canUseBiometrics) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loading ? null : _authenticateBiometrics,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: BorderSide(color: ruleColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.fingerprint_rounded, size: 20),
              label: Text(
                'Sign in with Biometrics',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: inkPrimary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),

          // Demo Accounts quick-fill bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ruleColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt_rounded, size: 14, color: const Color(0xFF4F46E5)),
                    const SizedBox(width: 4),
                    Text(
                      'TEST / DEMO ACCOUNTS',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: inkSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _QuickFillButton(
                        label: 'Professor',
                        isDark: isDark,
                        onTap: () => _quickFill('prof@example.com', 'password123'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _QuickFillButton(
                        label: 'Student',
                        isDark: isDark,
                        onTap: () => _quickFill('student@example.com', 'password123'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _QuickFillButton(
                        label: 'Admin',
                        isDark: isDark,
                        onTap: () => _quickFill('admin@professoros.edu.pk', 'password123'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sign up link
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Don't have an account? ",
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: inkSecondary,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go('/auth/register'),
                  child: Text(
                    'Register',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickFillButton extends StatelessWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickFillButton({
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }
}
