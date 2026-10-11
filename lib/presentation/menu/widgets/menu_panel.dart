import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../../core/numbers/number_formatter.dart';
import '../cubit/menu_cubit.dart';

class MenuPanel extends StatelessWidget {
  const MenuPanel({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => context.read<GetIt>()<MenuCubit>(),
    child: BlocBuilder<MenuCubit, MenuState>(
      builder: (context, state) {
        final cubit = context.read<MenuCubit>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'A small adventure while you work.',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 14),
            for (final destination in state.destinations)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(destination.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => cubit.open(destination),
              ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              visualDensity: VisualDensity.compact,
              title: const Text('Exit'),
              trailing: const Icon(Icons.exit_to_app),
              onTap: cubit.quit,
            ),
            const SizedBox(height: 8),
            Text(
              'User idle: ${NumberFormatter.duration(state.idleSeconds)}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        );
      },
    ),
  );
}
