import '../../../core/animation/animation_resources.dart';
import '../../../core/animation/graph/graph_definition.dart';
import '../../../core/animation/ids.dart';
import 'clips.dart';
import 'phone_graph.dart';
import 'rest_graphs.dart';
import 'variants.dart';

/// Explicit debug choices: a button always starts the same clip or subtree.
enum HeroAnimationPreview {
  sharpenRest('Sharpen rest'),
  readRest('Reading rest'),
  phoneRest('Phone rest'),
  walk('Walk', ClipId('hero.walk')),
  attack('Attack', ClipId('hero.attack')),
  idle('Standing', ClipId('hero.idle')),
  death('Death', ClipId('hero.death')),
  sitDown('Sit down', ClipId('hero.sitDown')),
  seated('Seated', ClipId('hero.seated')),
  sharpen('Sharpen', ClipId('hero.sharpen')),
  read('Read', HeroClips.read),
  readCleanup('Put book away', HeroClips.readCleanup),
  standUp('Stand up', ClipId('hero.standUp')),
  phoneEnter('Take phone out', HeroClips.phoneEnter),
  phoneScroll('Scroll / laugh', HeroClips.phoneScroll),
  phoneWake('Throw phone / walk', HeroClips.phoneWake);

  const HeroAnimationPreview(this.label, [this.clipId]);
  final String label;
  final ClipId? clipId;
  bool get isRest => clipId == null;

  AnimationGraphDefinition graph(AnimationResources resources) =>
      switch (this) {
        phoneRest => HeroPhoneRestGraph.definition(resources: resources),
        sharpenRest || readRest => HeroRestGraphs.seatedRest(
          resources: resources,
          activities: [
            HeroRestVariants.activities.singleWhere(
              (variant) =>
                  variant.clipId ==
                  (this == readRest
                      ? HeroClips.read
                      : const ClipId('hero.sharpen')),
            ),
          ],
        ),
        _ => throw StateError('Clip preview has no rest graph: $name'),
      };
}
