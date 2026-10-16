import 'dart:async';
import 'dart:math';
import '../../../../game/systems/game_state_machine.dart';
import '../../../../app/session/session_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../../../app/session/session_updates_service.dart';
import '../../../../l10n/hero_break_lines.dart';
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
       _breakRevision = session.simulation.breakReminder.revision,
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
  int _breakRevision;
  final List<int> _breakLineBag = [];
  int? _lastBreakLine;
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
    final breakRevision = game.breakReminder.revision;
    final breakChanged = breakRevision != _breakRevision;
    _breakRevision = breakRevision;
    final visible =
        !game.isResting &&
        !game.heroAnimations.isPreviewing &&
        game.phase != GamePhase.heroDeath &&
        game.phase != GamePhase.respawn &&
        game.settings.overallOpacity > 0;
    if (!visible) {
      _dismissTimer?.cancel();
      if (state.lineIndex != null) emit(const HeroReturnSpeechState());
    } else if (changed && lineCount > 0) {
      _show(HeroReturnSpeechState(lineIndex: _random.nextInt(lineCount)));
    } else if (breakChanged) {
      if (_breakLineBag.isEmpty) {
        _breakLineBag.addAll(List.generate(heroBreakLineCount, (i) => i));
        _breakLineBag.shuffle(_random);
        if (_breakLineBag.last == _lastBreakLine) {
          final first = _breakLineBag.first;
          _breakLineBag[0] = _breakLineBag.last;
          _breakLineBag[_breakLineBag.length - 1] = first;
        }
      }
      _lastBreakLine = _breakLineBag.removeLast();
      _show(
        HeroReturnSpeechState(
          lineIndex: _lastBreakLine,
          kind: HeroSpeechKind.breakReminder,
        ),
      );
    }
  }

  void _show(HeroReturnSpeechState speech) {
    _dismissTimer?.cancel();
    emit(speech);
    _dismissTimer = Timer(dismissAfter, () {
      if (!isClosed) emit(const HeroReturnSpeechState());
    });
  }

  @override
  Future<void> close() async {
    _dismissTimer?.cancel();
    await super.close();
  }
}
