import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/content/animations/hero/clips.dart';
import 'package:idle_companion/content/animations/hero/phone_graph.dart';
import 'package:idle_companion/content/animations/hero/rest_graphs.dart';
import 'package:idle_companion/core/animation/graph/node.dart';
import 'package:idle_companion/core/animation/ids.dart';
import 'package:idle_companion/domain/activity/rest_coordinator.dart';
import 'package:idle_companion/game/animation/hero_animation_coordinator.dart';

final class _Roll implements Random {
  _Roll(this.value);
  final double value;
  int calls = 0;
  @override
  double nextDouble() {
    calls++;
    return value;
  }

  @override
  bool nextBool() => throw UnimplementedError();
  @override
  int nextInt(int max) => throw UnimplementedError();
}

void main() {
  final resources = HeroClips.resources();
  final entry = resources.clip(HeroClips.phoneEnter);
  final wake = resources.clip(HeroClips.phoneWake);

  test(
    'phone entry reuses walk geometry and wake leaves walking its first frame',
    () {
      final walk = resources.clip(const ClipId('hero.walk'));
      expect(entry.frames.first.frameId, walk.frames.last.frameId);
      expect(
        wake.frames.last.frameId,
        const FrameId('hero.phoneFrames.frame.10'),
      );
      expect(
        identical(
          resources.frame(entry.frames.first.frameId),
          resources.frame(walk.frames.last.frameId),
        ),
        isTrue,
      );
      expect(
        wake.frames.map((frame) => frame.frameId),
        isNot(contains(walk.frames.first.frameId)),
      );
    },
  );

  test('root selects a complete subtree once and retains it during idle', () {
    final rolls = _Roll(.375);
    final rest = RestCoordinator(rolls, resources);
    rest.setIdleSeconds(1000);
    rest.advance(entry.duration);
    expect(rest.graphRunner!.snapshot.nodeId, HeroPhoneRestGraph.scroll);
    rest.advance(300);
    expect(rest.graphRunner!.snapshot.nodeId, HeroPhoneRestGraph.scroll);
    expect(rolls.calls, 1);
    final root = HeroRestGraphs.rest(resources: resources);
    final selection = root.node(root.entryNode) as Select;
    expect(selection.choices.map((c) => c.weight), [1, 1, 1, 1, 1]);
  });

  test('seated subtree remains available beside phone subtree', () {
    final rest = RestCoordinator(_Roll(.125), resources);
    rest.setIdleSeconds(1000);
    rest.advance(1.7);
    expect(rest.graphRunner!.snapshot.nodeId, HeroRestGraphs.sharpen);
  });

  for (final index in [0, 7, 8, 10]) {
    test(
      'return from scroll frame $index starts startled wake immediately',
      () {
        final rest = RestCoordinator(_Roll(.375), resources);
        rest.setIdleSeconds(1000);
        final scroll = resources.clip(HeroClips.phoneScroll);
        rest.advance(entry.duration + scroll.frameStart(index) + .01);
        rest.setIdleSeconds(0);
        rest.advance(0);
        expect(rest.graphRunner!.snapshot.nodeId, HeroPhoneRestGraph.wake);
        expect(rest.graphRunner!.snapshot.frameId, wake.frames.first.frameId);
        expect(rest.blocksAdventure, isTrue);
        rest.advance(wake.duration - .001);
        expect(rest.blocksAdventure, isTrue);
        rest.advance(.001);
        expect(rest.blocksAdventure, isFalse);
      },
    );
  }

  test('early return finishes drawing phone then wakes without scrolling', () {
    final rest = RestCoordinator(_Roll(.375), resources);
    rest.setIdleSeconds(1000);
    rest.advance(.1);
    rest.setIdleSeconds(0);
    rest.advance(entry.duration - .1);
    expect(rest.graphRunner!.snapshot.nodeId, HeroPhoneRestGraph.wake);
    rest.advance(wake.duration);
    expect(rest.blocksAdventure, isFalse);
  });

  test('walk reaches last frame before entry and rest blocks adventure', () {
    final rest = RestCoordinator(_Roll(.375), resources);
    final hero = HeroAnimationCoordinator(resources, rest: rest);
    hero.advance(.25);
    rest.setIdleSeconds(1000);
    expect(hero.advance(.5), 0);
    expect(rest.graphRunner, isNull);
    expect(hero.snapshot.frameId, const FrameId('hero.walk.frame.6'));
    expect(hero.advance(.25), 0);
    expect(hero.snapshot.frameId, const FrameId('hero.walk.frame.8'));
    hero.advance(.01);
    expect(rest.graphRunner!.snapshot.nodeId, HeroPhoneRestGraph.enter);
    expect(hero.snapshot.frameId, const FrameId('hero.walk.frame.8'));
    hero.advance(entry.duration);
    rest.setIdleSeconds(0);
    hero.advance(wake.duration - .001);
    expect(hero.snapshot.frameId, const FrameId('hero.phoneFrames.frame.10'));
    hero.advance(.001);
    expect(hero.blocksAdventure, isFalse);
    expect(hero.snapshot.frameId, const FrameId('hero.walk.frame.0'));
    expect(hero.restReturnRevision, 1);
    hero.advance(.125);
    expect(hero.snapshot.frameId, const FrameId('hero.walk.frame.1'));
  });

  test('wake cues take sword while phone remains in its flight frames', () {
    final release = wake.markers.singleWhere((m) => m.id == 'phoneReleased');
    final grab = wake.markers.singleWhere((m) => m.id == 'swordGrabbed');
    expect(release.time, lessThan(grab.time));
    expect(
      wake.frames[wake.frameIndex(grab.time)].frameId,
      const FrameId('hero.phoneFrames.frame.9'),
    );
  });

  test(
    'return before the walk step finishes cancels entry without a rest event',
    () {
      final rest = RestCoordinator(_Roll(.375), resources);
      final hero = HeroAnimationCoordinator(resources, rest: rest);
      rest.setIdleSeconds(1000);
      hero.advance(.1);
      final generation = hero.snapshot.generation;
      hero.advance(.1);
      expect(hero.snapshot.generation, generation);
      expect(rest.graphRunner, isNull);
      rest.setIdleSeconds(0);
      hero.advance(.1);
      expect(hero.blocksAdventure, isFalse);
      expect(hero.restReturnRevision, 0);
      expect(rest.graphRunner, isNull);
    },
  );
}
