import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'prof_badge.dart';

const submissionTriageFilters = <String, String>{
  'all': 'All',
  'needs_review': 'Needs Human Review',
  'prompt_injection': 'Prompt Injection',
  'unreadable': 'Unreadable / Scanned',
  'ungraded': 'Ungraded',
  'graded': 'Graded',
};

String submissionTriageLabel(String code) {
  switch (code) {
    case 'blank_or_unreadable':
      return 'Unreadable / Blank Document';
    case 'scanned_or_image_only':
      return 'Scanned / Image-Only PDF';
    case 'truncated_oversized_file':
      return 'Truncated Oversized File';
    case 'injection_detected':
      return 'Adversarial Prompt / Injection Detected';
    default:
      return code.replaceAll('_', ' ');
  }
}

class SubmissionTriageBadges extends StatelessWidget {
  final Map<String, dynamic> submission;
  const SubmissionTriageBadges({super.key, required this.submission});

  static (Color text, Color bg, Color border) badgeThemeFor(String reason) {
    switch (reason) {
      case 'injection_detected':
        // Danger: Text #B91C1C, Bg #FEE2E2, Border #FCA5A5
        return (
          AppColorsLight.statusCriticalInk,
          AppColorsLight.statusCriticalBg,
          AppColorsLight.statusCriticalBorder
        );
      case 'blank_or_unreadable':
      case 'scanned_or_image_only':
      case 'truncated_oversized_file':
      case 'needs_review':
      case 'human_review_required':
        // Warning: Text #B45309, Bg #FEF3C7, Border #FCD34D
        return (
          AppColorsLight.statusPendingInk,
          AppColorsLight.statusPendingBg,
          AppColorsLight.statusPendingBorder
        );
      default:
        // Neutral: Text #334155, Bg #F1F5F9, Border #CBD5E1
        return (
          AppColorsLight.statusNeutralInk,
          AppColorsLight.statusNeutralBg,
          AppColorsLight.statusNeutralBorder
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasons = (submission['triage_reasons'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList() ??
        const <String>[];
    final needsReview =
        submission['needs_review'] == true || reasons.isNotEmpty;
    if (!needsReview) return const SizedBox.shrink();
    final visibleReasons =
        reasons.isEmpty ? const ['human_review_required'] : reasons;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: visibleReasons.map((reason) {
        final colors = badgeThemeFor(reason);
        return ProfBadge(
          label: submissionTriageLabel(reason),
          color: colors.$1,
          backgroundColor: colors.$2,
          borderColor: colors.$3,
        );
      }).toList(),
    );
  }
}

class SubmissionTriageFilterChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  final bool includeGraded;

  const SubmissionTriageFilterChips({
    super.key,
    required this.selected,
    required this.onSelected,
    this.includeGraded = true,
  });

  @override
  Widget build(BuildContext context) {
    final filters = submissionTriageFilters.entries.where(
      (entry) => includeGraded || entry.key != 'graded',
    );
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: filters
          .map((entry) => ChoiceChip(
                label: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected == entry.key
                        ? AppColorsLight.chipText
                        : AppColorsLight.inkSecondary,
                  ),
                ),
                selected: selected == entry.key,
                selectedColor: AppColorsLight.chipFill,
                backgroundColor: AppColorsLight.surfaceMid,
                side: BorderSide(
                  color: selected == entry.key
                      ? AppColorsLight.primaryAction
                      : AppColorsLight.ruleStrong,
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                ),
                onSelected: (_) => onSelected(entry.key),
              ))
          .toList(),
    );
  }
}
