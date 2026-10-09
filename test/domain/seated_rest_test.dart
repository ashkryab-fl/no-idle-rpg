import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/content/animations/hero/rest_graphs.dart';
import 'package:idle_companion/core/animation/graph/graph_runner.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';

void main() {
  test('default rest uses the graph; death/reset discard pending playback', () {
    final game = GameSimulation(random: Random(1));
    game.idle.setIdleSeconds(30);
    game.advance(.4);
    final oldRunner = game.idle.graphRunner!;
    expect(oldRunner.snapshot.nodeId, HeroRestGraphs.sit);
    game.idle.setIdleSeconds(0);
    game.killHero();
    expect(oldRunner.snapshot.status, GraphPlaybackStatus.cancelled);
    expect(game.idle.graphRunner, isNull);
    game.advance(3);
    expect(game.heroPlayback.displayLabel, 'hero.walk');
    game.idle.setIdleSeconds(30);
    game.advance(.4);
    final resetRunner = game.idle.graphRunner!;
    game.resetEncounter();
    expect(resetRunner.snapshot.status, GraphPlaybackStatus.cancelled);
    expect(game.idle.graphRunner, isNull);
    game.advance(.1);
    expect(game.idle.graphRunner!.snapshot.nodeId, HeroRestGraphs.sit);
  });
}
