import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/assets/animation_catalog.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/game/systems/combat_system.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/game/systems/game_state_machine.dart';

CombatStats fighter(double speed) => CombatStats(
  maxHp: Amount.fromNum(100),
  damage: Amount.fromNum(10),
  attackSpeed: speed,
  critChance: 0,
  critDamage: 1.5,
);
void main() {
  test('incoming hits preserve the swing and pauses return to the guard', () {
    final game = GameSimulation(random: Random(1));
    game.spawnEnemy();
    game.machine.transition(GamePhase.combat);
    expect(game.heroAnimation, 'hero.attack');
    game.advance(.36);
    expect(game.heroHitRemaining, greaterThan(0));
    expect(game.heroAnimation, 'hero.attack');
    final attack = game.animations.get('hero.attack');
    expect((game.heroAnimationElapsed() / attack.stepTime).floor(), 2);
    game.advance(.25);
    expect(game.heroAnimation, 'hero.idle');
    game.advance(.4);
    expect(game.heroAnimation, 'hero.attack');
    game.killEnemy();
    expect(game.heroAnimation, 'hero.idle');
  });
  test('hero damage falls on the slash frame at normal and fast speeds', () {
    for (final speed in [1.0, 5.0]) {
      final catalog = AnimationCatalog();
      final combat = CombatSystem(Random(1), catalog);
      final attack = catalog.get('hero.attack');
      final stats = fighter(speed);
      final hitTime =
          attack.damageEventTime! * min(1, 1 / speed / attack.duration);
      final before = combat.update(
        hitTime - .0001,
        stats,
        fighter(1),
        'slime',
        1,
      );
      expect(before.where((event) => event.fromHero), isEmpty);
      final hits = combat.update(.0002, stats, fighter(1), 'slime', 1);
      expect(hits.where((event) => event.fromHero), hasLength(1));
      expect(
        (combat.attackElapsed(true, stats, 'hero') / attack.stepTime).floor(),
        2,
      );
    }
  });
  test('programmatic speed changes do not replay previous combat cycles', () {
    final combat = CombatSystem(Random(1), AnimationCatalog());
    combat.update(40, fighter(1), fighter(1), 'slime', 1);
    final hits = combat.update(.01, fighter(2), fighter(1), 'slime', 1);
    expect(hits, isEmpty);
  });
  test('events from both fighters follow chronological hit timing', () {
    final catalog = AnimationCatalog({
      'slime.attack': const AnimationDefinition(
        id: 'slime.attack',
        stepTime: .6,
        damageEventTime: .1,
      ),
    });
    final hits = CombatSystem(
      Random(1),
      catalog,
    ).update(.4, fighter(1), fighter(1), 'slime', 1);
    expect(hits.map((event) => event.fromHero).toList(), [false, true]);
  });
  test('dead actors hold their final frame throughout reward and respawn', () {
    final game = GameSimulation(random: Random(1));
    game.spawnEnemy();
    game.killEnemy();
    for (var i = 0; i < 50; i++) {
      game.advance(1 / 60);
    }
    expect(game.phase, GamePhase.reward);
    expect(game.enemyAnimationElapsed(), game.enemyPlayback!.duration);
    game.killHero();
    game.advance(game.animations.get('hero.death').duration + .05);
    expect(game.phase, GamePhase.respawn);
    expect(
      game.heroAnimationElapsed(),
      game.animations.get('hero.death').duration,
    );
  });
  test(
    'hero death progresses slowly and holds the final pose for one second',
    () {
      final game = GameSimulation(random: Random(1));
      final death = game.animations.get('hero.death');
      game.killHero();
      final framesSeen = <int>[];
      var finalFrameTicks = 0, ticks = 0;
      while (game.phase != GamePhase.traveling && ticks < 200) {
        final frame = min(
          (game.heroAnimationElapsed() / death.stepTime).floor(),
          death.frames - 1,
        );
        if (framesSeen.isEmpty || framesSeen.last != frame) {
          framesSeen.add(frame);
        }
        if (frame == death.frames - 1) {
          finalFrameTicks++;
        }
        game.advance(1 / 60);
        ticks++;
      }
      expect(framesSeen, [0, 1, 2, 3]);
      expect(finalFrameTicks / 60, closeTo(1, 2 / 60));
      expect(ticks / 60, closeTo(2.2, 2 / 60));
      expect(game.phase, GamePhase.traveling);
      expect(game.heroHp.ratio(game.stats.maxHp), closeTo(1, 1e-8));
      expect(game.heroAnimation, 'hero.walk');
    },
  );
}
