import 'package:flutter/material.dart';

import '../theme/sb_theme.dart';

/// Shell for sign-in style screens: cream page with amber glow.
/// >= [SbTokens.wideBreakpoint]: form centred in a white card. Phone: full-width scrolling form
/// that stays above the keyboard.
class SbAuthScaffold extends StatelessWidget {
  const SbAuthScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SbColors.canvas,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: SbTokens.authGlow)),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= SbTokens.wideBreakpoint) {
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(SbTokens.screenPadding),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: SbTokens.authCardMaxWidth),
                        child: SbCard(padding: const EdgeInsets.all(SbTokens.gap32), child: child),
                      ),
                    ),
                  );
                }
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    SbTokens.screenPadding,
                    SbTokens.gap24,
                    SbTokens.screenPadding,
                    SbTokens.gap24 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: child,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
