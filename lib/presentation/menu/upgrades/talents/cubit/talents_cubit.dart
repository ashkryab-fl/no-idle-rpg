import 'dart:async';
import '../../../../../domain/talents/talents.dart';
import '../../../../../app/session/session_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../../../../app/session/session_updates_service.dart';
import 'talents_state.dart';
export 'talents_state.dart';

@injectable
class TalentsCubit extends Cubit<TalentsState> {
  TalentsCubit(this.session, this.updates)
    : super(TalentsState.fromSession(session, 1));
  final SessionCubit session;
  final SessionUpdatesService updates;

  @postConstruct
  void subscribeToSession() => updates.subscribe(this, refresh);

  void refresh() {
    if (!isClosed) {
      emit(
        TalentsState.fromSession(
          session,
          state.count,
          rewardsExpanded: state.rewardsExpanded,
        ),
      );
    }
  }

  void selectCount(int? count) {
    if (isClosed) return;
    if (count != null && count != 1 && count != 10) return;
    emit(
      TalentsState.fromSession(
        session,
        count,
        rewardsExpanded: state.rewardsExpanded,
      ),
    );
  }

  void setRewardsExpanded(bool expanded) {
    if (isClosed) return;
    emit(
      TalentsState.fromSession(session, state.count, rewardsExpanded: expanded),
    );
  }

  void purchase(String id) {
    if (!session.canMutate || isClosed) return;
    if (session.simulation.purchaseTalent(id, count: state.count) == 0) return;
    refresh();
    session.refresh();
    unawaited(session.save());
  }

  void select(TalentPair pair, String? id) {
    if (!session.canMutate || isClosed) return;
    session.simulation.selectTalent(pair, id);
    refresh();
    session.refresh();
    unawaited(session.save());
  }
}
