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
  test('speed upgrades do not replay previous combat cycles', () {
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
    expect(
      game.enemyAnimationElapsed(),
      game.animations.get(game.enemyAnimation!).duration,
    );
    game.killHero();
    for (var i = 0; i < 50; i++) {
      game.advance(1 / 60);
    }
    expect(game.phase, GamePhase.respawn);
    expect(
      game.heroAnimationElapsed(),
      game.animations.get('hero.death').duration,
    );
  });
}
