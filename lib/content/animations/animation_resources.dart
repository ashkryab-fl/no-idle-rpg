import '../../core/animation/animation_resources.dart';
import 'enemies/goblin_clips.dart';
import 'hero/clips.dart';

/// Installed sprite content only. Procedural enemies have a separate timeline.
AnimationResources defaultAnimationResources() => _resources();

/// Opt-in authoring demo: additional timelines over the installed PNGs.
AnimationResources demoAnimationResources() =>
    _resources(includeDemoClips: true);

AnimationResources _resources({bool includeDemoClips = false}) {
  final hero = HeroClips.resources(includeDemoClips: includeDemoClips);
  final goblin = GoblinClips.resources();
  return AnimationResources(
    rigs: [...hero.rigs.values, ...goblin.rigs.values],
    frames: [...hero.frames.values, ...goblin.frames.values],
    clips: [...hero.clips.values, ...goblin.clips.values],
    poses: [...hero.poses.values, ...goblin.poses.values],
  );
}
