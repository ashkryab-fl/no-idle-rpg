import '../../../../../core/numbers/amount.dart';
import '../../../../../domain/equipment/equipment.dart';
import '../../../../../domain/equipment/equipment_purchase.dart';
import '../../../../../app/session/session_cubit.dart';

class EquipmentItemState {
  const EquipmentItemState(this.definition, this.level, this.quote);
  final EquipmentDefinition definition;
  final int level;
  final EquipmentQuote quote;
}

class EquipmentState {
  EquipmentState.fromSession(SessionCubit session, this.count)
    : gold = session.simulation.character.gold,
      items = List.unmodifiable([
        for (final definition in EquipmentCatalog.items)
          EquipmentItemState(
            definition,
            session.simulation.character.equipment[definition.id] ?? 0,
            session.simulation.purchases.quote(
              session.simulation.character,
              definition.id,
              count: count,
            ),
          ),
      ]);
  final int? count;
  final Amount gold;
  final List<EquipmentItemState> items;
}
