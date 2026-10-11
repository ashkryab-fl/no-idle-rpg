import 'dart:async';
import '../../../../../app/session/session_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../../../../app/session/session_updates_service.dart';
import 'equipment_state.dart';
export 'equipment_state.dart';

@injectable
class EquipmentCubit extends Cubit<EquipmentState> {
  EquipmentCubit(this.session, this.updates)
    : super(EquipmentState.fromSession(session, 1));

  final SessionCubit session;
  final SessionUpdatesService updates;

  @postConstruct
  void subscribeToSession() => updates.subscribe(this, refresh);

  void refresh() {
    if (!isClosed) emit(EquipmentState.fromSession(session, state.count));
  }

  void selectCount(int? count) {
    if (isClosed) return;
    if (count != null && count != 1 && count != 10) return;
    emit(EquipmentState.fromSession(session, count));
  }

  void purchase(String id) {
    if (!session.canMutate || isClosed) return;
    if (session.simulation.purchaseEquipment(id, count: state.count) == 0) {
      return;
    }
    refresh();
    session.refresh();
    unawaited(session.save());
  }
}
