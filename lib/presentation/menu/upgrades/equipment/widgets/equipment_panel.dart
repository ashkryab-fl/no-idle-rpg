import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../cubit/equipment_cubit.dart';
import 'equipment_list.dart';

class EquipmentPanel extends StatelessWidget {
  const EquipmentPanel({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => context.read<GetIt>()<EquipmentCubit>(),
    child: const EquipmentList(),
  );
}
