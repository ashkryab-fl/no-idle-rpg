import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/balance/game_balance.dart';
import 'package:idle_companion/core/persistence/game_save.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/game/systems/game_state_machine.dart';

class ConstantRandom implements Random {
  ConstantRandom([this.value = .99]);
  final double value;
  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => (value * max).floor();
  @override
  bool nextBool() => value < .5;
}

void until(GameSimulation g, bool Function() done) {
  for (var i = 0; !done() && i < 10000; i++) {
    g.advance(GameBalance.fixedStep);
  }
  expect(done(), isTrue);
}

GameSimulation restart(GameSimulation g) => GameSave.fromJson(
  jsonDecode(jsonEncode(GameSave.capture(g, DateTime.now()).toJson())),
).restoreSimulation();
void forcedClear(GameSimulation g) {
  for (var i = 0; i < 5; i++) {
    g.spawnEnemy();
    g.killEnemy();
    until(g, () => g.phase == GamePhase.reward);
    if (i < 4) until(g, () => g.phase == GamePhase.traveling);
  }
}
