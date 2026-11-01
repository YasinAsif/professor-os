/// ProfessorOS – ProfWeightSlider: Slider with synced number input.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class ProfWeightSlider extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final double max;
  final String? label;
  final bool readOnly;

  const ProfWeightSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.max = 100,
    this.label,
    this.readOnly = false,
  });

  @override
  State<ProfWeightSlider> createState() => _ProfWeightSliderState();
}

class _ProfWeightSliderState extends State<ProfWeightSlider> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toInt().toString());
  }

  @override
  void didUpdateWidget(covariant ProfWeightSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final currentParsed = double.tryParse(_controller.text) ?? -1;
      if (currentParsed.toInt() != widget.value.toInt()) {
        _controller.text = widget.value.toInt().toString();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (widget.label != null) ...[
          SizedBox(
            width: 125,
            child: Row(
              children: [
                if (widget.readOnly) ...[
                  const Icon(Icons.lock_outline_rounded,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    widget.label!,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.readOnly
                            ? AppColors.textMuted
                            : AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: widget.readOnly
                  ? AppColors.border
                  : AppColors.primaryIndigo,
              inactiveTrackColor: AppColors.border,
              thumbColor: widget.readOnly
                  ? AppColors.textMuted
                  : AppColors.primaryIndigo,
              disabledThumbColor: AppColors.textMuted,
              disabledActiveTrackColor: AppColors.border,
              overlayColor: widget.readOnly
                  ? Colors.transparent
                  : AppColors.primaryIndigo.withOpacity(0.12),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: widget.value.clamp(0, widget.max),
              min: 0,
              max: widget.max,
              divisions: widget.max > 0 ? widget.max.toInt() : 1,
              onChanged: widget.readOnly
                  ? null
                  : (v) {
                      _controller.text = v.toInt().toString();
                      widget.onChanged(v);
                    },
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 68,
          child: TextFormField(
            controller: _controller,
            readOnly: widget.readOnly,
            enabled: !widget.readOnly,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: widget.readOnly
                    ? AppColors.textMuted
                    : AppColors.primaryIndigo),
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              isDense: true,
              suffixText: '%',
              suffixStyle:
                  GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
              fillColor: widget.readOnly
                  ? (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9))
                  : AppColors.bgSurface,
              filled: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border)),
              disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: AppColors.border.withOpacity(0.5))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: AppColors.primaryIndigo, width: 1.5)),
            ),
            onChanged: (text) {
              if (widget.readOnly) return;
              final parsed = double.tryParse(text);
              if (parsed != null && parsed >= 0 && parsed <= widget.max) {
                widget.onChanged(parsed);
              }
            },
          ),
        ),
      ],
    );
  }
}
