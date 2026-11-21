import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/sb_theme.dart';

/// 6-digit OTP input row with per-digit focus handling and paste support.
class SbOtpInput extends StatefulWidget {
  const SbOtpInput({
    super.key,
    this.length = 6,
    this.hasError = false,
    this.enabled = true,
    this.clearSignal = 0,
    this.semanticLabelBuilder,
    this.onCompleted,
    this.onChanged,
  });

  final int length;
  final bool hasError;
  final bool enabled;

  /// Changing this value clears all boxes and refocuses the first one (for example after a wrong code).
  final int clearSignal;

  /// Localised label for box [index] (1-based) of [total]. Defaults to English.
  final String Function(int index, int total)? semanticLabelBuilder;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;

  @override
  State<SbOtpInput> createState() => _SbOtpInputState();
}

class _SbOtpInputState extends State<SbOtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode()..addListener(_onFocusChanged));
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(SbOtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clearSignal != widget.clearSignal) {
      for (final c in _controllers) {
        c.clear();
      }
      // After the frame: the boxes may only just have been re-enabled (after a failed verify), and
      // the parent must not be told to rebuild while it is building.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusNodes.first.requestFocus();
        widget.onChanged?.call('');
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentCode => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    // Check if pasted multiple digits
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < widget.length && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      final nextIndex = digits.length < widget.length ? digits.length : widget.length - 1;
      _focusNodes[nextIndex].requestFocus();

      final code = _currentCode;
      widget.onChanged?.call(code);
      if (code.length == widget.length) {
        widget.onCompleted?.call(code);
      }
      return;
    }

    if (value.isNotEmpty) {
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }

    final code = _currentCode;
    widget.onChanged?.call(code);
    if (code.length == widget.length) {
      widget.onCompleted?.call(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (index) {
        return Semantics(
          label:
              widget.semanticLabelBuilder?.call(index + 1, widget.length) ?? 'Digit ${index + 1} of ${widget.length}',
          child: Container(
            width: SbTokens.otpBoxWidth,
            height: SbTokens.buttonHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SbColors.inputFill,
              borderRadius: BorderRadius.circular(SbTokens.rInput),
              border: Border.all(
                color: widget.hasError
                    ? SbColors.danger
                    : (_focusNodes[index].hasFocus ? SbColors.amber : SbColors.inputBorder),
                width: _focusNodes[index].hasFocus || widget.hasError ? SbTokens.strokeFocus : SbTokens.strokeHairline,
              ),
            ),
            child: TextField(
              controller: _controllers[index],
              enabled: widget.enabled,
              focusNode: _focusNodes[index],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              expands: true,
              maxLines: null,
              minLines: null,
              autofillHints: const [AutofillHints.oneTimeCode],
              style: context.text.headlineSmall!.copyWith(
                fontWeight: SbTokens.weightBold,
                color: widget.hasError ? SbColors.danger : SbColors.text,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onChanged: (val) => _onDigitChanged(index, val),
              onTap: () {
                _controllers[index].selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _controllers[index].text.length,
                );
              },
            ),
          ),
        );
      }),
    );
  }
}
