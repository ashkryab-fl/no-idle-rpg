// Preview sequences use runtime frames, rigs and clip durations directly.
import 'dart:convert';
import 'dart:io';
import 'package:idle_companion/content/animations/animation_resources.dart';
import 'package:idle_companion/core/animation/ids.dart';

void main() {
  final resources = defaultAnimationResources();
  Map<String, Object> step(String id, int index, [double? hold]) {
    final clipFrame = resources.clip(ClipId('hero.$id')).frames[index];
    final frame = resources.frame(clipFrame.frameId);
    final rig = resources.rig(frame.rigId);
    final rect = frame.source;
    return {
      'asset': frame.asset!,
      'crop': [
        rect.x.toInt(),
        rect.y.toInt(),
        rect.width.toInt(),
        rect.height.toInt(),
      ],
      'rig': {
        'anchor': [rig.anchorX, rig.anchorY],
        'worldUnitsPerPixel': rig.worldUnitsPerPixel,
        'scaleMultiplier': frame.scaleMultiplier,
      },
      'duration': hold ?? clipFrame.duration,
    };
  }

  List<Map<String, Object>> clip(String id, {bool loopOnly = false}) {
    final clip = resources.clip(ClipId('hero.$id'));
    return [
      for (
        var i = loopOnly ? clip.loopRange!.start : 0;
        i < (loopOnly ? clip.loopRange!.end : clip.frames.length);
        i++
      )
        step(id, i),
    ];
  }

  final previews = <Map<String, Object>>[];
  void preview(
    String folder,
    String name,
    List<Map<String, Object>> sequence, {
    bool contact = false,
  }) {
    final prefix = 'build/animation_previews/hero/$folder/$name';
    previews.add({
      'group': 'build/animation_previews/hero/$folder',
      'output': '$prefix-preview.gif',
      if (contact) 'contactSheet': '$prefix-contact.png',
      'canvas': [512, 512],
      'rig': step('seated', 0)['rig']!,
      'sequence': sequence,
    });
  }

  final walk = clip('walk');
  final stand = clip('standUp');
  final neutral = step('seated', 0, .3);
  preview('phone_v1', 'entry', clip('phoneEnter'));
  preview('phone_v1', 'scroll', clip('phoneScroll', loopOnly: true));
  preview('phone_v1', 'wake', clip('phoneWake'));
  preview('phone_v1', 'walk-phone-walk', [
    ...walk,
    ...clip('phoneEnter'),
    ...clip('phoneScroll'),
    ...clip('phoneWake'),
    ...walk,
  ]);
  final sit = [
    for (var i = 0; i < 4; i++) step('sitDown', i, i == 3 ? .8 : .3),
  ];
  // Attack uses runtime timing; death retains longer review holds.
  preview('walk_v2', 'walk', walk);
  preview('attack_v1', 'attack', clip('attack'));
  preview('death_v1', 'death', [
    for (var i = 0; i < 4; i++) step('death', i, i == 3 ? 1 : .4),
  ]);
  preview('sit_down_v1', 'sit-down', sit);
  preview(
    'sharpen_v1',
    'sharpen',
    clip('sharpen', loopOnly: true),
    contact: true,
  );
  preview('sharpen_v1', '../sit_down_v1/rest', [
    ...sit,
    ...clip('sharpen'),
    ...clip('sharpen', loopOnly: true),
    ...clip('sharpen', loopOnly: true),
  ]);
  preview('stand_up_v1', 'stand-up', stand);
  preview('read_v1', 'read', clip('read', loopOnly: true), contact: true);
  preview('read_v1', 'rest-reading', [
    ...sit,
    ...clip('read'),
    ...clip('read', loopOnly: true),
    ...clip('readCleanup'),
    neutral,
    ...stand,
    walk.first,
  ], contact: true);
  preview('stand_up_v1', 'wake-to-walk', [
    step('sharpen', 7),
    neutral,
    ...stand,
    ...walk,
  ], contact: true);
  stdout.write(jsonEncode(previews));
}
