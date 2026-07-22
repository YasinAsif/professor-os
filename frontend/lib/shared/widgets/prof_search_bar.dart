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
    return TextField(
      onChanged: _onChanged,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
