import 'package:idle_companion/domain/adventure/stage_attempt.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';

/// A coherent checkpoint for tests starting partway through a stage.
void prepareWaveFixture(GameSimulation game, int stage, int wave) {
  game.stage = stage;
  game.stageKills = wave - 1;
  game.character.talents.highestFirstClearedStage = stage - 1;
  game.activeAttempt = StageAttempt.begin(
    game.character.talents,
    stage,
    game.spawner.plan(stage),
    profile: game.talentProfile,
  );
  if (wave > 1) {
    game.character.talents.lastSettledAttempt = game.activeAttempt!.id;
    game.character.talents.lastSettledWave = wave - 1;
  }
}
