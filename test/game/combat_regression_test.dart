import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/content/animations/animation_resources.dart';
import 'package:idle_companion/content/animations/enemies/procedural_timelines.dart';
import 'package:idle_companion/core/animation/animation_clip.dart';
import 'package:idle_companion/core/animation/attack_playback.dart';
import 'package:idle_companion/core/animation/ids.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/game/animation/hero_animation_coordinator.dart';
import 'package:idle_companion/game/systems/combat_system.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/game/systems/game_state_machine.dart';
import '../helpers/simulation_fixture.dart' show until;

CombatStats fighter(double speed) => CombatStats(
  maxHp: Amount.fromNum(100),
  damage: Amount.fromNum(10),
  attackSpeed: speed,
  critChance: 0,
  critDamage: 1.5,
);
void main() {
  test('lethal hit finishes the attack without dealing damage again', () {
    final game = GameSimulation(random: Random(1));
    game.spawnEnemy();
    game.enemy!.hp = Amount.fromNum(1);
    until(game, () => game.phase == GamePhase.enemyDeath);

    expect(game.heroPlayback.clipId, const ClipId('hero.attack'));
    expect(game.heroPlayback.frameIndex, 2);
    final frames = <int>{};
    until(game, () {
      final snapshot = game.heroPlayback;
      if (snapshot.clipId != const ClipId('hero.attack')) return true;
      frames.add(snapshot.frameIndex!);
      return false;
    });
    expect(frames, {2, 3, 4});
    expect(game.heroPlayback.clipId, const ClipId('hero.idle'));
    expect(
      game.events.where((event) => event.damage?.fromHero == true),
      hasLength(1),
    );
    until(game, () => game.phase == GamePhase.reward);
    expect(game.kills, 1);
  });

  test('attack recovery keeps combat speed and yields to hero death', () {
    for (final period in [1.0, .2]) {
      final hero = GameSimulation().heroAnimations;
      hero.combatPeriod = period;
      hero.synchronize(HeroAnimationRequest.combat);
      final clip = hero.combatPlayback.clip;
      final rate = max(1.0, clip.duration / period);
      hero.combatPlayback.advance(.35 / rate, period);
      hero.synchronize(HeroAnimationRequest.idle);
      expect(hero.snapshot.elapsed, closeTo(.35, 1e-9));
      hero.advance(.25 / rate);
      expect(hero.snapshot.clipId, const ClipId('hero.attack'));
      expect(hero.snapshot.frameIndex, 4);
      hero.advance(.06 / rate);
      expect(hero.snapshot.clipId, const ClipId('hero.idle'));

      hero.synchronize(HeroAnimationRequest.combat);
      hero.combatPlayback.advance(.35 / rate, period);
      hero.synchronize(HeroAnimationRequest.idle);
      hero.synchronize(HeroAnimationRequest.death);
      expect(hero.snapshot.clipId, const ClipId('hero.death'));
      expect(hero.snapshot.elapsed, 0);
    }
  });

  test('hero damage falls on the slash frame at normal and fast speeds', () {
    for (final speed in [1.0, 5.0]) {
      final catalog = defaultAnimationResources();
      final combat = CombatSystem(
        Random(1),
        heroPlayback: AttackPlayback(catalog.clip(const ClipId('hero.attack'))),
        enemyPlayback: AttackPlayback(ProceduralEnemyTimelines.attack),
      );
      final attack = catalog.clip(const ClipId('hero.attack'));
      expect(attack.duration, closeTo(.66, .000001));
      expect(
        attack.frames[1].duration,
        closeTo(attack.frames[0].duration * 2, .000001),
      );
      expect(attack.markers.single.time, .35);
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
