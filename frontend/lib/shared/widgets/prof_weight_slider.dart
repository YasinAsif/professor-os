/// ProfessorOS – ProfWeightSlider: Slider with synced number input.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class ProfWeightSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final double max;
  final String? label;

  const ProfWeightSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.max = 100,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (label != null) ...[
          SizedBox(
            width: 110,
            child: Text(
              label!,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primaryIndigo,
              inactiveTrackColor: AppColors.border,
              thumbColor: AppColors.primaryIndigo,
              overlayColor: AppColors.primaryIndigo.withOpacity(0.12),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value.clamp(0, max),
              min: 0,
              max: max,
              divisions: max > 0 ? max.toInt() : 1,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: TextFormField(
            key: ValueKey('weight_input_${label}_${value.toInt()}'),
            initialValue: value.toInt().toString(),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primaryIndigo),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              isDense: true,
              suffixText: '%',
              suffixStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
              fillColor: AppColors.bgSurface,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primaryIndigo, width: 1.5)),
            ),
            onChanged: (text) {
              final parsed = double.tryParse(text);
              if (parsed != null && parsed >= 0 && parsed <= max) {
                onChanged(parsed);
              }
            },
          ),
        ),
      ],
    );
  }
}
