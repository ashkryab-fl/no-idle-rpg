import 'package:flutter/material.dart';
import '../../app/game_controller.dart';
import 'equipment_list.dart';

class EquipmentPanel extends StatelessWidget {
  const EquipmentPanel({super.key, required this.controller});
  final GameController controller;
  @override
  Widget build(BuildContext context) => EquipmentList(controller: controller);
}
