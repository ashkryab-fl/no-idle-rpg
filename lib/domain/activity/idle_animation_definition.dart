import 'idle_level.dart';

class IdleAnimationDefinition {
  const IdleAnimationDefinition({
    required this.id,
    required this.requiredIdleLevel,
    this.weight = 1,
    this.nextAnimationId,
    this.nextAnimationIds = const [],
    this.canInterrupt = true,
    this.minLoops = 1,
    this.maxLoops = 1,
    this.cooldown = 0,
    this.holdLastFrame = 0,
    this.loopUntilActivity = false,
    this.exitAnimationIds = const [],
  });
  final String id;
  final IdleLevel requiredIdleLevel;
  final double weight, cooldown, holdLastFrame;
  final String? nextAnimationId;
  final List<String> nextAnimationIds;

  /// Separate return clips, played once even if inactivity resumes mid-exit.
  final List<String> exitAnimationIds;
  final bool canInterrupt, loopUntilActivity;
  final int minLoops, maxLoops;
  List<String> get continuations => [?nextAnimationId, ...nextAnimationIds];
}

abstract final class IdleAnimationCatalog {
  static const seatedExit = ['hero.seated', 'hero.standUp'];
  // Add seated activities to this root's continuations. Child weights control
  // the random choice; children never enter the lottery before sitting down.
  static const definitions = [
    IdleAnimationDefinition(
      id: 'hero.sitDown',
      requiredIdleLevel: IdleLevel.level1,
      nextAnimationIds: ['hero.sharpen'],
      canInterrupt: false,
      holdLastFrame: .5,
      exitAnimationIds: seatedExit,
    ),
    IdleAnimationDefinition(
      id: 'hero.sharpen',
      requiredIdleLevel: IdleLevel.level1,
      loopUntilActivity: true,
      exitAnimationIds: seatedExit,
    ),
  ];
}
