import '../../../../core/balance/progression_balance.dart';
import '../../../../core/numbers/number_formatter.dart';
import '../../../../core/numbers/amount.dart';
import '../../../../app/session/session_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../../../app/session/session_updates_service.dart';
import 'statistics_state.dart';
export 'statistics_state.dart';

@injectable
class StatisticsCubit extends Cubit<StatisticsState> {
  StatisticsCubit(this.session, this.updates) : super(_snapshot(session));
  final SessionCubit session;
  final SessionUpdatesService updates;

  @postConstruct
  void subscribeToSession() => updates.subscribe(this, refresh);

  void refresh() {
    if (!isClosed) emit(_snapshot(session));
  }

  static StatisticsState _snapshot(SessionCubit session) {
    final game = session.simulation, stats = game.stats;
    final activity = game.activity;
    String number(Amount value) => NumberFormatter.amount(value);
    return StatisticsState({
      'Gold': number(game.character.gold),
      'Knowledge Books': number(game.character.books),
      'Stage': '${game.stage}',
      'Wave':
          '${game.wave}/${ProgressionBalance.enemiesPerStage}${game.isBossWave ? ' · Boss' : ''}',
      'DPS': number(stats.dps.scale(game.dpsMultiplier)),
      'Damage': number(stats.damage),
      'Crit chance': '${NumberFormatter.decimal(stats.critChance * 100)}%',
      'Crit damage': '${NumberFormatter.decimal(stats.critDamage)}×',
      'HP / max HP': '${number(game.heroHp)} / ${number(stats.maxHp)}',
      'Distance traveled': '${NumberFormatter.decimal(game.distance)} m',
      'Enemies killed': '${game.kills}',
      'Active today': NumberFormatter.duration(activity.today.activeSeconds),
      'Idle today': NumberFormatter.duration(activity.today.idleSeconds),
      'Average active session': NumberFormatter.duration(
        activity.today.averageActive,
      ),
      'Average idle session': NumberFormatter.duration(
        activity.today.averageIdle,
      ),
      'Total active': NumberFormatter.duration(activity.total.activeSeconds),
      'Total idle': NumberFormatter.duration(activity.total.idleSeconds),
    });
  }
}
