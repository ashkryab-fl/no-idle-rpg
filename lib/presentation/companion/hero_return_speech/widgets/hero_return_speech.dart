import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/hero_return_lines.dart';
import '../../../../l10n/hero_break_lines.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../cubit/hero_return_speech_cubit.dart';

class HeroReturnSpeech extends StatelessWidget {
  const HeroReturnSpeech({super.key});
  @override
  Widget build(BuildContext context) {
    final lineCount = AppLocalizations.of(context)!.heroReturnLines.length;
    return BlocProvider(
      create: (context) =>
          context.read<GetIt>()<HeroReturnSpeechCubit>(param1: lineCount),
      child: const _HeroReturnSpeechView(),
    );
  }
}

class _HeroReturnSpeechView extends StatelessWidget {
  const _HeroReturnSpeechView();
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<HeroReturnSpeechCubit, HeroReturnSpeechState>(
        builder: (context, state) {
          if (state.lineIndex == null) return const SizedBox.shrink();
          final l10n = AppLocalizations.of(context)!;
          final lines = switch (state.kind) {
            HeroSpeechKind.restReturn => l10n.heroReturnLines,
            HeroSpeechKind.breakReminder => l10n.heroBreakLines,
          };
          return IgnorePointer(
            child: Align(
              alignment: Alignment.centerLeft,
              child: CustomPaint(
                painter: const _SpeechBubblePainter(),
                child: Padding(
                  key: const ValueKey('heroReturnSpeech'),
                  padding: const EdgeInsets.fromLTRB(28, 8, 10, 20),
                  child: Text(
                    lines[state.lineIndex!],
                    style: const TextStyle(
                      color: Color(0xffeeeadd),
                      fontSize: 11,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
}

class _SpeechBubblePainter extends CustomPainter {
  const _SpeechBubblePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const left = 18.0;
    const radius = 6.0;
    final bottom = size.height - 12;
    // One outline joins the body and curved tail, pointing down to the hero.
    final shape = Path()
      ..moveTo(left + radius, 0)
      ..lineTo(size.width - radius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius)
      ..lineTo(size.width, bottom - radius)
      ..quadraticBezierTo(size.width, bottom, size.width - radius, bottom)
      ..lineTo(left + 22, bottom)
      ..quadraticBezierTo(left + 10, bottom + 9, 0, size.height)
      ..quadraticBezierTo(left + 7, bottom + 2, left + 8, bottom)
      ..lineTo(left + radius, bottom)
      ..quadraticBezierTo(left, bottom, left, bottom - radius)
      ..lineTo(left, radius)
      ..quadraticBezierTo(left, 0, left + radius, 0)
      ..close();
    canvas.drawShadow(shape, const Color(0x66000000), 3, false);
    canvas.drawPath(shape, Paint()..color = const Color(0xf0202925));
    canvas.drawPath(
      shape,
      Paint()
        ..color = const Color(0xff8c9f8c)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
  }

  @override
  bool shouldRepaint(_SpeechBubblePainter oldDelegate) => false;
}
