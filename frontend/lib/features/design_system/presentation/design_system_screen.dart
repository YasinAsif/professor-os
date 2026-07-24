import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class DesignSystemScreen extends StatelessWidget {
  const DesignSystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Design System',
                style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.01, color: AppColors.inkPrimary)),
            Text('Marginalia v1.0 Guidelines',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkSecondary, fontWeight: FontWeight.w400)),
          ],
        ),
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.inkPrimary),
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString('assets/docs/DESIGN_SYSTEM.md'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.signal));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load design system docs:\n${snapshot.error}',
                  style: GoogleFonts.inter(color: AppColors.feedbackRed)),
            );
          }

          final markdownData = snapshot.data ?? '';

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  border: Border.all(color: AppColors.marginRule),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Markdown(
                    data: markdownData,
                    padding: const EdgeInsets.all(32),
                    styleSheet: MarkdownStyleSheet(
                      h1: GoogleFonts.fraunces(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.inkPrimary, letterSpacing: -0.02),
                      h2: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.inkPrimary, letterSpacing: -0.02),
                      h3: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.inkPrimary, letterSpacing: -0.02),
                      h4: GoogleFonts.fraunces(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.inkPrimary),
                      p: GoogleFonts.inter(fontSize: 15, color: AppColors.inkSecondary, height: 1.6),
                      listBullet: GoogleFonts.inter(fontSize: 15, color: AppColors.inkPrimary),
                      code: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        color: AppColors.inkPrimary,
                        backgroundColor: AppColors.bgMargin,
                      ),
                      codeblockPadding: const EdgeInsets.all(16),
                      codeblockDecoration: BoxDecoration(
                        color: AppColors.bgMargin,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.marginRule),
                      ),
                      blockquote: GoogleFonts.inter(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        color: AppColors.inkSecondary,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        border: Border(left: BorderSide(color: AppColors.signal, width: 4)),
                        color: AppColors.bgMargin,
                      ),
                      tableBorder: TableBorder.all(color: AppColors.marginRule, width: 1),
                      tableHead: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkPrimary),
                      tableBody: GoogleFonts.inter(fontSize: 14, color: AppColors.inkSecondary),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
