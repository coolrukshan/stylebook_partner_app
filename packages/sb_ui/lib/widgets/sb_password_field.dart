import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/sb_theme.dart';
import 'sb_text_field.dart';

/// Password input with a show/hide eye (44 px target, Semantics via tooltip).
///
/// Obscured by default. Visibility resets when the app leaves the foreground and when the
/// widget is removed. [showLabel] and [hideLabel] must be localised by the caller.
class SbPasswordField extends StatefulWidget {
  const SbPasswordField({
    super.key,
    required this.label,
    required this.showLabel,
    required this.hideLabel,
    this.controller,
    this.focusNode,
    this.errorText,
    this.textInputAction,
    this.autofillHints,
    this.maxLength,
    this.enabled = true,
    this.onChanged,
    this.onFieldSubmitted,
  });

  final String label;
  final String showLabel;
  final String hideLabel;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? errorText;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final int? maxLength;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<SbPasswordField> createState() => _SbPasswordFieldState();
}

class _SbPasswordFieldState extends State<SbPasswordField> with WidgetsBindingObserver {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _visible) {
      setState(() => _visible = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SbTextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      label: widget.label,
      errorText: widget.errorText,
      enabled: widget.enabled,
      obscureText: !_visible,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      maxLength: widget.maxLength,
      inputFormatters: const <TextInputFormatter>[],
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      suffix: Semantics(
        button: true,
        label: _visible ? widget.hideLabel : widget.showLabel,
        excludeSemantics: true,
        child: IconButton(
          tooltip: _visible ? widget.hideLabel : widget.showLabel,
          constraints: const BoxConstraints.tightFor(width: SbTokens.minTouch, height: SbTokens.minTouch),
          icon: Icon(
            _visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: SbColors.muted,
            size: SbTokens.iconSmall,
          ),
          onPressed: widget.enabled ? () => setState(() => _visible = !_visible) : null,
        ),
      ),
    );
  }
}
