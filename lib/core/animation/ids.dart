/// IDs compare by namespace and stable value, including in mixed debug maps.
sealed class AnimationId {
  const AnimationId(this.value);
  final String value;
  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is AnimationId &&
      other.value == value;
  @override
  int get hashCode => Object.hash(runtimeType, value);
  @override
  String toString() => value;
}

final class ClipId extends AnimationId {
  const ClipId(super.value);
}

final class FrameId extends AnimationId {
  const FrameId(super.value);
}

final class RigId extends AnimationId {
  const RigId(super.value);
}

final class NodeId extends AnimationId {
  const NodeId(super.value);
}

final class VariantId extends AnimationId {
  const VariantId(super.value);
}

final class CooldownKey extends AnimationId {
  const CooldownKey(super.value);
}

final class GraphFactId extends AnimationId {
  const GraphFactId(super.value);
}

final class GraphSignalId extends AnimationId {
  const GraphSignalId(super.value);
  static const activityReturned = GraphSignalId('activityReturned');
}

final class GraphResultId extends AnimationId {
  const GraphResultId(super.value);
  static const readyToTravel = GraphResultId('readyToTravel');
}

final class GraphId extends AnimationId {
  const GraphId(super.value);
}

final class PoseFamilyId extends AnimationId {
  const PoseFamilyId(super.value);
  static const seated = PoseFamilyId('seatedNeutral');
  static const standingRight = PoseFamilyId('standingRight');
  static const walkingRight = PoseFamilyId('walkingRight');
}

final class PoseId extends AnimationId {
  const PoseId(super.value);
  static const seatedNeutral = PoseId('hero.seatedNeutral');
}

void validateAnimationId(String value) {
  if (value.trim().isEmpty) throw ArgumentError('Empty animation resource ID');
}
