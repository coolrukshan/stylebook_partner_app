import 'package:flutter/material.dart';
import 'package:sb_ui/sb_ui.dart';

/// Title and one-line explanation at the top of the sign-in style screens.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: context.text.headlineMedium!.copyWith(color: SbColors.ink, fontWeight: SbTokens.weightBold),
          ),
        ),
        const SizedBox(height: SbTokens.gap8),
        Text(subtitle, style: context.text.bodyMedium!.copyWith(color: SbColors.text2)),
      ],
    );
  }
}
