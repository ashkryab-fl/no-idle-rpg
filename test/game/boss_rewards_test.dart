import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/balance/talent_profile.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/core/persistence/game_save.dart';
import 'package:idle_companion/domain/economy/reward.dart';
import 'package:idle_companion/domain/talents/talents.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import '../helpers/simulation_fixture.dart' show forcedClear, restart, until;

void main() {
  test(
    'saved effect must match paid rank, even if under the absolute ceiling',
    () {
      final g = GameSimulation();
      g.character.talents.highestFirstClearedStage = 1;
      g.character.books = Amount.fromNum(3);
      expect(g.purchaseTalent('first_clear_gold'), 1);
      g.selectTalent(TalentPair.boss, 'first_clear_gold');
      g.spawnEnemy();
      final json =
          jsonDecode(
                jsonEncode(
                  GameSave.capture(g, DateTime.utc(2026, 10, 11)).toJson(),
                ),
              )
              as Map<String, dynamic>;
      final effects =
          ((json['adventure'] as Map)['attempt'] as Map)['effects'] as Map;
      effects['first_clear_gold'] = .4;
      expect(() => GameSave.fromJson(json), throwsFormatException);
    },
  );
  test(
    'first/milestone Gold, Books and healing cannot replay through six save/death loops',
    () {
      var g = GameSimulation()..stage = 20;
      g.character.equipment.addAll({'weapon': 1000, 'armor': 1000});
      g.heroHp = g.stats.maxHp.scale(.5);
      g.character.talents.highestFirstClearedStage = 19;
      // Synthetic owned ranks isolate claim behavior from funding policy.
      for (final id in ['first_clear_gold', 'stage_heal', 'stage_gold']) {
        g.character.talents.ownedRanks[id] = 3;
        g.selectTalent(TalentCatalog.require(id).pair, id);
      }
      var firstPayments = 0, milestonePayments = 0, stageBonuses = 0;
      for (var cycle = 0; cycle < 6; cycle++) {
        forcedClear(g);
        final r = g.lastReward!;
        if (r.lines.containsKey(RewardSource.firstClearBaseGold)) {
          firstPayments++;
        }
        if (r.lines.containsKey(RewardSource.milestoneBooks)) {
          milestonePayments++;
        }
        if (r.lines.containsKey(RewardSource.stageBonusGold)) {
          stageBonuses++;
        }
        final hp = g.heroHp, gold = g.character.gold, books = g.character.books;
        g = restart(g);
        expect(g.heroHp.log10, hp.log10);
        expect(g.character.gold.log10, gold.log10);
        expect(g.character.books.log10, books.log10);
        g.killHero();
        until(g, () => g.phase.name == 'traveling');
        g = restart(g);
      }
      expect(firstPayments, 1);
      expect(milestonePayments, 1);
      expect(stageBonuses, 3);
      expect(g.character.books.toDouble(), closeTo(10, 1e-8));
      expect(g.character.talents.usedRepeats, {20: 2});
      expect(g.character.talents.highestFirstClearedStage, 20);
      expect(g.stats.attackSpeed, 1);
      expect(TalentProfile.candidate.repeatLimit, 2);
    },
  );
}
