import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/assets/animation_catalog.dart';
import 'package:idle_companion/domain/activity/idle_animation.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';

class FixedRandom implements Random {
  FixedRandom(this.roll);
  final double roll;
  @override
  double nextDouble() => roll;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

void main() {
  test('sit-down holds its final frame before a separate sharpening loop', () {
    final animations = AnimationCatalog();
    final idle = IdleBehaviorSystem(Random(1), animations)..setIdleSeconds(30);
    idle.update(.01);
    expect(idle.animationId, 'hero.sitDown');
    idle.update(1.25);
    expect(
      animations.get(idle.animationId!).frameIndex(idle.animationElapsed),
      3,
    );
    idle.update(.2);
    expect(idle.animationId, 'hero.sitDown');
    expect(
      animations.get(idle.animationId!).frameIndex(idle.animationElapsed),
      3,
    );
    idle.update(.3);
    expect(idle.animationId, 'hero.sharpen');
    expect(idle.animationElapsed, 0);
    for (var i = 0; i < 100; i++) {
      idle.update(.37);
      expect(idle.animationId, 'hero.sharpen');
      expect(
        animations.get('hero.sharpen').frameIndex(idle.animationElapsed),
        inInclusiveRange(1, 4),
      );
    }
    idle.setIdleSeconds(0);
    idle.update(.01);
    expect(idle.animationId, 'hero.caught');
    idle.update(1);
    expect(idle.animationId, isNull);
  });

  test('return during sitting finishes the entry without starting a child', () {
    final idle = IdleBehaviorSystem(Random(1), AnimationCatalog())
      ..setIdleSeconds(30);
    idle.update(.01);
    idle.setIdleSeconds(0);
    idle.update(.5);
    expect(idle.animationId, 'hero.sitDown');
    idle.update(1.21);
    expect(idle.animationId, 'hero.caught');
  });

  test(
    'a noninterruptible seated loop completes its current cycle on return',
    () {
      final idle = IdleBehaviorSystem(
        Random(1),
        AnimationCatalog(),
        definitions: const [
          IdleAnimationDefinition(
            id: 'hero.sharpen',
            requiredIdleLevel: IdleLevel.level1,
            canInterrupt: false,
            loopUntilActivity: true,
          ),
        ],
      )..setIdleSeconds(30);
      idle.update(.01);
      idle.update(1.5);
      idle.setIdleSeconds(0);
      idle.update(.1);
      expect(idle.animationId, 'hero.sharpen');
      idle.update(.5);
      expect(idle.animationId, 'hero.caught');
    },
  );

  test('weighted continuations always start after the shared entry pose', () {
    const definitions = [
      IdleAnimationDefinition(
        id: 'entry',
        requiredIdleLevel: IdleLevel.level1,
        nextAnimationIds: ['first', 'second'],
        holdLastFrame: .3,
      ),
      IdleAnimationDefinition(id: 'first', requiredIdleLevel: IdleLevel.level1),
      IdleAnimationDefinition(
        id: 'second',
        requiredIdleLevel: IdleLevel.level1,
        weight: 3,
      ),
    ];
    for (final (roll, child) in [(.1, 'first'), (.9, 'second')]) {
      final idle = IdleBehaviorSystem(
        FixedRandom(roll),
        AnimationCatalog(),
        definitions: definitions,
      )..setIdleSeconds(30);
      idle.update(.01);
      expect(idle.animationId, 'entry');
      idle.update(.7);
      expect(idle.animationId, 'entry');
      idle.update(.21);
      expect(idle.animationId, child);
      expect(idle.animationElapsed, 0);
    }
  });

  test('blocked continuations preserve the completed pose until eligible', () {
    final idle = IdleBehaviorSystem(
      Random(1),
      AnimationCatalog(),
      definitions: const [
        IdleAnimationDefinition(
          id: 'hero.sitDown',
          requiredIdleLevel: IdleLevel.level1,
          nextAnimationIds: ['later'],
        ),
        IdleAnimationDefinition(
          id: 'later',
          requiredIdleLevel: IdleLevel.level2,
        ),
      ],
    )..setIdleSeconds(30);
    idle.update(.01);
    for (var i = 0; i < 10; i++) {
      idle.update(1);
      expect(idle.animationId, 'hero.sitDown');
    }
    expect(
      AnimationCatalog().get('hero.sitDown').frameIndex(idle.animationElapsed),
      3,
    );
    idle.setIdleSeconds(120);
    idle.update(.01);
    expect(idle.animationId, 'later');
  });

  test('branch cooldown holds the entry instead of replaying it', () {
    final idle = IdleBehaviorSystem(
      Random(1),
      AnimationCatalog(),
      definitions: const [
        IdleAnimationDefinition(
          id: 'entry',
          requiredIdleLevel: IdleLevel.level1,
          nextAnimationIds: ['activity'],
        ),
        IdleAnimationDefinition(
          id: 'activity',
          requiredIdleLevel: IdleLevel.level1,
          cooldown: 3,
        ),
      ],
    )..setIdleSeconds(30);
    idle.update(.01);
    idle.update(.61);
    expect(idle.animationId, 'activity');
    idle.update(.61);
    expect(idle.animationId, 'entry');
    idle.update(.61);
    expect(idle.animationId, 'entry');
    expect(idle.animationElapsed, .6);
    idle.update(2);
    expect(idle.animationId, 'activity');
  });

  test('explicit finite repeats play before holding the final pose', () {
    final idle = IdleBehaviorSystem(
      Random(1),
      AnimationCatalog(),
      definitions: const [
        IdleAnimationDefinition(
          id: 'hero.sitDown',
          requiredIdleLevel: IdleLevel.level1,
          minLoops: 2,
          maxLoops: 2,
          holdLastFrame: .2,
        ),
      ],
    )..setIdleSeconds(30);
    idle.update(.01);
    idle.update(1.3);
    final animation = AnimationCatalog().get('hero.sitDown');
    expect(animation.frameIndex(idle.animationElapsed), 0);
    idle.update(1.15);
    expect(animation.frameIndex(idle.animationElapsed), 3);
  });

  test('branch validation rejects missing targets and indirect cycles', () {
    for (final target in ['entry', 'missing']) {
      expect(
        () => IdleBehaviorSystem(
          Random(1),
          AnimationCatalog(),
          definitions: [
            const IdleAnimationDefinition(
              id: 'entry',
              requiredIdleLevel: IdleLevel.level1,
              nextAnimationIds: ['child'],
            ),
            IdleAnimationDefinition(
              id: 'child',
              requiredIdleLevel: IdleLevel.level1,
              nextAnimationIds: [target],
            ),
          ],
        ),
        throwsArgumentError,
      );
    }
  });

  test('shared descendants are valid and never become independent roots', () {
    final idle = IdleBehaviorSystem(
      FixedRandom(.9),
      AnimationCatalog(),
      definitions: const [
        IdleAnimationDefinition(
          id: 'entry',
          requiredIdleLevel: IdleLevel.level1,
          nextAnimationIds: ['a', 'b'],
        ),
        IdleAnimationDefinition(
          id: 'a',
          requiredIdleLevel: IdleLevel.level1,
          nextAnimationId: 'end',
        ),
        IdleAnimationDefinition(
          id: 'b',
          requiredIdleLevel: IdleLevel.level1,
          nextAnimationId: 'end',
        ),
        IdleAnimationDefinition(id: 'end', requiredIdleLevel: IdleLevel.level1),
      ],
    )..setIdleSeconds(30);
    idle.update(.01);
    expect(idle.animationId, 'entry');
    idle.update(.61);
    expect(idle.animationId, 'b');
    idle.update(.61);
    expect(idle.animationId, 'end');
  });

  test('seated sharpening does not move or spawn an encounter', () {
    final game = GameSimulation(random: Random(1));
    game.advance(.2);
    final distance = game.distance;
    game.idle.setIdleSeconds(30);
    game.advance(2);
    expect(game.heroAnimation, 'hero.sharpen');
    for (var i = 0; i < 100; i++) {
      game.advance(.1);
      game.spawnEnemy();
      expect(game.heroAnimation, 'hero.sharpen');
      expect(game.distance, distance);
      expect(game.enemy, isNull);
    }
  });
}
