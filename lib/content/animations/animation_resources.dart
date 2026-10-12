import '../../core/animation/animation_resources.dart';
import 'enemies/goblin_clips.dart';
import 'hero/clips.dart';

/// Installed sprite content only. Procedural enemies have a separate timeline.
AnimationResources defaultAnimationResources() => _resources();

AnimationResources _resources() {
  final hero = HeroClips.resources();
  final goblin = GoblinClips.resources();
  return AnimationResources(
    rigs: [...hero.rigs.values, ...goblin.rigs.values],
    frames: [...hero.frames.values, ...goblin.frames.values],
    clips: [...hero.clips.values, ...goblin.clips.values],
    poses: [...hero.poses.values, ...goblin.poses.values],
  );
}
