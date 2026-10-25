/// ProfessorOS – Reset Password Screen.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_parser.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/prof_button.dart';
import '../data/auth_repository.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? token;
  const ResetPasswordScreen({super.key, this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  int get _strength => Validators.passwordStrength(_passCtrl.text);

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
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthRepository().resetPassword(widget.token ?? '', _passCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successfully! Please sign in with your new password.'),
            backgroundColor: AppColors.verified,
          ),
        );
        context.go('/auth/login');
      }
    } catch (e) {
      setState(() => _error = ErrorParser.parse(e));
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
    final inkPrimary = isDark ? AppColors.inkPrimary : AppColorsLight.inkPrimary;
    final inkSecondary = isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary;

    final strengthColors = [
      AppColors.dangerRose,
      const Color(0xFFEA580C),
      AppColors.accentAmber,
      AppColors.successGreen,
      AppColors.successGreen,
    ];
    final strengthLabels = [
      'Too weak',
      'Weak',
      'Fair',
      'Strong',
      'Very strong',
    ];

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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                                Icons.key_rounded,
                                size: 28,
                                color: AppColors.academicTeal,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Create New Password',
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
                            'Your new password must be secure and different from previous passwords.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: inkSecondary,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
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

                          // New password
                          Text(
                            'New Password',
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
                            obscureText: _obscurePass,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => setState(() {}),
                            style: GoogleFonts.inter(fontSize: 14, color: inkPrimary),
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              prefixIcon: Icon(Icons.lock_outline_rounded, size: 18, color: inkSecondary),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 18,
                                  color: inkSecondary,
                                ),
                                onPressed: () => setState(() => _obscurePass = !_obscurePass),
                              ),
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
                                          : (isDark ? AppColors.ruleStrong : const Color(0xFFE2E8F0)),
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
                          const SizedBox(height: 16),

                          // Confirm password
                          Text(
                            'Confirm New Password',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: inkPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _confirmCtrl,
                            obscureText: _obscureConfirm,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!_loading) _submit();
                            },
                            validator: (v) => v != _passCtrl.text
                                ? 'Passwords do not match.'
                                : null,
                            style: GoogleFonts.inter(fontSize: 14, color: inkPrimary),
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              prefixIcon: Icon(Icons.lock_reset_rounded, size: 18, color: inkSecondary),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 18,
                                  color: inkSecondary,
                                ),
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
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

                          // Update button
                          ProfButton(
                            label: 'Update Password',
                            icon: Icons.check_circle_outline_rounded,
                            variant: ProfButtonVariant.cta,
                            size: ProfButtonSize.lg,
                            isExpanded: true,
                            isLoading: _loading,
                            onPressed: _loading ? null : _submit,
                          ),
                        ],
                      ),
                    ),
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
