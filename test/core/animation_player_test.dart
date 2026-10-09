import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/animation/animation_clip.dart';
import 'package:idle_companion/core/animation/animation_player.dart';
import 'package:idle_companion/core/animation/ids.dart';
import 'package:idle_companion/core/assets/animation_catalog.dart';

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
  test('unequal durations, damage crossing, completion and unspent time', () {
    final player = AnimationPlayer(
      clip(
        [.1, .5, .2],
        markers: const [
          AnimationMarker(
            id: 'damage',
            time: .35,
            kind: AnimationMarkerKind.damage,
          ),
          AnimationMarker(id: 'end', time: .8),
        ],
      ),
    );
    expect(player.snapshot.frameIndex, 0);
    expect(player.advance(.1).events, isEmpty);
    expect(player.snapshot.frameIndex, 1);
    final crossing = player.advance(.55);
    expect(crossing.events.single.marker.kind, AnimationMarkerKind.damage);
    expect(crossing.events.single.timeWithinStep, closeTo(.25, 1e-10));
    expect(player.snapshot.frameIndex, 2);
    expect(player.snapshot.completed, false);
    final end = player.advance(.4);
    expect(end.completedNow, true);
    expect(end.consumed, closeTo(.15, 1e-10));
    expect(end.remaining, closeTo(.25, 1e-10));
    expect(end.events.single.marker.id, 'end');
    expect(player.snapshot.elapsed, closeTo(.8, 1e-10));
    final held = player.advance(20);
    expect(held.remaining, 20);
    expect(held.completedNow, false);
    expect(held.events, isEmpty);
    expect(player.snapshot.frameIndex, 2);
  });

  test('large dt emits every cycle marker and never repeats intro', () {
    final player = AnimationPlayer(
      clip(
        [.2, .1, .3],
        loop: const AnimationLoopRange(1, 3),
        markers: const [
          AnimationMarker(id: 'start', time: 0),
          AnimationMarker(id: 'intro', time: .1),
          AnimationMarker(id: 'loopStart', time: .2),
          AnimationMarker(id: 'middle', time: .35),
          AnimationMarker(id: 'loopEnd', time: .6),
        ],
      ),
    );
    expect(player.advance(0).events, isEmpty);
    final result = player.advance(2.2);
    List<AnimationMarkerEvent> events(String id) =>
        result.events.where((event) => event.marker.id == id).toList();
    expect(events('start'), hasLength(1));
    expect(events('intro'), hasLength(1));
    expect(events('loopStart'), hasLength(6));
    expect(events('middle'), hasLength(5));
    expect(events('loopEnd'), hasLength(5));
    expect(player.snapshot.loopCount, 5);
    expect(player.snapshot.frameIndex, 1);
    expect(player.snapshot.completed, false);
    expect(result.remaining, 0);
    final next = player.advance(.01);
    expect(next.events, isEmpty, reason: 'Boundary events cannot fire twice');
    expect(
      result.events.map((e) => e.elapsed).toList(),
      orderedEquals(result.events.map((e) => e.elapsed).toList()..sort()),
    );
  });

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

  test('a bounded loop uses its end boundary rather than trailing frames', () {
    final player = AnimationPlayer(
      clip([.2, .1, .3, .8], loop: const AnimationLoopRange(1, 3)),
    );
    player.advance(.6);
    expect(player.snapshot.frameIndex, 1);
    player.advance(.1);
    expect(player.snapshot.frameIndex, 2);
    player.advance(.3);
    expect(player.snapshot.frameIndex, 1);
  });

  test('play/reset restart local time, markers and walk at frame zero', () {
    final catalog = AnimationCatalog();
    final player = AnimationPlayer(catalog.get('hero.attack').clip);
    final first = player.advance(.6);
    expect(first.events.single.marker.kind, AnimationMarkerKind.damage);
    expect(first.events.single.elapsed, .35);
    player.reset();
    expect(player.snapshot.elapsed, 0);
    expect(player.snapshot.completed, false);
    expect(player.advance(.6).events.single.elapsed, .35);
    player.play(catalog.get('hero.sharpen').clip);
    player.advance(23.7);
    player.play(catalog.get('hero.walk').clip);
    expect(player.snapshot.frameIndex, 0);
    expect(player.snapshot.loopCount, 0);
    expect(player.snapshot.elapsed, 0);
    expect(player.advance(.1).events, isEmpty);
    expect(player.snapshot.frameIndex, 0);
  });

  test('invalid dt is rejected without changing playback', () {
    final player = AnimationPlayer(clip([.2]));
    for (final dt in [-1.0, double.nan, double.infinity]) {
      expect(() => player.advance(dt), throwsArgumentError);
      expect(player.elapsed, 0);
    }
  });

  test(
    'short frames retain their timeline and near-zero markers fire once',
    () {
      final short = AnimationPlayer(
        clip(
          [1e-12, 2e-12],
          loop: const AnimationLoopRange(0, 2),
          markers: const [AnimationMarker(id: 'tiny', time: 5e-13)],
        ),
      );
      expect(short.snapshot.frameIndex, 0);
      expect(short.advance(1e-12).events.single.elapsed, 5e-13);
      expect(short.snapshot.frameIndex, 1);
      expect(short.advance(2e-12).events, isEmpty);
      expect(short.snapshot.frameIndex, 0);
      expect(short.snapshot.loopCount, 1);
      expect(
        short.advance(1e-12).events.single.elapsed,
        closeTo(3.5e-12, 1e-20),
      );
      final nearZero = AnimationPlayer(
        clip(
          [.5],
          markers: const [AnimationMarker(id: 'nearZero', time: 5e-11)],
        ),
      );
      expect(nearZero.advance(.1).events.single.marker.id, 'nearZero');
      expect(nearZero.advance(.1).events, isEmpty);
    },
  );
}
