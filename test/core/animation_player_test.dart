import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/animation/animation_clip.dart';
import 'package:idle_companion/core/animation/animation_player.dart';
import 'package:idle_companion/core/animation/ids.dart';
import 'package:idle_companion/content/animations/animation_resources.dart';

AnimationClipDefinition clip(
  List<double> durations, {
  AnimationLoopRange? loop,
  List<AnimationMarker> markers = const [],
}) => AnimationClipDefinition(
  id: const ClipId('test'),
  frames: [
    for (var i = 0; i < durations.length; i++)
      ClipFrameDefinition(FrameId('frame.$i'), durations[i]),
  ],
  loopRange: loop,
  markers: markers,
);

void main() {
  test('30/60 FPS and x1/x5/x20 match a single large update', () {
    final definition = clip(
      [.2, .1, .3],
      loop: const AnimationLoopRange(1, 3),
      markers: const [
        AnimationMarker(id: 'intro', time: .1),
        AnimationMarker(
          id: 'damage',
          time: .35,
          kind: AnimationMarkerKind.damage,
        ),
        AnimationMarker(id: 'end', time: .6),
      ],
    );
    final reference = AnimationPlayer(definition);
    final expected = reference.advance(12).events;
    for (final fps in [30, 60]) {
      for (final speed in [1, 5, 20]) {
        final player = AnimationPlayer(definition);
        final events = <AnimationMarkerEvent>[];
        final steps = 12 * fps ~/ speed;
        for (var step = 0; step < steps; step++) {
          events.addAll(player.advance(speed / fps).events);
        }
        expect(
          player.snapshot.frameIndex,
          reference.snapshot.frameIndex,
          reason: '$fps FPS x$speed',
        );
        expect(player.snapshot.loopCount, reference.snapshot.loopCount);
        expect(
          player.snapshot.timelineElapsed,
          closeTo(reference.snapshot.timelineElapsed, 1e-9),
        );
        expect(
          events.map((e) => (e.marker.id, e.loopCount)),
          expected.map((e) => (e.marker.id, e.loopCount)),
        );
        for (var i = 0; i < events.length; i++) {
          expect(events[i].elapsed, closeTo(expected[i].elapsed, 1e-9));
        }
      }
    }
  });

  test('play/reset restart local time, markers and walk at frame zero', () {
    final catalog = defaultAnimationResources();
    final player = AnimationPlayer(catalog.clip(const ClipId('hero.attack')));
    final first = player.advance(.6);
    expect(first.events.single.marker.kind, AnimationMarkerKind.damage);
    expect(first.events.single.elapsed, .35);
    player.reset();
    expect(player.snapshot.elapsed, 0);
    expect(player.snapshot.completed, false);
    expect(player.advance(.6).events.single.elapsed, .35);
    player.play(catalog.clip(const ClipId('hero.sharpen')));
    player.advance(23.7);
    player.play(catalog.clip(const ClipId('hero.walk')));
    expect(player.snapshot.frameIndex, 0);
    expect(player.snapshot.loopCount, 0);
    expect(player.snapshot.elapsed, 0);
    expect(player.advance(.1).events, isEmpty);
    expect(player.snapshot.frameIndex, 0);
  });
}
