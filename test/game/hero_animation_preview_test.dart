import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/content/animations/hero/debug_previews.dart';
import 'package:idle_companion/content/animations/hero/phone_graph.dart';
import 'package:idle_companion/content/animations/hero/rest_graphs.dart';
import 'package:idle_companion/content/animations/hero/sleep_graph.dart';
import 'package:idle_companion/core/animation/ids.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/game/systems/game_state_machine.dart';
import '../helpers/simulation_fixture.dart';

void main() {
  test('rest buttons select the same subtree regardless of game random', () {
    for (final roll in [.01, .99]) {
      final game = GameSimulation(idleRandom: ConstantRandom(roll));
      for (final (preview, node) in [
        (HeroAnimationPreview.sharpenRest, HeroRestGraphs.sharpen),
        (HeroAnimationPreview.readRest, HeroRestGraphs.read),
        (HeroAnimationPreview.phoneRest, HeroPhoneRestGraph.scroll),
        (HeroAnimationPreview.sleepRest, HeroSleepRestGraph.sleep),
      ]) {
        for (var repeat = 0; repeat < 3; repeat++) {
          game.heroAnimations.startPreview(preview);
          game.advance(3);
          expect(game.heroPlayback.nodeId, node);
          expect(game.heroAnimations.preview, preview);
          expect(game.distance, 0);
          expect(game.idle.graphRunner, isNull);
        }
      }
    }
  });

  test('every clip can be restarted from its original first frame', () {
    final game = GameSimulation();
    for (final preview in HeroAnimationPreview.values.where((p) => !p.isRest)) {
      game.heroAnimations.startPreview(preview);
      final first = game.resources.clip(preview.clipId!).frames.first.frameId;
      expect(game.heroPlayback.frameId, first);
      game.advance(.5);
      final generation = game.heroPlayback.generation;
      game.heroAnimations.startPreview(preview);
      expect(game.heroPlayback.frameId, first);
      expect(game.heroPlayback.elapsed, 0);
      expect(game.heroPlayback.generation, greaterThan(generation));
    }
  });

  test('wake holds the selected phone exit frame until normal playback', () {
    final game = GameSimulation();
    game.heroAnimations.startPreview(HeroAnimationPreview.phoneRest);
    game.advance(2);
    expect(game.heroAnimations.canWakePreview, isTrue);
    game.heroAnimations.wakePreview();
    expect(game.heroPlayback.nodeId, HeroPhoneRestGraph.wake);
    expect(game.heroAnimations.canWakePreview, isFalse);
    game.advance(1);
    expect(game.heroPlayback.completed, isTrue);
    expect(
      game.heroPlayback.frameId,
      const FrameId('hero.phoneFrames.frame.10'),
    );
    expect(game.distance, 0);
    expect(game.heroAnimations.restReturnRevision, 0);
    game.heroAnimations.stopPreview();
    game.advance(.1);
    expect(game.distance, greaterThan(0));
  });

  test(
    'preview pauses combat, rewards and encounter clocks without changing phase',
    () {
      final game = GameSimulation();
      game.spawnEnemy();
      game.machine.transition(GamePhase.combat);
      game.advance(.1);
      final foe = game.enemy!;
      final hp = game.heroHp;
      final enemyHp = foe.hp;
      final elapsed = game.machine.elapsed;
      final distance = game.distance;
      final scroll = game.scroll;
      final events = game.events.length;
      final attackElapsed = game.heroAnimations.combatPlayback.elapsed;
      game.heroAnimations.startPreview(HeroAnimationPreview.phoneRest);
      game.advance(5);
      expect(game.phase, GamePhase.combat);
      expect(game.heroHp, hp);
      expect(foe.hp, enemyHp);
      expect(game.machine.elapsed, elapsed);
      expect(game.distance, distance);
      expect(game.scroll, scroll);
      expect(game.events.length, events);
      expect(game.heroAnimations.combatPlayback.elapsed, attackElapsed);
      game.heroAnimations.stopPreview();
      game.advance(.1);
      expect(game.machine.elapsed, greaterThan(elapsed));
    },
  );

  test('progress reset clears preview and returns to normal animation', () {
    final game = GameSimulation();
    game.heroAnimations.startPreview(HeroAnimationPreview.death);
    game.resetEncounter();
    expect(game.heroAnimations.isPreviewing, isFalse);
    expect(game.heroPlayback.clipId, const ClipId('hero.walk'));
  });
}
