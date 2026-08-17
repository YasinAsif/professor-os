import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../data/auth_repository.dart';

import '../../../core/utils/error_parser.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
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
  bool _approvalRequired = false;

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
    setState(() { _loading = true; _error = null; });
    try {
      final result = await AuthRepository().register(_emailCtrl.text.trim(), _nameCtrl.text.trim(), _passCtrl.text, _role);
      _verificationToken = result['token'];
      _approvalRequired = result['approval_required'] == true;
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) setState(() => _error = ErrorParser.parse(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
            child: _done ? _buildSuccess() : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 64, height: 64,
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: (_approvalRequired ? const Color(0xFFD97706) : AppColors.verified).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _approvalRequired ? Icons.pending_actions_rounded : Icons.mark_email_read_rounded,
            color: _approvalRequired ? const Color(0xFFD97706) : AppColors.verified,
            size: 32,
          ),
        ),
        Text(
          _approvalRequired ? 'Approval Pending' : 'Check your inbox',
          style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.inkPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          _approvalRequired
            ? 'Your ${_role} account has been registered.\nAn admin will review and approve your account before you can sign in.'
            : 'We sent a verification link to\n${_emailCtrl.text}',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.inkSecondary, height: 1.5),
        ),
        const SizedBox(height: 32),

        if (_verificationToken != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.verified.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Text('Demo Direct Access', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.verified)),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.verified,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  onPressed: _verifyingInstantly ? null : () async {
                    setState(() => _verifyingInstantly = true);
                    try {
                      await AuthRepository().verifyEmail(_verificationToken!);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account verified successfully!')));
                        context.go('/auth/login');
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification error: $e')));
                    } finally {
                      if (mounted) setState(() => _verifyingInstantly = false);
                    }
                  },
                  child: _verifyingInstantly ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Verify Account Instantly'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        ElevatedButton(
          onPressed: () => context.go('/auth/login'),
          child: const Text('Go to Sign In'),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _resending ? null : () async {
            setState(() => _resending = true);
            try {
              await AuthRepository().resendVerification(_emailCtrl.text.trim());
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification email resent!')));
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Resending failed: $e')));
            } finally {
              if (mounted) setState(() => _resending = false);
            }
          },
          child: _resending
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("Didn't receive email? Resend link"),
        ),
      ]
    );
  }

  Widget _buildForm() {
    final strengthColors = [AppColors.feedbackRed, const Color(0xFFD97706), AppColors.pending, AppColors.verified, AppColors.verified];
    final strengthLabels = ['Too weak', 'Weak', 'Fair', 'Strong', 'Very strong'];

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ProfessorOS', style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.inkPrimary), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Create your account', style: GoogleFonts.inter(fontSize: 14, color: AppColors.inkSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 32),

          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 24),
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

          TextFormField(
            controller: _nameCtrl,
            validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your full name' : null,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Full Name'),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _emailCtrl,
            validator: Validators.email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Email address'),
          ),
          const SizedBox(height: 24),

          Text('I am a…', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final r in [('professor', 'Professor'), ('student', 'Student'), ('ta', 'TA')])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: r.$1 != 'ta' ? 8 : 0),
                    child: _RolePill(label: r.$2, selected: _role == r.$1, onTap: () => setState(() => _role = r.$1)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: _passCtrl,
            validator: Validators.password,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_loading) _submit();
            },
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          
          if (_passCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: List.generate(4, (i) => Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: i < _strength ? strengthColors[_strength] : AppColors.marginRule,
                  ),
                ),
              )),
            ),
            const SizedBox(height: 4),
            Text(_strength > 0 ? strengthLabels[_strength] : '',
              style: GoogleFonts.inter(fontSize: 11, color: strengthColors[_strength.clamp(0, 4)], fontWeight: FontWeight.w500)),
          ],

          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Create Account'),
          ),

          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: () => context.go('/auth/login'),
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.inkSecondary),
                  children: [
                    const TextSpan(text: 'Already have an account? '),
                    TextSpan(text: 'Sign in', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.signal)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RolePill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.bgActive : AppColors.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppColors.signal : AppColors.marginRule, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected ? AppColors.inkPrimary : AppColors.inkSecondary,
          ),
        ),
      ),
    );
  }
}
