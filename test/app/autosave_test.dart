import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/app/game_controller.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import '../helpers/runtime_fakes.dart';

void main() {
  testWidgets(
    'autosave runs every minute and each successful upgrade saves immediately',
    (tester) async {
      final repository = MemoryRepository();
      final container = ProviderContainer(
        overrides: [
          runtimeProvider.overrideWithValue(
            fakeRuntime(repository, FakeWindow()),
          ),
        ],
      );
      try {
        container.read(gameControllerProvider);
        final controller = container.read(gameControllerProvider.notifier);
        await tester.pump(const Duration(seconds: 59));
        expect(repository.writes, 0);
        await tester.pump(const Duration(seconds: 1));
        expect(repository.writes, 1);
        await tester.pump(const Duration(minutes: 1));
        expect(repository.writes, 2);

        controller.simulation.character.gold = Amount.fromNum(1000);
        controller.purchaseEquipment('weapon', 1);
        expect(repository.writes, 3);
        expect(
          (repository.snapshot!['character'] as Map)['equipment'],
          containsPair('weapon', 1),
        );

        controller.simulation.character.books = Amount.fromNum(100);
        controller.purchaseEquipment('armor', 10);
        expect(repository.writes, 4);
        expect(
          (repository.snapshot!['character'] as Map)['equipment'],
          containsPair('armor', 10),
        );
        await tester.pump();
      } finally {
        container.dispose();
      }
    },
  );
}
