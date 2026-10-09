import '../../core/animation/animation_resources.dart';
import 'hero/clips.dart';

/// Installed sprite content only. Procedural enemies have a separate timeline.
AnimationResources defaultAnimationResources() => HeroClips.resources();

/// Opt-in authoring demo: additional timelines over the same eight real PNGs.
AnimationResources demoAnimationResources() =>
    HeroClips.resources(includeDemoClips: true);
