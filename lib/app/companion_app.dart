import 'package:flutter/material.dart';
import '../presentation/overlay/companion_overlay.dart';

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Idle Companion',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xff8dd7bf),
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.transparent,
      visualDensity: VisualDensity.compact,
    ),
    home: const CompanionOverlay(),
  );
}
