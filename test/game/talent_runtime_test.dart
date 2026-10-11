import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/animation/attack_playback.dart';
import 'package:idle_companion/content/animations/animation_resources.dart';
import 'package:idle_companion/content/animations/enemies/procedural_timelines.dart';
import 'package:idle_companion/core/animation/ids.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/domain/talents/talents.dart';
import 'package:idle_companion/domain/adventure/stage_attempt.dart';
import 'package:idle_companion/game/systems/combat_system.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/game/systems/game_state_machine.dart';
import '../helpers/simulation_fixture.dart';

GameSimulation talentsGame() {
  final g = GameSimulation(random: ConstantRandom());
  g.character.talents.highestFirstClearedStage = 100;
  g.character.books = Amount.fromNum(10000);
  for (final d in TalentCatalog.items) {
    g.purchaseTalent(d.id, count: 3);
  }
  return g;
}

void main() {
  test(
    'contextual boss multiplier follows crit; protection affects only enemy crit bonus',
    () {
      final resources = defaultAnimationResources();
      final stats = CombatStats(
        maxHp: Amount.fromNum(120),
        damage: Amount.fromNum(100),
        attackSpeed: 1,
        critChance: .5,
        critDamage: 2,
      );
      for (final critical in [false, true]) {
        final combat = CombatSystem(
          ConstantRandom(critical ? 0 : .99),
          heroPlayback: AttackPlayback(
            resources.clip(const ClipId('hero.attack')),
          ),
          enemyPlayback: AttackPlayback(ProceduralEnemyTimelines.attack),
        );
        final effects = TalentEffects({
          'boss_damage': .5,
          'crit_protection': .6,
        });
        expect(
          combat.calculate(stats, true, effects: effects).amount.toDouble(),
          closeTo(critical ? 200 : 100, 1e-9),
        );
        expect(
          combat
              .calculate(stats, true, effects: effects, isBoss: true)
              .amount
              .toDouble(),
          closeTo(critical ? 300 : 150, 1e-9),
        );
        final incoming = combat.calculate(stats, false, effects: effects);
        expect(incoming.amount.toDouble(), closeTo(critical ? 140 : 100, 1e-9));
        expect(
          incoming.preventedCritBonus.toDouble(),
          closeTo(critical ? 60 : 0, 1e-9),
        );
      }
    },
  );
  test(
    'purchases/select queue mid-attempt; death restarts lower stage with queued values',
    () {
      final g = talentsGame()..stage = 6;
      g.selectTalent(TalentPair.boss, 'boss_damage');
      g.spawnEnemy();
      final snapshot = g.activeAttempt!;
      final hp = g.heroHp;
      g.purchaseTalent('boss_damage');
      g.selectTalent(TalentPair.boss, 'first_clear_gold');
      expect(g.heroHp, same(hp));
      expect(g.activeAttempt, same(snapshot));
      expect(snapshot.ranks, {'boss_damage': 3});
      final restored = restart(g);
      expect(restored.activeAttempt!.ranks, snapshot.ranks);
      expect(restored.heroHp.log10, hp.log10);
      restored.killHero();
      expect(restored.stage, 5);
      expect(restored.activeAttempt, isNull);
      until(restored, () => restored.phase == GamePhase.traveling);
      restored.spawnEnemy();
      expect(restored.activeAttempt!.ranks, {'first_clear_gold': 3});
    },
  );
}
