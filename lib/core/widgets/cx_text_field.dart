import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// The Crux text field. Filled surface, chunky radius, ultraviolet focus
/// ring, honest inline error text.
class CxTextField extends StatelessWidget {
  const CxTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: CxType.label.copyWith(color: c.textSecondary)),
          const SizedBox(height: CxSpace.sm),
        ],
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          autofocus: autofocus,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: textInputAction,
          style: CxType.body.copyWith(color: c.textPrimary),
          cursorColor: c.ultraviolet,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: CxType.body.copyWith(color: c.textTertiary),
            errorText: errorText,
            errorStyle: CxType.caption.copyWith(color: c.danger),
            filled: true,
            fillColor: c.surfaceHigh,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: CxSpace.lg,
              vertical: CxSpace.lg,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: CxRadii.brMd,
              borderSide: BorderSide(color: c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: CxRadii.brMd,
              borderSide: BorderSide(color: c.ultraviolet, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: CxRadii.brMd,
              borderSide: BorderSide(color: c.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: CxRadii.brMd,
              borderSide: BorderSide(color: c.danger, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
