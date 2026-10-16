import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:idle_companion/app/di/injection.dart';
import 'package:idle_companion/app/session/session_cubit.dart';
import 'package:idle_companion/l10n/app_localizations.dart';
import 'package:idle_companion/l10n/hero_break_lines.dart';
import 'package:idle_companion/presentation/companion/hero_return_speech/cubit/hero_return_speech_cubit.dart';
import 'package:idle_companion/presentation/companion/hero_return_speech/widgets/hero_return_speech.dart';
import '../../../helpers/runtime_fakes.dart';

void main() {
  testWidgets('All 50 reminders appear before repeats, then expire once', (
    tester,
  ) async {
    final dependencies = configureDependencies(
      runtime: fakeRuntime(MemoryRepository(), FakeWindow()),
    );
    final session = dependencies<SessionCubit>();
    final speech = dependencies<HeroReturnSpeechCubit>(
      param1: 40,
      param2: Random(7),
    );
    try {
      await tester.pump();
      final reminder = session.simulation.breakReminder;
      final seen = <int>{};
      int? previous;
      for (var i = 0; i < 100; i++) {
        reminder.advance(i == 0 ? 2400 : 180);
        speech.refresh();
        expect(speech.state.kind, HeroSpeechKind.breakReminder);
        final index = speech.state.lineIndex!;
        expect(index, inInclusiveRange(0, heroBreakLineCount - 1));
        if (i % 50 == 0) seen.clear();
        expect(seen.add(index), isTrue);
        expect(index, isNot(previous));
        previous = index;
      }
      expect(seen.length, 50);
      final shown = speech.state;
      speech.refresh();
      expect(speech.state, same(shown));
      await tester.pump(const Duration(seconds: 4));
      expect(speech.state.lineIndex, isNull);
      speech.refresh();
      expect(speech.state.lineIndex, isNull);

      session.simulation.settings.overallOpacity = 0;
      reminder.advance(180);
      speech.refresh();
      session.simulation.settings.overallOpacity = 1;
      speech.refresh();
      expect(speech.state.lineIndex, isNull);
      reminder.advance(180);
      speech.refresh();
      expect(speech.state.kind, HeroSpeechKind.breakReminder);
      expect(speech.state.lineIndex, isNotNull);
      session.simulation.idle.setIdleSeconds(31);
      speech.refresh();
      expect(speech.state.lineIndex, isNull);
    } finally {
      await tester.runAsync(speech.close);
      await tester.pump(const Duration(seconds: 4));
      await tester.runAsync(dependencies.reset);
    }
  });

  testWidgets('Reminder bubble renders from the localized break catalog', (
    tester,
  ) async {
    final dependencies = configureDependencies(
      runtime: fakeRuntime(MemoryRepository(), FakeWindow()),
    );
    try {
      await tester.pumpWidget(
        RepositoryProvider<GetIt>.value(
          value: dependencies,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: HeroReturnSpeech()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final builder = find.byType(
        BlocBuilder<HeroReturnSpeechCubit, HeroReturnSpeechState>,
      );
      final speech = tester.element(builder).read<HeroReturnSpeechCubit>();
      final session = dependencies<SessionCubit>();
      session.simulation.breakReminder.advance(2399);
      speech.refresh();
      await tester.pump();
      expect(find.byKey(const ValueKey('heroReturnSpeech')), findsNothing);
      session.simulation.breakReminder.advance(1);
      session.refresh();
      await tester.pump();
      await tester.pump();
      final lines = AppLocalizations.of(
        tester.element(builder),
      )!.heroBreakLines;
      expect(lines.length, 50);
      expect(lines.toSet().length, 50);
      expect(lines.every((line) => line.trim().isNotEmpty), isTrue);
      expect(find.text(lines[speech.state.lineIndex!]), findsOneWidget);
      expect(speech.state.kind, HeroSpeechKind.breakReminder);
      await tester.pump(const Duration(seconds: 4));
      expect(find.byKey(const ValueKey('heroReturnSpeech')), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(dependencies.reset);
    }
  });
}
