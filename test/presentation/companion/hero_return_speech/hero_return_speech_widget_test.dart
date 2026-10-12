import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:idle_companion/app/di/injection.dart';
import 'package:idle_companion/app/session/session_cubit.dart';
import 'package:idle_companion/l10n/app_localizations.dart';
import 'package:idle_companion/l10n/hero_return_lines.dart';
import 'package:idle_companion/presentation/companion/hero_return_speech/cubit/hero_return_speech_cubit.dart';
import 'package:idle_companion/presentation/companion/hero_return_speech/widgets/hero_return_speech.dart';
import '../../../helpers/runtime_fakes.dart';

void main() {
  testWidgets(
    'Localized speech creates its Cubit safely and survives locale updates',
    (tester) async {
      final dependencies = configureDependencies(
        runtime: fakeRuntime(MemoryRepository(), FakeWindow()),
      );
      Widget host(Locale locale) => RepositoryProvider<GetIt>.value(
        value: dependencies,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en'), Locale('en', 'US')],
          home: const Scaffold(body: HeroReturnSpeech()),
        ),
      );
      try {
        await tester.pumpWidget(host(const Locale('en')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final builder = find.byType(
          BlocBuilder<HeroReturnSpeechCubit, HeroReturnSpeechState>,
        );
        final speech = tester.element(builder).read<HeroReturnSpeechCubit>();
        expect(speech.lineCount, 40);

        // Finish an actual rest graph so the widget renders a localized line.
        final session = dependencies<SessionCubit>();
        final game = session.simulation;
        final previous = game.heroAnimations.restReturnRevision;
        game.idle.setIdleSeconds(31);
        // Let the current walk step finish before returning from a real rest.
        for (
          var i = 0;
          i < 20 && game.idle.graphRunner?.isRunning != true;
          i++
        ) {
          game.heroAnimations.advance(.1);
        }
        expect(game.idle.graphRunner?.isRunning, isTrue);
        game.idle.setIdleSeconds(0);
        for (var i = 0; i < 1000 && game.idle.blocksAdventure; i++) {
          game.heroAnimations.advance(.1);
        }
        expect(game.heroAnimations.restReturnRevision, previous + 1);
        session.refresh();
        await tester.pump();
        await tester.pump();
        final bubble = find.byKey(const ValueKey('heroReturnSpeech'));
        expect(bubble, findsOneWidget);
        final localizedLine = tester
            .widget<Text>(
              find.descendant(of: bubble, matching: find.byType(Text)),
            )
            .data;
        expect(
          AppLocalizations.of(tester.element(builder))!.heroReturnLines,
          contains(localizedLine),
        );

        await tester.pumpWidget(host(const Locale('en', 'US')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.element(builder).read<HeroReturnSpeechCubit>(),
          same(speech),
        );
        expect(bubble, findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(dependencies.reset);
      }
    },
  );
}
