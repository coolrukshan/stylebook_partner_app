import 'package:flutter/material.dart';
import '../theme/sb_theme.dart';

/// Error banner using design system danger tokens. Announced as a live region.
class SbErrorBanner extends StatelessWidget {
  const SbErrorBanner({
    super.key,
    required this.message,
    this.retryLabel,
    this.onRetry,
  }) : assert(onRetry == null || retryLabel != null, 'retryLabel (localised) is required with onRetry');

  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: SbTokens.gap16, vertical: SbTokens.gap12),
        decoration: BoxDecoration(
          color: SbColors.dangerBg,
          borderRadius: BorderRadius.circular(SbTokens.rInput),
          border: Border.all(color: SbColors.danger.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.error_outline,
                color: SbColors.danger,
                size: SbTokens.iconSmall,
              ),
            ),
            const SizedBox(width: SbTokens.gap12),
            Expanded(
              child: Text(
                message,
                style: context.text.bodyMedium!.copyWith(
                  color: SbColors.danger,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: SbTokens.gap8),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: SbColors.danger,
                  padding: const EdgeInsets.symmetric(horizontal: SbTokens.gap8, vertical: SbTokens.gap4),
                  minimumSize: const Size(SbTokens.minTouch, SbTokens.minTouch),
                ),
                child: Text(
                  retryLabel!,
                  style: context.text.labelMedium!.copyWith(
                    color: SbColors.danger,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
