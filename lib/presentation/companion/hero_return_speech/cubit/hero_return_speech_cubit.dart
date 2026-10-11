import 'dart:async';
import 'dart:math';
import '../../../../game/systems/game_state_machine.dart';
import '../../../../app/session/session_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../../../app/session/session_updates_service.dart';
import 'hero_return_speech_state.dart';
export 'hero_return_speech_state.dart';

@injectable
class HeroReturnSpeechCubit extends Cubit<HeroReturnSpeechState> {
  HeroReturnSpeechCubit(
    this.session,
    this.updates, {
    required this.lineCount,
    Random? random,
    this.dismissAfter = const Duration(seconds: 4),
  }) : _random = random ?? Random(),
       _returnRevision = session.simulation.heroAnimations.restReturnRevision,
       super(const HeroReturnSpeechState());

  @factoryMethod
  static HeroReturnSpeechCubit create(
    SessionCubit session,
    SessionUpdatesService updates,
    @factoryParam int lineCount,
    @factoryParam Random? random,
  ) => HeroReturnSpeechCubit(
    session,
    updates,
    lineCount: lineCount,
    random: random,
  );

  final int lineCount;
  final Duration dismissAfter;
  // Independent RNG preserves combat, loot and rest choices.
  final Random _random;
  int _returnRevision;
  Timer? _dismissTimer;

  final SessionCubit session;
  final SessionUpdatesService updates;

  @postConstruct
  void subscribeToSession() => updates.subscribe(this, refresh);

  void refresh() {
    if (isClosed) return;
    final game = session.simulation;
    final revision = game.heroAnimations.restReturnRevision;
    final changed = revision != _returnRevision;
    _returnRevision = revision;
    final visible =
        !game.isResting &&
        game.phase != GamePhase.heroDeath &&
        game.phase != GamePhase.respawn &&
        game.settings.overallOpacity > 0;
    if (!visible) {
      _dismissTimer?.cancel();
      if (state.lineIndex != null) emit(const HeroReturnSpeechState());
    } else if (changed && lineCount > 0) {
      _dismissTimer?.cancel();
      emit(HeroReturnSpeechState(lineIndex: _random.nextInt(lineCount)));
      _dismissTimer = Timer(dismissAfter, () {
        if (!isClosed) emit(const HeroReturnSpeechState());
      });
    }
  }

  @override
  Future<void> close() async {
    _dismissTimer?.cancel();
    await super.close();
  }
}
