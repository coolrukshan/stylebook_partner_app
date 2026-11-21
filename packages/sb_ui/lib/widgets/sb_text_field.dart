import 'package:flutter/material.dart';
import '../theme/sb_theme.dart';

/// StyleBook styled text input.
class SbTextField extends StatelessWidget {
  const SbTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixText,
    this.prefix,
    this.errorText,
    this.keyboardType,
    this.autofocus = false,
    this.enabled = true,
    this.onChanged,
    this.onFieldSubmitted,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? prefixText;
  final Widget? prefix;
  final String? errorText;
  final TextInputType? keyboardType;
  final bool autofocus;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: context.text.labelMedium!.copyWith(
              color: SbColors.text2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: controller,
          enabled: enabled,
          autofocus: autofocus,
          keyboardType: keyboardType,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          style: context.text.bodyLarge!.copyWith(
            color: SbColors.text,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: context.text.bodyLarge!.copyWith(color: SbColors.subtle),
            prefixText: prefixText,
            prefixStyle: context.text.bodyLarge!.copyWith(
              color: SbColors.text,
              fontWeight: FontWeight.w600,
            ),
            prefixIcon: prefix,
            filled: true,
            fillColor: enabled ? SbColors.inputFill : SbColors.soft,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SbTokens.rInput),
              borderSide: const BorderSide(color: SbColors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SbTokens.rInput),
              borderSide: const BorderSide(color: SbColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SbTokens.rInput),
              borderSide: const BorderSide(color: SbColors.amber, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SbTokens.rInput),
              borderSide: const BorderSide(color: SbColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SbTokens.rInput),
              borderSide: const BorderSide(color: SbColors.danger, width: 1.5),
            ),
            errorText: errorText,
            errorStyle: context.text.bodySmall!.copyWith(color: SbColors.danger),
          ),
        ),
      ],
    );
  }
}
