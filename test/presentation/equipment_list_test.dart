import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/app/game_controller.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/equipment/equipment.dart';
import 'package:idle_companion/presentation/equipment/equipment_list.dart';

import '../helpers/runtime_fakes.dart';

void main() {
  for (final purchaseCount in <int?>[1, 10, null]) {
    testWidgets(
      'equipment x${purchaseCount ?? 'MAX'} crit preview matches the purchase at desktop width',
      (tester) async {
        tester.view.physicalSize = const Size(400, 620);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer(
          overrides: [
            runtimeProvider.overrideWithValue(
              fakeRuntime(MemoryRepository(), FakeWindow()),
            ),
          ],
        );
        final controller = container.read(gameControllerProvider.notifier);
        final hero = controller.simulation.character;
        hero.gold = hero.books = Amount.fromNum(1000);
        final catalog = EquipmentCatalog.items;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Consumer(
                    builder: (context, ref, child) {
                      ref.watch(gameControllerProvider);
                      return EquipmentList(controller: controller);
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.textContaining('Attack speed'), findsNothing);
        expect(find.text('Boots'), findsNothing);
        expect(
          find.text('Crit chance: 5.00% → 5.10% (after +1)'),
          findsOneWidget,
        );
        expect(
          find.text('Crit damage: 1.50× → 1.51× (after +1)'),
          findsOneWidget,
        );
        await tester.tap(find.text('x10'));
        await tester.pump();
        expect(
          find.text('Crit chance: 5.00% → 6.00% (after +10)'),
          findsOneWidget,
        );
        expect(
          find.text('Crit damage: 1.50× → 1.60× (after +10)'),
          findsOneWidget,
        );
        await tester.tap(find.text('MAX'));
        await tester.pump();
        final item = catalog.singleWhere(
          (item) => item.stat == CharacterStat.critChance,
        );
        final affordable = item.affordable(0, hero.gold);
        final count = purchaseCount == null
            ? affordable
            : purchaseCount.clamp(0, affordable);
        if (purchaseCount != null) {
          await tester.tap(find.text('x$purchaseCount'));
          await tester.pump();
        }
        final preview = (5 + .1 * count).toStringAsFixed(2);
        expect(
          find.text('Crit chance: 5.00% → $preview% (after +$count)'),
          findsOneWidget,
        );
        expect(hero.toJson().containsKey('upgrades'), isFalse);
        expect(hero.equipment, isEmpty);
        final card = find.ancestor(
          of: find.text(item.name),
          matching: find.byType(Card),
        );
        final buy = find.descendant(
          of: card,
          matching: find.byType(FilledButton),
        );
        await tester.ensureVisible(buy);
        await tester.tap(buy);
        await tester.pump();
        expect(
          (controller.simulation.stats.critChance * 100).toStringAsFixed(2),
          preview,
        );
        expect(controller.simulation.stats.attackSpeed, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      },
    );
  }
  for (final rank in [8000, 16606]) {
    testWidgets(
      'small crit delta or precision refusal is explicit at rank $rank',
      (tester) async {
        tester.view.physicalSize = const Size(400, 620);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer(
          overrides: [
            runtimeProvider.overrideWithValue(
              fakeRuntime(MemoryRepository(), FakeWindow()),
            ),
          ],
        );
        final controller = container.read(gameControllerProvider.notifier);
        final hero = controller.simulation.character
          ..gold = Amount.fromLog(10000)
          ..equipment['helmet'] = rank;
        final before = controller.simulation.stats.critChance;
        final quote = controller.simulation.purchases.quote(hero, 'helmet');
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: EquipmentList(controller: controller),
                ),
              ),
            ),
          ),
        );
        final card = find.ancestor(
          of: find.text('Helmet'),
          matching: find.byType(Card),
        );
        final button = find.descendant(
          of: card,
          matching: find.byType(FilledButton),
        );
        if (rank == 8000) {
          expect(
            find.text('Crit chance: 80.00% → 80.00% (after +1)'),
            findsOneWidget,
          );
          final label = tester
              .widget<Text>(
                find.descendant(
                  of: card,
                  matching: find.textContaining('percentage points'),
                ),
              )
              .data!;
          final delta = double.parse(label.split('+')[1].split(' ')[0]);
          expect(delta, greaterThan(0));
          expect(
            delta / 100,
            closeTo(
              controller.simulation.curveProfile.chance.gain(rank + 1),
              1e-12,
            ),
          );
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pump();
          expect(controller.simulation.stats.critChance, greaterThan(before));
          expect(hero.equipment['helmet'], quote.level + quote.count);
        } else {
          expect(
            find.text('Precision limit: no representable gain'),
            findsOneWidget,
          );
          expect(tester.widget<FilledButton>(button).onPressed, isNull);
          expect(hero.equipment['helmet'], rank);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      },
    );
  }
}
