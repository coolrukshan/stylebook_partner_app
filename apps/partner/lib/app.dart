import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sb_ui/sb_ui.dart';

import 'l10n/app_localizations.dart';
import 'features/auth/presentation/widgets/session_notices.dart';
import 'router.dart';

class PartnerApp extends ConsumerWidget {
  const PartnerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    debugShowCheckedModeBanner: false,
    theme: SbTheme.light(),
    routerConfig: ref.watch(routerProvider),
    builder: (context, child) => SessionNotices(child: child ?? const SizedBox.shrink()),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}
