import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/app/app_runtime.dart';
import 'package:idle_companion/app/di/injection.dart';
import 'package:idle_companion/app/session/session_cubit.dart';
import 'package:idle_companion/app/session/session_state.dart';
import 'package:idle_companion/app/session/session_updates_service.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/presentation/companion/cubit/overlay_cubit.dart';
import 'package:idle_companion/presentation/menu/cubit/menu_cubit.dart';
import 'package:idle_companion/presentation/menu/debug/cubit/debug_cubit.dart';
import 'package:idle_companion/presentation/menu/settings/cubit/settings_cubit.dart';
import 'package:idle_companion/presentation/menu/statistics/cubit/statistics_cubit.dart';
import 'package:idle_companion/presentation/menu/upgrades/equipment/cubit/equipment_cubit.dart';
import 'package:idle_companion/presentation/menu/upgrades/talents/cubit/talents_cubit.dart';
import 'package:idle_companion/presentation/recovery/cubit/recovery_cubit.dart';
import 'package:idle_companion/presentation/recovery/cubit/recovery_request.dart';
import '../helpers/runtime_fakes.dart';

class _CountingSession extends SessionCubit {
  _CountingSession(super.runtime);
  int subscriptions = 0;
  @override
  Stream<SessionState> get stream =>
      _CountingStream(super.stream, () => subscriptions++);
}

class _CountingStream<T> extends Stream<T> {
  _CountingStream(this.source, this.onListen);
  final Stream<T> source;
  final void Function() onListen;
  @override
  StreamSubscription<T> listen(
    void Function(T)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    onListen();
    return source.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Generated factories automatically register all live session features',
    () async {
      final dependencies = configureDependencies(
        runtime: fakeRuntime(MemoryRepository(), FakeWindow()),
      );
      final session = dependencies<SessionCubit>();
      final updates = dependencies<SessionUpdatesService>();
      final overlay = dependencies<OverlayCubit>();
      final equipment = dependencies<EquipmentCubit>();
      final talents = dependencies<TalentsCubit>();
      final statistics = dependencies<StatisticsCubit>();
      final menu = dependencies<MenuCubit>();
      final settings = dependencies<SettingsCubit>();
      final debug = dependencies<DebugCubit>();
      addTearDown(dependencies.reset);
      for (final cubit in [
        equipment,
        talents,
        statistics,
        menu,
        settings,
        debug,
      ]) {
        addTearDown(cubit.close);
      }
      expect(updates.subscriberCount, 7);
      expect(settings.overlay, same(overlay));
      expect(menu.overlay, same(overlay));
      session.simulation.character.gold = Amount.fromNum(42);
      session.simulation.settings.sound = true;
      session.simulation.stage = 8;
      final equipmentUpdated = equipment.stream.first;
      final talentsUpdated = talents.stream.first;
      final statisticsUpdated = statistics.stream.first;
      final settingsUpdated = settings.stream.first;
      final overlayUpdated = overlay.stream.first;
      session.refresh();
      await Future.wait([
        equipmentUpdated,
        talentsUpdated,
        statisticsUpdated,
        settingsUpdated,
        overlayUpdated,
      ]);
      expect(equipment.state.gold.toDouble(), closeTo(42, .001));
      expect(talents.state.stage, 8);
      expect(statistics.state.values['Stage'], '8');
      expect(settings.state.sound, isTrue);
      expect(overlay.state.stage, 8);
      await equipment.close();
      expect(updates.subscriberCount, 6);
      final replacement = dependencies<EquipmentCubit>();
      addTearDown(replacement.close);
      expect(replacement, isNot(same(equipment)));
      expect(updates.subscriberCount, 7);
    },
  );

  test(
    'One service subscription fans out updates and removes closed Cubits',
    () async {
      final session = _CountingSession(
        fakeRuntime(MemoryRepository(), FakeWindow()),
      );
      final updates = SessionUpdatesService(session);
      final equipment = EquipmentCubit(session, updates);
      final statistics = StatisticsCubit(session, updates);
      equipment.subscribeToSession();
      statistics.subscribeToSession();
      equipment.subscribeToSession();
      expect(session.subscriptions, 1);
      expect(updates.subscriberCount, 2);
      session.simulation.character.gold = Amount.fromNum(100);
      final equipmentUpdated = equipment.stream.first;
      final statisticsUpdated = statistics.stream.first;
      session.refresh();
      await Future.wait([equipmentUpdated, statisticsUpdated]);
      expect(equipment.state.gold.toDouble(), closeTo(100, .001));
      expect(statistics.state.values['Gold'], '100');
      await equipment.close();
      expect(updates.subscriberCount, 1);
      final before = statistics.state;
      await updates.dispose();
      session.simulation.stage = 12;
      session.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(statistics.state, same(before));
      expect(updates.subscriberCount, 0);
      await statistics.close();
      await session.close();
    },
  );

  test(
    'Dependency containers isolate runtimes and dispose shared resources',
    () async {
      final first = configureDependencies(
        runtime: fakeRuntime(MemoryRepository(), FakeWindow()),
      );
      final second = configureDependencies(
        runtime: fakeRuntime(MemoryRepository(), FakeWindow()),
      );
      final firstSession = first<SessionCubit>();
      final secondSession = second<SessionCubit>();
      final firstOverlay = first<OverlayCubit>();
      final secondOverlay = second<OverlayCubit>();
      final updates = first<SessionUpdatesService>();
      firstSession.simulation.character.gold = Amount.fromNum(999);
      expect(secondSession.simulation.character.gold.isZero, isTrue);
      expect(first<AppRuntime>(), isNot(same(second<AppRuntime>())));
      await first.reset();
      expect(firstSession.isClosed, isTrue);
      expect(firstOverlay.isClosed, isTrue);
      expect(updates.subscriberCount, 0);
      expect(secondSession.isClosed, isFalse);
      expect(secondOverlay.isClosed, isFalse);
      await second.reset();
    },
  );

  test(
    'Recovery factory works before a runtime exists and does not start a session',
    () async {
      final dependencies = configureDependencies();
      final window = FakeWindow();
      final recovery = dependencies<RecoveryCubit>(
        param1: RecoveryRequest(
          error: 'Unreadable save',
          retry: () async {},
          window: window,
        ),
      );
      expect(recovery.state.error, 'Unreadable save');
      expect(dependencies.isRegistered<AppRuntime>(), isFalse);
      expect(window.closeHandler, isNull);
      await recovery.quit();
      expect(window.quits, 1);
      await recovery.close();
      await dependencies.reset();
    },
  );
}
