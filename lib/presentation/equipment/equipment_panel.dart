import 'package:flutter/material.dart';
import '../../app/game_controller.dart';
import '../../domain/equipment/equipment.dart';
import '../upgrades/upgrade_list.dart';

class EquipmentPanel extends StatelessWidget {
  const EquipmentPanel({super.key, required this.controller});
  final GameController controller;
  @override
  Widget build(BuildContext context) => UpgradeList(
    controller: controller,
    definitions: EquipmentCatalog.items,
    equipment: true,
  );
}
