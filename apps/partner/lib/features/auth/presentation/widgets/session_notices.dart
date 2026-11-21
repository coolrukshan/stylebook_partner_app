import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/providers.dart';

/// App-level listener for notices that must outlive the screen that caused them (for example
/// "Password changed" when a step-up replaced the change-password screen mid-request).
///
/// Place it in `MaterialApp.builder`, below the root `ScaffoldMessenger`.
class SessionNotices extends ConsumerWidget {
  const SessionNotices({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(passwordChangedSignalProvider, (_, _) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).passwordChanged)));
    });
    return child;
  }
}
