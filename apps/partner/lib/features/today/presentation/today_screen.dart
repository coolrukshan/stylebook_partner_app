import 'package:flutter/material.dart';
import 'package:sb_ui/sb_ui.dart';

import '../../../l10n/app_localizations.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SbTokens.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.todayTitle, style: context.text.headlineMedium),
              const SizedBox(height: SbTokens.gap16),
              SbCard(child: Text(l10n.todayScaffoldReady, style: context.text.bodyMedium)),
            ],
          ),
        ),
      ),
    );
  }
}
