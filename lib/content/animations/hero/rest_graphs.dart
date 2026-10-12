import '../../../core/animation/animation_clip.dart';
import '../../../core/animation/animation_resources.dart';
import 'clips.dart';
import '../../../core/animation/graph/graph_definition.dart';
import '../../../core/animation/graph/graph_validator.dart';
import '../../../core/animation/graph/node.dart';
import '../../../core/animation/graph/selection_policy.dart';
import '../../../core/animation/graph/transition.dart';
import '../../../core/animation/ids.dart';
import 'variants.dart';
import 'phone_graph.dart';
import 'sleep_graph.dart';
import 'poses.dart';

abstract final class HeroRestGraphs {
  static const sit = NodeId('rest.sit');
  static const sitHold = NodeId('rest.sitHold');
  static const activitySelect = NodeId('rest.activitySelect');
  static const activityWait = NodeId('rest.activityWait');
  static const sharpen = NodeId('rest.sharpen');
  static const read = NodeId('rest.read');
  static const readCleanup = NodeId('rest.readCleanup');
  static const exitHold = NodeId('rest.exitHold');
  static const standSelect = NodeId('rest.standSelect');
  static const standWait = NodeId('rest.standWait');
  static const stand = NodeId('rest.stand');
  static const done = NodeId('rest.done');
  static const selectionChanged = GraphSignalId('rest.selectionChanged');

  /// Choose one complete rest subtree once per inactivity session.
  static AnimationGraphDefinition rest({AnimationResources? resources}) {
    final content = resources ?? HeroClips.resources();
    final seated = seatedRest(resources: content);
    final phone = HeroPhoneRestGraph.definition(resources: content);
    final sleep = HeroSleepRestGraph.definition(resources: content);
    const choose = NodeId('rest.select');
    const wait = NodeId('rest.wait');
    final graph = AnimationGraphDefinition(
      id: const GraphId('hero.rest'),
      entryNode: choose,
      nodes: [
        Select(
          id: choose,
          fallback: wait,
          choices: [
            GraphChoice(
              id: const VariantId('hero.rest.seated'),
              target: sit,
              completionNode: done,
            ),
            GraphChoice(
              id: const VariantId('hero.rest.phone'),
              target: HeroPhoneRestGraph.enter,
              completionNode: HeroPhoneRestGraph.done,
            ),
            GraphChoice(
              id: const VariantId('hero.rest.sleep'),
              target: HeroSleepRestGraph.standing,
              completionNode: HeroSleepRestGraph.done,
            ),
          ],
        ),
        HoldPose(
          id: wait,
          poseId: HeroPoses.walkLast,
          transitions: [
            AnimationTransition(const Signal(selectionChanged), choose),
          ],
        ),
        ...seated.nodes.values,
        ...phone.nodes.values,
        ...sleep.nodes.values,
      ],
    );
    AnimationGraphValidator(content).validate(graph);
    return graph;
  }

  /// Складає граф саме сидячого відпочинку:
  /// sit -> sitHold (0.5 с) -> activitySelect -> вибрана активність.
  /// Після ActivityReturned: активність -> optional cleanup -> exitHold
  /// (0.3 с) -> standSelect -> вибране вставання -> done (readyToTravel).
  ///
  /// entryNode визначає початок, а transitions кожного вузла — наступний крок;
  /// порядок елементів у nodes сам по собі не задає порядок програвання.
  /// PlayClip програє скінченний кліп, LoopClip повторює активність, HoldPose
  /// утримує позу, Select вибирає гілку, Finish повертає результат графа.
  ///
  /// activities і standUps — описи варіантів із HeroRestVariants за замовчуванням.
  /// Кожен опис додає choice до відповідного Select і власні вузли до nodes.
  /// Політика вибору враховує умови, cooldown і вагу при вході в Select.
  /// Якщо доступних варіантів немає, activityWait / standWait утримує сидячу
  /// позу до selectionChanged, після чого повторюється вибір.
  ///
  /// Сідання і sitHold завершуються навіть при ранньому ActivityReturned.
  /// Вибрана активність повторюється до цього сигналу; автоматичної зміни
  /// активностей протягом одного відпочинку тут немає. Її interruption визначає,
  /// коли можна вийти, а optional cleanup повертає до seatedNeutral перед виходом.
  /// До readyToTravel координатор продовжує блокувати пригоду.
  ///
  /// Графи відпочинку без сідання слід складати окремо з власними входом,
  /// активностями та виходом і передавати через GameSimulation.restGraph.
  /// За замовчуванням rest() вибирає сидяче, телефонне піддерево або сон.
  /// Валідатор нижче перевіряє ресурси та
  /// сумісність поз на переходах зібраного графа.
  static AnimationGraphDefinition seatedRest({
    AnimationResources? resources,
    List<HeroRestVariant>? activities,
    List<HeroRestVariant>? standUps,
  }) {
    final activityVariants = activities ?? HeroRestVariants.activities;
    final standVariants = standUps ?? HeroRestVariants.standUps;
    final content = resources ?? HeroClips.resources();
    for (final variant in [...activityVariants, ...standVariants]) {
      variant.validate(content);
    }
    final graph = AnimationGraphDefinition(
      id: const GraphId('hero.seatedRest'),
      entryNode: sit,
      nodes: [
        PlayClip(
          id: sit,
          clipId: const ClipId('hero.sitDown'),
          transitions: [
            // Return stays pending across entry and its original final hold.
            AnimationTransition(const Completed(), sitHold),
          ],
        ),
        HoldPose(
          id: sitHold,
          poseId: PoseId.seatedNeutral,
          duration: .5,
          interruption: InterruptionPolicy.afterClip,
          transitions: [
            AnimationTransition(const ActivityReturned(), exitHold),
            AnimationTransition(const Completed(), activitySelect),
          ],
        ),
        Select(
          id: activitySelect,
          fallback: activityWait,
          choices: [for (final variant in activityVariants) variant.choice],
          transitions: [
            AnimationTransition(const ActivityReturned(), exitHold),
          ],
        ),
        HoldPose(
          id: activityWait,
          poseId: PoseId.seatedNeutral,
          transitions: [
            AnimationTransition(const ActivityReturned(), exitHold),
            AnimationTransition(const Signal(selectionChanged), activitySelect),
          ],
        ),
        for (final variant in activityVariants)
          ...variant.activityNodes(exitHold),
        HoldPose(
          id: exitHold,
          poseId: PoseId.seatedNeutral,
          duration: .3,
          transitions: [AnimationTransition(const Completed(), standSelect)],
        ),
        Select(
          id: standSelect,
          fallback: standWait,
          choices: [for (final variant in standVariants) variant.choice],
        ),
        HoldPose(
          id: standWait,
          poseId: PoseId.seatedNeutral,
          transitions: [
            AnimationTransition(const Signal(selectionChanged), standSelect),
          ],
        ),
        for (final variant in standVariants) variant.standNode(done),
        Finish(
          id: done,
          result: GraphResultId.readyToTravel,
          entryPose: const AnimationPoseContract.family(
            PoseFamilyId.standingRight,
          ),
        ),
      ],
    );
    AnimationGraphValidator(content).validate(graph);
    return graph;
  }
}
