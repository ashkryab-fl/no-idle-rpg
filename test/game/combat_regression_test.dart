import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/content/animations/animation_resources.dart';
import 'package:idle_companion/content/animations/enemies/procedural_timelines.dart';
import 'package:idle_companion/core/animation/animation_clip.dart';
import 'package:idle_companion/core/animation/attack_playback.dart';
import 'package:idle_companion/core/animation/ids.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/game/systems/combat_system.dart';

CombatStats fighter(double speed) => CombatStats(
  maxHp: Amount.fromNum(100),
  damage: Amount.fromNum(10),
  attackSpeed: speed,
  critChance: 0,
  critDamage: 1.5,
);
void main() {
  test('hero damage falls on the slash frame at normal and fast speeds', () {
    for (final speed in [1.0, 5.0]) {
      final catalog = defaultAnimationResources();
      final combat = CombatSystem(
        Random(1),
        heroPlayback: AttackPlayback(catalog.clip(const ClipId('hero.attack'))),
        enemyPlayback: AttackPlayback(ProceduralEnemyTimelines.attack),
      );
      final attack = catalog.clip(const ClipId('hero.attack'));
      final stats = fighter(speed);
      final hitTime =
          attack.markers.single.time * min(1, 1 / speed / attack.duration);
      final before = combat.update(hitTime - .0001, stats, fighter(1), 1);
      expect(before.where((event) => event.fromHero), isEmpty);
      final hits = combat.update(.0002, stats, fighter(1), 1);
      expect(hits.where((event) => event.fromHero), hasLength(1));
      expect(
        attack.frameIndex(combat.heroClock.clipElapsed(1 / stats.attackSpeed)),
        2,
      );
    }
  });

  test('events from both fighters follow chronological hit timing', () {
    final resources = defaultAnimationResources();
    final enemyAttack = AnimationClipDefinition(
      id: const ClipId('test.enemy.attack'),
      frames: const [ClipFrameDefinition(ProceduralEnemyTimelines.body, .6)],
      markers: const [
        AnimationMarker(
          id: 'damage',
          time: .1,
          kind: AnimationMarkerKind.damage,
        ),
      ],
    );
    final hits = CombatSystem(
      Random(1),
      heroPlayback: AttackPlayback(resources.clip(const ClipId('hero.attack'))),
      enemyPlayback: AttackPlayback(enemyAttack),
    ).update(.4, fighter(1), fighter(1), 1);
    expect(hits.map((event) => event.fromHero).toList(), [false, true]);
  });
}
