/// ProfessorOS – ProfSearchBar: Debounced search with magnifying glass.

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ProfSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String hintText;
  final Duration debounceDuration;

  const ProfSearchBar({
    super.key,
    required this.onChanged,
    this.hintText = 'Search...',
    this.debounceDuration = const Duration(milliseconds: 300),
  });

  @override
  State<ProfSearchBar> createState() => _ProfSearchBarState();
}

class _ProfSearchBarState extends State<ProfSearchBar> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(widget.debounceDuration, () {
      widget.onChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hintColor = isDark ? AppColors.inkGhost : AppColorsLight.inkGhost;
    final iconColor = isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary;
    final borderColor = isDark ? AppColors.rule : AppColorsLight.ruleStrong;
    final fillColor = isDark ? AppColors.surface : Colors.white;

    return TextField(
      onChanged: _onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: fillColor,
        hintText: widget.hintText,
        hintStyle: TextStyle(color: hintColor, fontSize: 14),
        prefixIcon: Icon(Icons.search_rounded, color: iconColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.r8),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.r8),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.r8),
          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
        ),
      ),
    );
  }
}
