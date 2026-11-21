import 'package:flutter/material.dart';
import 'package:sb_ui/sb_ui.dart';

import '../../../l10n/app_localizations.dart';

/// Shown while the stored session is refreshed at launch.
class SessionLoadingScreen extends StatelessWidget {
  const SessionLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SbColors.canvas,
      body: Center(
        child: Semantics(
          label: AppLocalizations.of(context).loadingSession,
          child: const CircularProgressIndicator(color: SbColors.ink),
        ),
      ),
    );
  }
}
