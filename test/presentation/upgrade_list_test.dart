import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/app/game_controller.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/equipment/equipment.dart';
import 'package:idle_companion/domain/progression/infinite_upgrade.dart';
import 'package:idle_companion/presentation/upgrades/upgrade_list.dart';

import '../helpers/runtime_fakes.dart';

void main() {
  for (final equipment in [false, true]) {
    testWidgets(
      '${equipment ? 'equipment' : 'book'} crit preview matches the purchase at desktop width',
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
        final catalog = equipment
            ? EquipmentCatalog.items
            : UpgradeCatalog.character;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Consumer(
                    builder: (context, ref, child) {
                      ref.watch(gameControllerProvider);
                      return UpgradeList(
                        controller: controller,
                        definitions: catalog,
                        equipment: equipment,
                      );
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
        final count = item.affordable(0, equipment ? hero.gold : hero.books);
        final preview = (5 + .1 * count).toStringAsFixed(2);
        expect(
          find.text('Crit chance: 5.00% → $preview% (after +$count)'),
          findsOneWidget,
        );
        expect(hero.upgrades, isEmpty);
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
}
