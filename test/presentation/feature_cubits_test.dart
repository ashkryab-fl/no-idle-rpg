import 'dart:async';
import 'package:get_it/get_it.dart';
import 'package:idle_companion/app/di/injection.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/balance/game_balance.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/talents/talents.dart';
import 'package:idle_companion/presentation/menu/debug/cubit/debug_cubit.dart';
import 'package:idle_companion/presentation/menu/upgrades/equipment/cubit/equipment_cubit.dart';
import 'package:idle_companion/presentation/menu/upgrades/equipment/widgets/equipment_list.dart';
import 'package:idle_companion/presentation/menu/upgrades/equipment/widgets/equipment_panel.dart';
import 'package:idle_companion/presentation/companion/hero_return_speech/cubit/hero_return_speech_cubit.dart';
import 'package:idle_companion/presentation/menu/cubit/menu_cubit.dart';
import 'package:idle_companion/presentation/companion/cubit/overlay_cubit.dart';
import 'package:idle_companion/app/session/session_cubit.dart';
import 'package:idle_companion/presentation/menu/settings/cubit/settings_cubit.dart';
import 'package:idle_companion/presentation/menu/statistics/cubit/statistics_cubit.dart';
import 'package:idle_companion/presentation/menu/upgrades/talents/cubit/talents_cubit.dart';
import 'package:idle_companion/presentation/menu/upgrades/talents/widgets/talents_panel.dart';
import '../helpers/runtime_fakes.dart';

Future<void> flushSessionEvents() => Future<void>.delayed(Duration.zero);

