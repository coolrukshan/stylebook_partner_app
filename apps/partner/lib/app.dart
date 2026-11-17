import 'package:flutter/material.dart';
import 'package:sb_ui/sb_ui.dart';

import 'router.dart';

class PartnerApp extends StatelessWidget {
  const PartnerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'StyleBook Partner',
        debugShowCheckedModeBanner: false,
        theme: SbTheme.light(),
        routerConfig: appRouter,
      );
}
