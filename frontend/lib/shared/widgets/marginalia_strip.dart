import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class MarginaliaStrip extends StatefulWidget {
  final String statusLabel;
  final Color statusColor;
  final String? score;
  final String? grader;
  final bool recentlySaved;

  const MarginaliaStrip({
    super.key,
    required this.statusLabel,
    required this.statusColor,
    this.score,
    this.grader,
    this.recentlySaved = false,
  });

  @override
  State<MarginaliaStrip> createState() => _MarginaliaStripState();
}

class _MarginaliaStripState extends State<MarginaliaStrip> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _opacity = Tween<double>(begin: 0.5, end: 1.0).animate(_controller);
    _offset = Tween<Offset>(begin: const Offset(0, -0.05), end: Offset.zero).animate(_controller);

    if (widget.recentlySaved) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant MarginaliaStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recentlySaved && !oldWidget.recentlySaved) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildContent() {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.marginRule, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Status Dot + Label
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: widget.statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                widget.statusLabel,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkSecondary,
                ),
              ),
            ],
          ),
          
          if (widget.score != null) ...[
            const SizedBox(height: 8),
            // Mono Score
            Text(
              widget.score!,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                // If it has a score, we use feedbackRed if it's graded by system/prof, or just keep it semantic
                color: widget.statusColor == AppColors.verified 
                    ? AppColors.verified 
                    : AppColors.inkPrimary,
              ),
            ),
          ],

          if (widget.grader != null) ...[
            const SizedBox(height: 4),
            // Grader Attribution
            Text(
              widget.grader!,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.feedbackRed,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.recentlySaved) {
      return SlideTransition(
        position: _offset,
        child: FadeTransition(
          opacity: _opacity,
          child: _buildContent(),
        ),
      );
    }
    return _buildContent();
  }
}
