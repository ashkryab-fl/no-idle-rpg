import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/assets/animation_catalog.dart';
import 'package:idle_companion/domain/activity/idle_animation.dart';
import 'package:idle_companion/domain/activity/activity_statistics.dart';

void main() {
  test('idle graph rejects cycles, missing nodes and invalid thresholds', () {
    final animations = AnimationCatalog();
    expect(
      () =>
          IdleBehaviorSystem(Random(1), animations, thresholds: [30, 20, 300]),
      throwsArgumentError,
    );
    expect(
      () => IdleBehaviorSystem(
        Random(1),
        animations,
        definitions: const [
          IdleAnimationDefinition(
            id: 'a',
            requiredIdleLevel: IdleLevel.level1,
            nextAnimationId: 'missing',
          ),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => IdleBehaviorSystem(
        Random(1),
        animations,
        definitions: const [
          IdleAnimationDefinition(
            id: 'a',
            requiredIdleLevel: IdleLevel.level1,
            nextAnimationId: 'a',
          ),
        ],
      ),
      throwsArgumentError,
    );
    final custom = IdleBehaviorSystem(
      Random(1),
      animations,
      thresholds: [1, 2, 3],
    );
    expect(custom.levelFor(2), IdleLevel.level2);
  });
  test('standalone idle respects loop count and root cooldown', () {
    final idle = IdleBehaviorSystem(
      Random(1),
      AnimationCatalog(),
      definitions: const [
        IdleAnimationDefinition(
          id: 'custom',
          requiredIdleLevel: IdleLevel.level1,
          minLoops: 2,
          maxLoops: 2,
          cooldown: 3,
        ),
      ],
    )..setIdleSeconds(31);
    idle.update(.01);
    idle.update(.61);
    expect(idle.animationId, 'custom');
    idle.update(.61);
    expect(idle.animationId, isNull);
    idle.update(1.9);
    expect(idle.animationId, 'custom');
  });
  test('idle levels use configured thresholds', () {
    final idle = IdleBehaviorSystem(Random(1), AnimationCatalog());
    expect(idle.levelFor(29), IdleLevel.active);
    expect(idle.levelFor(30), IdleLevel.level1);
    expect(idle.levelFor(120), IdleLevel.level2);
    expect(idle.levelFor(300), IdleLevel.level3);
  });
  const chain = [
    IdleAnimationDefinition(
      id: 'a',
      requiredIdleLevel: IdleLevel.level1,
      nextAnimationId: 'b',
      canInterrupt: false,
    ),
    IdleAnimationDefinition(
      id: 'b',
      requiredIdleLevel: IdleLevel.level1,
      nextAnimationId: 'c',
    ),
    IdleAnimationDefinition(id: 'c', requiredIdleLevel: IdleLevel.level1),
  ];
  test('data-driven chain traverses a → b → c; child nodes are not roots', () {
    final idle = IdleBehaviorSystem(
      Random(1),
      AnimationCatalog(),
      definitions: chain,
    )..setIdleSeconds(31);
    idle.update(.01);
    expect(idle.animationId, 'a');
    idle.update(.61);
    expect(idle.animationId, 'b');
    idle.update(.61);
    expect(idle.animationId, 'c');
    idle.update(.61);
    expect(idle.animationId, 'a');
  });
  test('chooses one eligible standalone or full chain at a time', () {
    final idle = IdleBehaviorSystem(
      Random(7),
      AnimationCatalog(),
      definitions: const [
        ...chain,
        IdleAnimationDefinition(
          id: 'single',
          requiredIdleLevel: IdleLevel.level1,
        ),
        IdleAnimationDefinition(
          id: 'deepRest',
          requiredIdleLevel: IdleLevel.level3,
        ),
      ],
    )..setIdleSeconds(30);
    final selectedRoots = <String>{};
    idle.update(.01);
    for (var i = 0; i < 100; i++) {
      final previous = idle.animationId;
      if (previous == 'a' || previous == 'single') {
        selectedRoots.add(previous!);
      }
      expect(previous, isNot('deepRest'));
      idle.update(.61);
      if (previous == 'a') {
        expect(idle.animationId, 'b');
      } else if (previous == 'b') {
        expect(idle.animationId, 'c');
      } else {
        expect(idle.animationId, isIn(['a', 'single']));
      }
    }
    expect(selectedRoots, {'a', 'single'});
    idle.setIdleSeconds(300);
    var deepRestSelected = false;
    for (var i = 0; i < 100; i++) {
      idle.update(.61);
      deepRestSelected |= idle.animationId == 'deepRest';
    }
    expect(deepRestSelected, true);
  });
  test(
    'noninterruptible animation completes then caught state returns to active',
    () {
      final idle = IdleBehaviorSystem(
        Random(1),
        AnimationCatalog(),
        definitions: chain,
      )..setIdleSeconds(31);
      idle.update(.01);
      idle.setIdleSeconds(0);
      idle.update(.1);
      expect(idle.animationId, 'a');
      idle.update(.6);
      expect(idle.animationId, 'hero.caught');
      idle.update(1);
      expect(idle.animationId, isNull);
    },
  );
  test('interruptible animation returns immediately through caught state', () {
    final idle = IdleBehaviorSystem(
      Random(1),
      AnimationCatalog(),
      definitions: [chain.last],
    )..setIdleSeconds(31);
    idle.update(.01);
    idle.setIdleSeconds(0);
    idle.update(.01);
    expect(idle.animationId, 'hero.caught');
  });
  test('session transitions aggregate boundaries and means', () {
    final t = DateTime(2026, 10, 8, 12);
    final activity = ActivityStatisticsService(now: t);
    activity.sample(t, true);
    for (var i = 1; i <= 6; i++) {
      activity.sample(t.add(Duration(seconds: i)), i < 4);
    }
    activity.sample(t.add(const Duration(seconds: 7)), true);
    expect(activity.today.activeSeconds, 4);
    expect(activity.today.idleSeconds, 3);
    expect(activity.today.averageActive, 4);
    expect(activity.today.averageIdle, 3);
  });
  test('local midnight splits today and retains totals', () {
    final t = DateTime(2026, 10, 8, 23, 59, 58);
    final activity = ActivityStatisticsService(now: t);
    activity.sample(t, true);
    activity.sample(t.add(const Duration(seconds: 4)), true);
    expect(activity.day, '2026-10-9');
    expect(activity.today.activeSeconds, 2);
    expect(activity.total.activeSeconds, 4);
    activity.sample(t.add(const Duration(seconds: 5)), false);
    expect(activity.today.averageActive, 3);
  });
  test('suspend and restart do not count offline usage', () {
    final t = DateTime(2026, 10, 8, 12);
    final activity = ActivityStatisticsService(now: t)..sample(t, true);
    activity.sample(t.add(const Duration(seconds: 5)), true);
    activity.sample(t.add(const Duration(hours: 4)), true);
    expect(activity.total.activeSeconds, 5);
    final restored = ActivityStatisticsService.fromJson(activity.toJson());
    restored.sample(t.add(const Duration(hours: 8)), false);
    expect(restored.total.activeSeconds, 5);
  });
}
