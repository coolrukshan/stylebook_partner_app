import 'package:flutter/material.dart';
import 'package:sb_ui/sb_ui.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(SbTokens.screenPadding),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Today', style: context.text.headlineMedium),
              const SizedBox(height: SbTokens.gap16),
              SbCard(child: Text('Partner app scaffold ready.', style: context.text.bodyMedium)),
            ]),
          ),
        ),
      );
}
