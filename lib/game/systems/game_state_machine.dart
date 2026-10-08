enum GamePhase {
  boot,
  traveling,
  enemyApproach,
  combat,
  enemyDeath,
  reward,
  heroDeath,
  respawn,
}

class GameStateMachine {
  GamePhase phase = GamePhase.boot;
  double elapsed = 0;
  static const transitions = {
    GamePhase.boot: {GamePhase.traveling},
    GamePhase.traveling: {GamePhase.enemyApproach, GamePhase.heroDeath},
    GamePhase.enemyApproach: {
      GamePhase.combat,
      GamePhase.heroDeath,
      GamePhase.enemyDeath,
    },
    GamePhase.combat: {GamePhase.enemyDeath, GamePhase.heroDeath},
    GamePhase.enemyDeath: {GamePhase.reward, GamePhase.heroDeath},
    GamePhase.reward: {GamePhase.traveling, GamePhase.heroDeath},
    GamePhase.heroDeath: {GamePhase.respawn},
    GamePhase.respawn: {GamePhase.traveling},
  };
  void transition(GamePhase next) {
    if (!transitions[phase]!.contains(next)) {
      throw StateError('Illegal transition $phase → $next');
    }
    phase = next;
    elapsed = 0;
  }
}
