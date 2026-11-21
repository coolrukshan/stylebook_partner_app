import 'package:flutter/material.dart';

import '../theme/sb_theme.dart';

/// Amber text link button with minimum 44px touch target.
class SbTextLink extends StatelessWidget {
  const SbTextLink({super.key, required this.text, required this.onTap, this.enabled = true});

  final String text;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? SbColors.amber : SbColors.muted;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: SbTokens.minTouch, minWidth: SbTokens.minTouch),
      child: TextButton(
        onPressed: enabled ? onTap : null,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: SbTokens.gap12, vertical: SbTokens.gap8),
          minimumSize: const Size(SbTokens.minTouch, SbTokens.minTouch),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          text,
          style: context.text.labelMedium!.copyWith(color: fg, fontWeight: SbTokens.weightSemibold),
        ),
      ),
    );
  }
}
