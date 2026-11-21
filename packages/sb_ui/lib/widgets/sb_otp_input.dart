import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/sb_theme.dart';

/// 6-digit OTP input row with per-digit focus handling and paste support.
class SbOtpInput extends StatefulWidget {
  const SbOtpInput({
    super.key,
    this.length = 6,
    this.hasError = false,
    this.onCompleted,
    this.onChanged,
  });

  final int length;
  final bool hasError;
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
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
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
          label: 'Digit ${index + 1} of ${widget.length}',
          child: Container(
            width: 46,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SbColors.inputFill,
              borderRadius: BorderRadius.circular(SbTokens.rInput),
              border: Border.all(
                color: widget.hasError
                    ? SbColors.danger
                    : (_focusNodes[index].hasFocus ? SbColors.amber : SbColors.inputBorder),
                width: _focusNodes[index].hasFocus || widget.hasError ? 1.5 : 1,
              ),
            ),
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofillHints: const [AutofillHints.oneTimeCode],
              style: context.text.headlineSmall!.copyWith(
                fontWeight: FontWeight.w700,
                color: widget.hasError ? SbColors.danger : SbColors.text,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
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