void completeRestReturn(SessionCubit session) {
  final game = session.simulation;
  final previous = game.heroAnimations.restReturnRevision;
  game.idle.setIdleSeconds(31);
  // Entry follows the last walk frame; return only after a graph has started.
  for (var i = 0; i < 20 && game.idle.graphRunner?.isRunning != true; i++) {
    game.heroAnimations.advance(.1);
  }
  expect(game.idle.graphRunner?.isRunning, isTrue);
  game.idle.setIdleSeconds(0);
  for (var i = 0; i < 1000 && game.idle.blocksAdventure; i++) {
    game.heroAnimations.advance(.1);
  }
  expect(game.heroAnimations.restReturnRevision, previous + 1);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryRepository repository;
  late FakeWindow window;
  late FakeActivity activity;
  late SessionCubit session;
  late GetIt dependencies;
  late OverlayCubit overlay;
  group('Feature Cubits', () {
    setUp(() {
      repository = MemoryRepository();
      window = FakeWindow();
      activity = FakeActivity();
      dependencies = configureDependencies(
        runtime: fakeRuntime(repository, window, activity),
      );
      session = dependencies<SessionCubit>();
      overlay = dependencies<OverlayCubit>();
    });
    tearDown(() async {
      await dependencies.reset();
    });

    test(
      'Equipment owns quantity and recomputes purchases against current funds',
      () async {
        session.simulation.character.gold = Amount.fromNum(10000);
        final equipment = dependencies<EquipmentCubit>();
        final statistics = dependencies<StatisticsCubit>();
        addTearDown(equipment.close);
        addTearDown(statistics.close);
        equipment.selectCount(10);
        final before = equipment.state;
        expect(before.items.first.quote.count, 10);
        // Another action spent the money after the preview was shown.
        session.simulation.character.gold = Amount.zero;
        equipment.purchase('weapon');
        expect(session.simulation.character.equipment['weapon'], isNull);
        expect(repository.writes, 0);
        session.simulation.character.gold = Amount.fromNum(10000);
        equipment.purchase('weapon');
        await flushSessionEvents();
        expect(equipment.state.items.first.level, 10);
        expect(equipment.state.count, 10);
        expect(repository.writes, 1);
        expect(statistics.state.values['Gold'], isNot('0'));
        expect(before.items.first.level, 0);
        expect(before.gold.toDouble(), closeTo(10000, .001));
        expect(() => equipment.state.items.clear(), throwsUnsupportedError);
      },
    );

    test(
      'Talents own quantity, selection and reward expansion independently',
      () async {
        session.simulation.character.books = Amount.fromNum(10000);
        session.simulation.character.talents.highestFirstClearedStage = 5;
        final talents = dependencies<TalentsCubit>();
        final equipment = dependencies<EquipmentCubit>();
        addTearDown(talents.close);
        addTearDown(equipment.close);
        talents.selectCount(null);
        talents.purchase('boss_damage');
        talents.select(TalentPair.boss, 'boss_damage');
        talents.setRewardsExpanded(true);
        final selected = talents.state;
        talents.select(TalentPair.boss, null);
        await flushSessionEvents();
        expect(selected.selected[TalentPair.boss], 'boss_damage');
        expect(talents.state.selected[TalentPair.boss], isNull);
        expect(talents.state.items.first.rank, 3);
        expect(talents.state.count, isNull);
        expect(talents.state.rewardsExpanded, isTrue);
        expect(equipment.state.count, 1);
        expect(repository.writes, 3);
      },
    );

    test(
      'Settings publish immediately and save only at the end of slider edits',
      () async {
        final settings = dependencies<SettingsCubit>();
        addTearDown(settings.close);
        await overlay.show(OverlayPanel.settings);
        final before = settings.state;
        await settings.update(
          overallOpacity: 0,
          backgroundOpacity: .5,
          persist: false,
        );
        await flushSessionEvents();
        expect(repository.writes, 0);
        expect(window.heroVisible, isFalse);
        expect(window.expanded, isTrue);
        expect(overlay.state.overallOpacity, 0);
        expect(settings.state.backgroundOpacity, .5);
        expect(before.overallOpacity, 1);
        await settings.save();
        expect(repository.writes, 1);
        await settings.update(overallOpacity: 2, fps: 60);
        expect(settings.state.overallOpacity, 1);
        expect(settings.state.fps, 60);
        expect(window.heroVisible, isTrue);
      },
    );

    test(
      'Reset blocks feature mutations and refreshes all snapshots on completion',
      () async {
        final settings = dependencies<SettingsCubit>();
        final equipment = dependencies<EquipmentCubit>();
        final talents = dependencies<TalentsCubit>();
        final debug = dependencies<DebugCubit>();
        addTearDown(settings.close);
        addTearDown(equipment.close);
        addTearDown(talents.close);
        addTearDown(debug.close);
        session.simulation.character.gold = Amount.fromNum(10000);
        debug.setDebugIdle(31);
        debug.setSpeed(20);
        equipment.purchase('weapon');
        await flushSessionEvents();
        repository.resetGate = Completer<void>();
        final reset = settings.reset();
        expect(settings.state.busy, isTrue);
        final writes = repository.writes;
        equipment.purchase('weapon');
        debug.runAction('gold');
        await settings.update(sound: true);
        expect(repository.writes, writes);
        repository.resetGate!.complete();
        await reset;
        await flushSessionEvents();
        expect(settings.state.busy, isFalse);
        expect(settings.state.sound, isFalse);
        expect(equipment.state.gold.isZero, isTrue);
        expect(equipment.state.items.first.level, 0);
        expect(talents.state.books.isZero, isTrue);
        expect(debug.state.speed, 1);
        expect(debug.state.idleOverride, isNull);
        expect(overlay.state.panel, OverlayPanel.settings);
      },
    );

    test(
      'Menu shares session activity and delegates window navigation',
      () async {
        final menu = dependencies<MenuCubit>();
        addTearDown(menu.close);
        await flushSessionEvents();
        activity.idle = const Duration(seconds: 123);
        await session.pollActivity();
        await flushSessionEvents();
        expect(menu.state.idleSeconds, 123);
        await menu.open(OverlayPanel.equipment);
        expect(overlay.state.panel, OverlayPanel.equipment);
        expect(window.expanded, isTrue);
        await overlay.show(null);
        expect(window.expanded, isFalse);
      },
    );

    test(
      'Disposed feature stops observing session and ignores delayed commands',
      () async {
        final equipment = dependencies<EquipmentCubit>();
        final settings = dependencies<SettingsCubit>();
        final before = equipment.state;
        await equipment.close();
        await settings.close();
        session.simulation.character.gold = Amount.fromNum(1000);
        session.refresh();
        await flushSessionEvents();
        equipment.selectCount(10);
        equipment.purchase('weapon');
        await settings.reset();
        expect(equipment.state, same(before));
        expect(repository.writes, 0);
        expect(
          session.simulation.character.gold.toDouble(),
          closeTo(1000, .001),
        );
      },
    );
  });

  testWidgets('Feature BlocProviders dispose Cubits when the panel changes', (
    tester,
  ) async {
    final dependencies = configureDependencies(
      runtime: fakeRuntime(MemoryRepository(), FakeWindow()),
    );
    final session = dependencies<SessionCubit>();
    final overlay = dependencies<OverlayCubit>();
    Widget host(Widget panel) => RepositoryProvider<GetIt>.value(
      value: dependencies,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: session),
          BlocProvider.value(value: overlay),
        ],
        child: MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: panel)),
        ),
      ),
    );
    await tester.pumpWidget(host(const EquipmentPanel()));
    final equipment = tester
        .element(find.byType(EquipmentList))
        .read<EquipmentCubit>();
    await tester.tap(find.text('×10'));
    await tester.pump();
    expect(equipment.state.count, 10);
    await tester.pumpWidget(host(const TalentsPanel()));
    await tester.pump();
    expect(equipment.isClosed, isTrue);
    await tester.pumpWidget(host(const EquipmentPanel()));
    await tester.pump();
    final reopened = tester
        .element(find.byType(EquipmentList))
        .read<EquipmentCubit>();
    expect(reopened, isNot(same(equipment)));
    expect(reopened.state.count, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await dependencies.reset();
    });
  });

  testWidgets(
    'Speech expires once and stays hidden after opacity is restored',
    (tester) async {
      final dependencies = configureDependencies(
        runtime: fakeRuntime(MemoryRepository(), FakeWindow()),
      );
      final session = dependencies<SessionCubit>();
      final speech = dependencies<HeroReturnSpeechCubit>(
        param1: 40,
        param2: Random(7),
      );
      // Complete the native startup poll before simulating a rest return.
      await tester.pump();
      completeRestReturn(session);
      speech.refresh();
      expect(speech.state.lineIndex, inInclusiveRange(0, 39));
      await tester.pump(const Duration(seconds: 4));
      expect(speech.state.lineIndex, isNull);
      completeRestReturn(session);
      speech.refresh();
      expect(speech.state.lineIndex, isNotNull);
      session.simulation.settings.overallOpacity = 0;
      speech.refresh();
      session.simulation.settings.overallOpacity = 1;
      speech.refresh();
      expect(speech.state.lineIndex, isNull);
      await tester.runAsync(speech.close);
      await tester.pump(const Duration(seconds: 4));
      await tester.runAsync(dependencies.reset);
    },
  );

  testWidgets('Session disposal cancels autosave and activity timers', (
    tester,
  ) async {
    final repository = MemoryRepository();
    final window = FakeWindow();
    final dependencies = configureDependencies(
      runtime: fakeRuntime(repository, window),
    );
    dependencies<SessionCubit>();
    await tester.runAsync(dependencies.reset);
    await tester.pump(GameBalance.saveInterval * 2);
    expect(repository.writes, 0);
    expect(window.quits, 0);
    await window.closeHandler!();
    expect(window.quits, 0);
  });
}
