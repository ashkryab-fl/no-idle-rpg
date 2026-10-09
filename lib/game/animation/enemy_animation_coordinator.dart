import '../../content/animations/enemies/procedural_timelines.dart';
import '../../core/animation/animation_clip.dart';
import '../../core/animation/animation_player.dart';
import '../../core/animation/animation_resources.dart';
import '../../core/animation/attack_playback.dart';
import '../../core/animation/enemy_animation_content.dart';
import '../../core/animation/playback_snapshot.dart';

enum EnemyAnimationRequest { idle, combat, death }

final class EnemyAnimationCoordinator {
  EnemyAnimationCoordinator(this.resources)
    : combatPlayback = AttackPlayback(ProceduralEnemyTimelines.attack);
  final AnimationResources resources;
  final AttackPlayback combatPlayback;
  AnimationPlayer? _death;
  EnemyAnimationContent? _content;
  EnemyAnimationRequest _request = EnemyAnimationRequest.idle;
  int _generation = 0;
  double combatPeriod = 1;
  bool get deathCompleted => _death?.completed ?? false;

  void synchronize(
    EnemyAnimationContent? content,
    EnemyAnimationRequest request,
  ) {
    if (content != _content) {
      // Validate every declared sprite channel before switching generations.
      if (content is SpriteEnemyAnimationContent) {
        resources.clip(content.idleId);
        content.death(resources);
      }
      final attack = content?.attack(resources);
      _content = content;
      _death = null;
      combatPlayback.reset(clip: attack);
      _generation++;
      _request = EnemyAnimationRequest.idle;
    }
    if (content == null) return;
    if (request == _request) return;
    _generation++;
    _request = request;
    switch (request) {
      case EnemyAnimationRequest.death:
        _death = AnimationPlayer(content.death(resources));
      case EnemyAnimationRequest.combat:
        combatPlayback.reset();
      case EnemyAnimationRequest.idle:
        _death = null;
    }
  }

  void advance(double dt) {
    if (!dt.isFinite || dt < 0) throw ArgumentError.value(dt, 'dt');
    if (_request == EnemyAnimationRequest.death) _death!.advance(dt);
  }

  PlaybackSnapshot? get snapshot {
    final content = _content;
    if (content == null) return null;
    final attacking =
        _request == EnemyAnimationRequest.combat &&
        combatPlayback.attacking(combatPeriod);
    final AnimationClipDefinition? clip =
        _request == EnemyAnimationRequest.death
        ? _death!.clip
        : attacking
        ? combatPlayback.clip
        : content is SpriteEnemyAnimationContent
        ? resources.clip(content.idleId)
        : null;
    final elapsed = _request == EnemyAnimationRequest.death
        ? _death!.elapsed
        : attacking
        ? combatPlayback.clipElapsed(combatPeriod)
        : 0.0;
    final pose = _request == EnemyAnimationRequest.death
        ? ProceduralPose.fallen
        : attacking
        ? ProceduralPose.striking
        : ProceduralPose.standing;
    final label = clip?.id.value ?? 'canvas.enemy.idle';
    if (content is SpriteEnemyAnimationContent) {
      return PlaybackSnapshot.atClip(
        resources,
        clip!.id,
        elapsed,
        generation: _generation,
        displayLabel: label,
        pose: pose,
      );
    }
    return PlaybackSnapshot(
      clipId: clip?.id,
      elapsed: elapsed,
      duration: clip?.duration ?? 0,
      displayLabel: label,
      generation: _generation,
      completed: _death?.completed ?? false,
      proceduralPose: pose,
    );
  }

  void reset() {
    _content = null;
    _death = null;
    combatPlayback.reset();
    _request = EnemyAnimationRequest.idle;
    _generation++;
  }
}
