import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/content/animations/hero/rest_graphs.dart';
import 'package:idle_companion/core/animation/animation_clip.dart';
import 'package:idle_companion/core/animation/attack_playback.dart';
import 'package:idle_companion/core/animation/ids.dart';
import 'package:idle_companion/core/animation/graph/graph_runner.dart';
import 'package:idle_companion/core/assets/animation_catalog.dart';
import 'package:idle_companion/domain/activity/rest_coordinator.dart';
import 'package:idle_companion/game/animation/hero_animation_coordinator.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/game/systems/game_state_machine.dart';

HeroAnimationCoordinator coordinator() {
  final catalog = AnimationCatalog();
  return HeroAnimationCoordinator(
    catalog.resources,
    rest: RestCoordinator(Random(7), catalog),
  );
}

void main() {
  test('production sprite catalog contains only installed hero assets', () {
    final resources = AnimationCatalog().resources;
    expect(resources.clips.keys.map((id) => id.value).toSet(), {
      'hero.walk',
      'hero.attack',
      'hero.idle',
      'hero.death',
      'hero.sitDown',
      'hero.seated',
      'hero.sharpen',
      'hero.standUp',
    });
    for (final frame in resources.frames.values) {
      expect(frame.debugPlaceholder, false);
      expect(File(frame.asset!).existsSync(), true, reason: frame.asset);
    }
    for (final removed in [
      'hero.a1',
      'hero.a2',
      'hero.a3',
      'hero.b',
      'hero.c',
      'hero.d',
      'hero.hit',
      'hero.caught',
      'slime.walk',
      'slime.attack',
      'slime.death',
      'sentinel.idle',
      'wisp.hit',
    ]) {
      expect(() => resources.clip(ClipId(removed)), throwsArgumentError);
    }
  });

  test('rest completion passes remaining time to a fresh walking clock', () {
    final hero = coordinator();
    hero.advance(3.7);
    hero.rest.setIdleSeconds(30);
    expect(hero.advance(2), 0);
    expect(hero.snapshot.nodeId, HeroRestGraphs.sharpen);
    hero.rest.setIdleSeconds(0);
    expect(hero.advance(1.85), closeTo(.05, 1e-9));
    expect(hero.blocksAdventure, false);
    expect(
      hero.rest.events.whereType<GraphCompletionEvent>().single.result,
      GraphResultId.readyToTravel,
    );
    expect(hero.snapshot.clipId, const ClipId('hero.walk'));
    expect(hero.snapshot.elapsed, closeTo(.05, 1e-9));
    expect(hero.snapshot.frameIndex, 0);
    hero.advance(.075);
    expect(hero.snapshot.frameIndex, 1);
  });

  test('partitioned rest/exit and walking match 30/60 FPS at x1/x5/x20', () {
    final reference = coordinator()..rest.setIdleSeconds(30);
    reference.advance(2);
    reference.rest.setIdleSeconds(0);
    reference.advance(3);
    for (final fps in [30, 60]) {
      for (final speed in [1, 5, 20]) {
        final hero = coordinator()..rest.setIdleSeconds(30);
        var travel = 0.0;
        final dt = speed / fps;
        for (var i = 0; i < 2 * fps ~/ speed; i++) {
          expect(hero.advance(dt), 0);
        }
        hero.rest.setIdleSeconds(0);
        var elapsed = 0.0;
        while (elapsed < 3) {
          final step = min(dt, 3 - elapsed);
          travel += hero.advance(step);
          elapsed += step;
        }
        expect(travel, closeTo(1.2, 1e-9));
        expect(hero.snapshot.clipId, reference.snapshot.clipId);
        expect(hero.snapshot.frameId, reference.snapshot.frameId);
        expect(
          hero.snapshot.elapsed,
          closeTo(reference.snapshot.elapsed, 1e-9),
        );
        expect(hero.blocksAdventure, false);
      }
    }
  });

  test(
    'inactivity during exit finishes standing before another rest entry',
    () {
      final hero = coordinator()..rest.setIdleSeconds(30);
      hero.advance(2);
      hero.rest.setIdleSeconds(0);
      hero.advance(.6);
      expect(hero.snapshot.nodeId, HeroRestGraphs.stand);
      final generation = hero.snapshot.generation;
      hero.rest.setIdleSeconds(30);
      expect(hero.advance(1.4), 0);
      expect(hero.snapshot.nodeId, HeroRestGraphs.sit);
      expect(hero.snapshot.elapsed, closeTo(.2, 1e-9));
      expect(hero.snapshot.generation, greaterThanOrEqualTo(generation));
      expect(hero.blocksAdventure, true);
    },
  );

  test('snapshots are immutable; reading never advances clocks', () {
    final game = GameSimulation(random: Random(7));
    game.advance(.2);
    final snapshot = game.heroPlayback;
    for (var i = 0; i < 100; i++) {
      expect(game.heroPlayback.frameId, snapshot.frameId);
      expect(game.heroPlayback.elapsed, snapshot.elapsed);
    }
    game.killHero();
    expect(game.heroPlayback.generation, greaterThan(snapshot.generation));
    expect(game.heroPlayback.clipId, const ClipId('hero.death'));
    expect(snapshot.clipId, const ClipId('hero.walk'));
    expect(snapshot.elapsed, closeTo(.2, 1e-9));
    game.resetEncounter();
    expect(game.heroPlayback.clipId, const ClipId('hero.walk'));
    expect(game.heroPlayback.elapsed, 0);
    expect(game.heroPlayback.frameIndex, 0);
  });

  test('combat damage, slash cursor and hit flash share the same playback', () {
    final game = GameSimulation(random: Random(1));
    game.spawnEnemy();
    game.machine.transition(GamePhase.combat);
    expect(
      identical(game.combat.heroClock, game.heroAnimations.combatPlayback),
      true,
    );
    expect(
      identical(game.combat.enemyClock, game.enemyAnimations.combatPlayback),
      true,
    );
    game.advance(.36);
    final snapshot = game.heroPlayback;
    expect(snapshot.clipId, const ClipId('hero.attack'));
    expect(snapshot.frameIndex, 2);
    expect(snapshot.damageFlash, true);
    expect(snapshot.frame!.asset, 'assets/characters/hero/attack.png');
    expect(
      snapshot.elapsed,
      closeTo(game.heroAnimations.combatPlayback.elapsed, 1e-9),
    );
    game.advance(.25);
    expect(game.heroPlayback.clipId, const ClipId('hero.idle'));
  });

  test('attack retiming retains hits and chronological multiple markers', () {
    final resource = AnimationCatalog().resources.clip(
      const ClipId('hero.attack'),
    );
    final playback = AttackPlayback(resource);
    expect(
      playback.advance(.4, 1).single.marker.kind,
      AnimationMarkerKind.damage,
    );
    expect(playback.advance(.01, .5), isEmpty);
    expect(playback.advance(.01, 1), isEmpty);
    playback.reset();
    playback.advance(.25, .5);
    // Marker moves earlier than the current cycle fraction. Emit once now,
    // without rewinding the visible cursor to the marker's earlier timestamp.
    final due = playback.advance(.01, 1);
    expect(due.single.timeWithinStep, 0);
    expect(playback.elapsed, closeTo(.51, 1e-9));
    expect(playback.advance(.01, 1), isEmpty);
    playback.reset();
    final hits = playback.advance(4, .2);
    expect(hits, hasLength(20));
    expect(hits.map((event) => event.loopCount), Iterable.generate(20));
    expect(
      hits.map((event) => event.timeWithinStep),
      orderedEquals(hits.map((event) => event.timeWithinStep).toList()..sort()),
    );
  });
}
