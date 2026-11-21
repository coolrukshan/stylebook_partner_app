import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/sb_theme.dart';

/// StyleBook styled text input.
class SbTextField extends StatelessWidget {
  const SbTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.prefixText,
    this.prefix,
    this.suffix,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.inputFormatters,
    this.maxLength,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.autofocus = false,
    this.enabled = true,
    this.onChanged,
    this.onFieldSubmitted,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? prefixText;
  final Widget? prefix;
  final Widget? suffix;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final bool autofocus;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = SbTokens.strokeHairline]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(SbTokens.rInput),
      borderSide: BorderSide(color: color, width: width),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: context.text.labelMedium!.copyWith(color: SbColors.text2, fontWeight: SbTokens.weightSemibold),
          ),
          const SizedBox(height: SbTokens.gap8),
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          autofocus: autofocus,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          autofillHints: autofillHints,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          obscureText: obscureText,
          autocorrect: autocorrect,
          enableSuggestions: enableSuggestions,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          style: context.text.bodyLarge!.copyWith(color: SbColors.text, fontWeight: SbTokens.weightMedium),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: context.text.bodyLarge!.copyWith(color: SbColors.subtle),
            prefixText: prefixText,
            prefixStyle: context.text.bodyLarge!.copyWith(color: SbColors.text, fontWeight: SbTokens.weightSemibold),
            prefixIcon: prefix,
            suffixIcon: suffix,
            counterText: '',
            filled: true,
            fillColor: enabled ? SbColors.inputFill : SbColors.soft,
            constraints: const BoxConstraints(minHeight: SbTokens.inputHeight),
            contentPadding: const EdgeInsets.symmetric(horizontal: SbTokens.gap16, vertical: SbTokens.gap12),
            border: border(SbColors.inputBorder),
            enabledBorder: border(SbColors.inputBorder),
            focusedBorder: border(SbColors.amber, SbTokens.strokeFocus),
            errorBorder: border(SbColors.danger),
            focusedErrorBorder: border(SbColors.danger, SbTokens.strokeFocus),
            errorText: errorText,
            errorStyle: context.text.bodySmall!.copyWith(color: SbColors.danger),
          ),
        ),
      ],
    );
  }
}
