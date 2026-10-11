import 'dart:convert';
import 'dart:io';
import 'package:idle_companion/core/balance/equipment_curve_profile.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/domain/equipment/equipment.dart';
import 'package:idle_companion/domain/equipment/equipment_purchase.dart';
import 'package:idle_companion/game/systems/enemy_spawner.dart';

/// Counterfactual next-foe costs, independent of the policy's next actual choice.
void main(List<String> args) {
  final baseline =
      jsonDecode(
            File(
              args.isEmpty ? 'docs/balance/phase_02_baseline.json' : args.first,
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final profiles = <String, EquipmentCurveProfile>{};
  for (final entry in (baseline['profiles'] as Map<String, dynamic>).entries) {
    final p = entry.value as Map<String, dynamic>;
    PowerCurve power(Map<String, dynamic> c) => PowerCurve(
      threshold: c['threshold'],
      width: c['width'],
      tailRate: c['tailRate'],
    );
    profiles[entry.key] = EquipmentCurveProfile(
      id: entry.key,
      weapon: power(p['weapon']),
      armor: power(p['armor']),
      chance: ChanceCurve(
        threshold: p['chance']['threshold'],
        cap: p['chance']['cap'],
        soft: p['chance']['soft'],
      ),
      multiplier: MultiplierCurve(
        threshold: p['multiplier']['threshold'],
        width: p['multiplier']['width'],
        tailScale: p['multiplier']['tailScale'],
        soft: p['multiplier']['soft'],
      ),
      minimumChanceGain: p['minimumChanceGain'],
    );
  }
  final rows = <Map<String, Object?>>[];
  for (final raw in baseline['rows']) {
    final r = raw as Map<String, dynamic>;
    final profile = profiles[r['profile']]!;
    final hero = CharacterProgress()
      ..equipment.addAll(Map<String, int>.from(r['equipment']))
      ..gold = Amount.fromJson(r['goldRemainingLog']);
    final stats = CharacterStats.calculate(hero, profile: profile);
    final foe = EnemyFactory().create(
      EnemyCatalog.definitions.single,
      (r['stage'] as int) - 1,
      isBoss: r['wave'] == 5,
    );
    final hits = foe.hp.ratio(stats.damage).clamp(1.0, 1e9).ceil();
    final income = Amount.fromJson(r['recentGoldPerSecondLog']);
    final hp = Amount.fromJson(r['currentHpLog']);
    final data = <String, Object?>{
      for (final k in ['profile', 'policy', 'income', 'seed', 'hours']) k: r[k],
      'nextFoeHpLog': foe.hp.toJson(),
      'ordinaryHits': hits,
      'heroDead': hp.isZero,
    };
    void target(String id, Amount? required) {
      if (required == null) {
        data['${id}EffectiveCount'] = 0;
        data['${id}EffectiveCostLog'] = null;
        data['${id}EffectiveAffordSeconds'] = 0;
        return;
      }
      final item = EquipmentCatalog.require(id);
      final level = hero.equipment[id] ?? 0;
      final unlimited = CharacterProgress()
        ..equipment.addAll(hero.equipment)
        ..gold = Amount.fromLog(1e308);
      var low = 1,
          high = EquipmentPurchases(
            profile: profile,
          ).quote(unlimited, id, count: null).count;
      if (high == 0 || profile.value(item.stat, level + high) < required) {
        data['${id}EffectiveCount'] = null;
        data['${id}EffectiveAffordSeconds'] = null;
        return;
      }
      while (low < high) {
        final middle = low + (high - low) ~/ 2;
        if (profile.value(item.stat, level + middle) >= required) {
          high = middle;
        } else {
          low = middle + 1;
        }
      }
      final cost = item.batchCost(level, low), shortage = cost - hero.gold;
      data['${id}EffectiveCount'] = low;
      data['${id}EffectiveCostLog'] = cost.toJson();
      data['${id}EffectiveAffordSeconds'] = shortage.isZero
          ? 0
          : income.isZero
          ? null
          : shortage.ratio(income);
    }

    target('weapon', hits == 1 ? null : foe.hp.scale(1 / (hits - 1)));
    // Expected incoming damage at APS=1, without hero crit or overkill savings.
    // Dead heroes use full HP after respawn; Armor never revives them.
    final incoming = foe.stats.dps.scale((hits - 1).toDouble());
    final availableHp = hp.isZero ? stats.maxHp : hp;
    final missingHp = incoming - availableHp;
    target('armor', missingHp.isZero ? null : stats.maxHp + missingHp);
    rows.add(data);
  }
  stdout.writeln(
    jsonEncode({
      'method':
          'Next configured foe, ordinary noncritical hero hits; Weapon target reduces ceil(foeHP/damage) by one. Armor target covers expected incoming DPS*(hits-1); dead heroes start after respawn. Null time means no income or no representable target. Both are counterfactual estimates, not guarantees of a stochastic encounter or the policy selection.',
      'rows': rows,
    }),
  );
}
