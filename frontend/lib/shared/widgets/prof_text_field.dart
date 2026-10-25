import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class ProfTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final int? maxLines;
  final int? minLines;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;

  const ProfTextField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.minLines,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<ProfTextField> createState() => _ProfTextFieldState();
}

class _ProfTextFieldState extends State<ProfTextField> {
  late FocusNode _focusNode;
  bool _internalFocusNode = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _focusNode = FocusNode();
      _internalFocusNode = true;
    } else {
      _focusNode = widget.focusNode!;
    }
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted && _focusNode.hasFocus != _isFocused) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (_internalFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final labelColor = isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary;
    final textColor = isDark ? AppColors.inkPrimary : AppColorsLight.inkPrimary;
    final hintColor = isDark ? AppColors.inkGhost : AppColorsLight.inkGhost;
    final bgColor = isDark ? AppColors.surface : AppColorsLight.surface;
    final ruleColor = isDark ? AppColors.rule : AppColorsLight.rule;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null && widget.label!.isNotEmpty) ...[
          Text(
            widget.label!,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _isFocused ? const Color(0xFF4F46E5) : labelColor,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: textColor,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hintText,
            helperText: widget.helperText,
            errorText: widget.errorText,
            filled: true,
            fillColor: bgColor,
            prefixIcon: widget.prefixIcon,
            suffixIcon: widget.suffixIcon,
            hintStyle: GoogleFonts.inter(
              fontSize: 14,
              color: hintColor,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.r8),
              borderSide: BorderSide(color: ruleColor, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.r8),
              borderSide: BorderSide(color: ruleColor, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.r8),
              borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.r8),
              borderSide: const BorderSide(color: AppColors.statusCriticalInk, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.r8),
              borderSide: const BorderSide(color: AppColors.statusCriticalInk, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
