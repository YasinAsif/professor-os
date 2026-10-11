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
      children: visibleReasons
          .map((reason) => ProfBadge(
                label: submissionTriageLabel(reason),
                color: AppColors.accentAmber,
              ))
          .toList(),
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
                label: Text(entry.value),
                selected: selected == entry.key,
                onSelected: (_) => onSelected(entry.key),
              ))
          .toList(),
    );
  }
}
