/// ProfessorOS – Forgot Password Screen.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_parser.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/prof_button.dart';
import '../data/auth_repository.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _done = false;
  String? _error;

  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthRepository().forgotPassword(_emailCtrl.text.trim());
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) setState(() => _error = ErrorParser.parse(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgPage = isDark ? AppColors.bgPage : AppColorsLight.bgPage;
    final surfaceColor = isDark ? AppColors.surface : AppColorsLight.surface;
    final ruleColor = isDark ? AppColors.rule : AppColorsLight.rule;

    return Scaffold(
      backgroundColor: bgPage,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
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
                    child: _done ? _buildSuccess() : _buildForm(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary = isDark ? AppColors.inkPrimary : AppColorsLight.inkPrimary;
    final inkSecondary = isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.verified.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.verified.withOpacity(0.3), width: 1.5),
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              color: AppColors.verified,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Instructions Dispatched',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: inkPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'If an active academic account exists for that email,\nyou will receive a password reset link shortly.',
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: inkSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ProfButton(
          label: 'Return to Sign In',
          icon: Icons.arrow_back_rounded,
          variant: ProfButtonVariant.primary,
          size: ProfButtonSize.lg,
          isExpanded: true,
          onPressed: () => context.go('/auth/login'),
        ),
      ],
    );
  }

  Widget _buildForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary = isDark ? AppColors.inkPrimary : AppColorsLight.inkPrimary;
    final inkSecondary = isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary;
    final ruleColor = isDark ? AppColors.rule : AppColorsLight.rule;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Back navigation
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => context.go('/auth/login'),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_rounded, size: 16, color: inkSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Back to sign in',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Icon badge
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.academicTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.academicTeal.withOpacity(0.25),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.lock_reset_rounded,
                size: 28,
                color: AppColors.academicTeal,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'Reset Password',
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: inkPrimary,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your registered institutional email to receive a secure recovery link.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: inkSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

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
              child: Row(
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
            ),
            const SizedBox(height: 16),
          ],

          // Email field
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
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_loading) _submit();
            },
            style: GoogleFonts.inter(fontSize: 14, color: inkPrimary),
            decoration: InputDecoration(
              hintText: 'name@university.edu.pk',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: inkSecondary.withOpacity(0.6)),
              prefixIcon: Icon(Icons.alternate_email_rounded, size: 18, color: inkSecondary),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              filled: true,
              fillColor: isDark ? AppColors.surfaceMid : const Color(0xFFF8FAFC),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: ruleColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.academicTeal, width: 1.5),
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

          // Send Instructions Button
          ProfButton(
            label: 'Send Reset Link',
            icon: Icons.send_rounded,
            variant: ProfButtonVariant.cta,
            size: ProfButtonSize.lg,
            isExpanded: true,
            isLoading: _loading,
            onPressed: _loading ? null : _submit,
          ),
        ],
      ),
    );
  }
}
