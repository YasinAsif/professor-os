import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';

/// Screen displayed when a student attempts to take an exam from a mobile web browser.
/// Enforces HEC Zero-Trust Proctoring requirements: students must use a desktop computer
/// or the secure Android Native Application with Kiosk mode.
class ExamMobileBlockView extends StatelessWidget {
  final VoidCallback? onBackToDashboard;
  final String? apkDownloadUrl;

  const ExamMobileBlockView({
    super.key,
    this.onBackToDashboard,
    this.apkDownloadUrl,
  });

  Future<void> _handleDownloadApk(BuildContext context) async {
    final urlString = apkDownloadUrl ?? '/static/downloads/professor_os_student.apk';
    final uri = Uri.tryParse(urlString);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('APK download link will be available from your institution portal.'),
            backgroundColor: AppColors.primaryIndigo,
          ),
        );
      }
    }
  }

  void _handleBack(BuildContext context) {
    if (onBackToDashboard != null) {
      onBackToDashboard!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate background for security screen
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                color: const Color(0xFF1E293B),
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Red Lock / Security Shield Icon
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withAlpha(38),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          size: 56,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        'Secure App Required',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Subtitle
                      Text(
                        'Mobile Web Browser Detected',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFCA5A5),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Policy Explanation
                      Text(
                        'To maintain academic integrity and prevent cheating, exams cannot be taken on mobile web browsers (including desktop mode).\n\nPlease open this exam on a desktop computer or install the official ProfessorOS Android Student App with Lock Task Mode.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.5,
                          color: const Color(0xFFCBD5E1),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Primary Action: Download APK
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () => _handleDownloadApk(context),
                          icon: const Icon(Icons.android, color: Colors.white),
                          label: Text(
                            'Download Android App (APK)',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Secondary Action: Go Back to Dashboard
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _handleBack(context),
                          icon: const Icon(Icons.arrow_back, color: Color(0xFF94A3B8)),
                          label: Text(
                            'Return to Dashboard',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF334155)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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
