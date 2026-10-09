import 'package:idle_companion/core/assets/animation_catalog.dart';

/// Old-chain fixtures deliberately declare debug frames outside shipped content.
AnimationCatalog legacyTestAnimations() => AnimationCatalog({
  for (final id in [
    'entry',
    'first',
    'second',
    'later',
    'activity',
    'a',
    'b',
    'c',
    'single',
    'deepRest',
    'custom',
    'rest',
    'end',
  ])
    id: AnimationDefinition(id: id),
});
