import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/assets/animation_catalog.dart';

void main() {
  test('one-shots hold their end; loop entry frames play only once', () {
    const entry = AnimationDefinition(id: 'entry', frames: 3, stepTime: .125);
    expect(entry.frameIndex(.125), 1);
    expect(entry.frameIndex(1), 2);
    const activity = AnimationDefinition(
      id: 'activity',
      frames: 3,
      stepTime: .125,
      loop: true,
      loopStartFrame: 1,
    );
    expect(activity.frameIndex(0), 0);
    expect(activity.frameIndex(.125), 1);
    expect(activity.frameIndex(.25), 2);
    expect(activity.frameIndex(.375), 1);
    expect(activity.frameIndex(.5), 2);
    expect(activity.frameIndex(100.375), 1);
  });
  test('loop entry metadata rejects invalid start indices', () {
    for (final index in [-1, 3]) {
      expect(
        () => AnimationCatalog({
          'invalid': AnimationDefinition(
            id: 'invalid',
            frames: 3,
            loop: true,
            loopStartFrame: index,
          ),
        }),
        throwsArgumentError,
      );
    }
    expect(
      () => AnimationCatalog({
        'invalid': const AnimationDefinition(
          id: 'invalid',
          frames: 3,
          loopStartFrame: 1,
        ),
      }),
      throwsArgumentError,
    );
  });
  test('animation metadata rejects mismatched IDs and nonfinite timelines', () {
    expect(
      () => AnimationCatalog({'wrong': const AnimationDefinition(id: 'right')}),
      throwsArgumentError,
    );
    expect(
      () => AnimationCatalog({
        'huge': const AnimationDefinition(
          id: 'huge',
          frames: 2,
          stepTime: 1e308,
        ),
      }),
      throwsArgumentError,
    );
    expect(
      () => AnimationCatalog({
        'anchor': const AnimationDefinition(id: 'anchor', anchorX: double.nan),
      }),
      throwsArgumentError,
    );
    final catalog = AnimationCatalog({
      'hero.walk': const AnimationDefinition(
        id: 'hero.walk',
        frames: 8,
        stepTime: 1 / 8,
        loop: true,
      ),
    });
    expect(catalog.get('hero.walk').duration, 1);
    expect(catalog.get('new.placeholder').duration, .6);
  });
}
