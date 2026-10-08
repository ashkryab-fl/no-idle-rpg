import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/assets/animation_catalog.dart';

void main() {
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
