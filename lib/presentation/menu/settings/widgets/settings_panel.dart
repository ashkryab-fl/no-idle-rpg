import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../cubit/settings_cubit.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => context.read<GetIt>()<SettingsCubit>(),
    child: const _SettingsView(),
  );
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<SettingsCubit, SettingsState>(
    builder: (context, settings) {
      final cubit = context.read<SettingsCubit>();
      return Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Always on top'),
            value: settings.alwaysOnTop,
            onChanged: (v) => cubit.update(topmost: v),
          ),
          const SizedBox(height: 12),
          _percentageSlider(
            context: context,
            label: 'Window size',
            value: settings.windowSize,
            onChanged: (value) =>
                cubit.update(windowSize: value, persist: false),
          ),
          _percentageSlider(
            context: context,
            label: 'Background opacity',
            value: settings.backgroundOpacity,
            onChanged: (value) =>
                cubit.update(backgroundOpacity: value, persist: false),
          ),
          _percentageSlider(
            context: context,
            label: 'Road opacity',
            value: settings.roadOpacity,
            onChanged: (value) =>
                cubit.update(roadOpacity: value, persist: false),
          ),
          _percentageSlider(
            context: context,
            label: 'Overall opacity',
            value: settings.overallOpacity,
            onChanged: (value) =>
                cubit.update(overallOpacity: value, persist: false),
          ),
          const Text(
            'The menu stays visible at 0%.',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sound'),
            subtitle: const Text('Audio integration is planned'),
            value: settings.sound,
            onChanged: (v) => cubit.update(sound: v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: Text('FPS limit')),
              DropdownButton<int>(
                value: settings.fps,
                items: [15, 30, 60]
                    .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                    .toList(),
                onChanged: (v) => cubit.update(fps: v),
              ),
            ],
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Launch at startup'),
            subtitle: Text('Coming later'),
            trailing: Icon(Icons.lock_outline),
          ),
          const Divider(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: settings.busy
                  ? null
                  : () async {
                      final reset = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Reset all progress?'),
                          content: const Text(
                            'Stage progress, currencies, equipment, activity statistics and settings will be cleared.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Reset'),
                            ),
                          ],
                        ),
                      );
                      if (reset == true) await cubit.reset();
                    },
              child: const Text('Reset save data'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: settings.busy ? null : cubit.quit,
              child: const Text('Save & quit'),
            ),
          ),
        ],
      );
    },
  );

  Widget _percentageSlider({
    required BuildContext context,
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) => Column(
    children: [
      Row(
        children: [
          Expanded(child: Text(label)),
          Text('${(value * 100).round()}%'),
        ],
      ),
      Slider(
        key: ValueKey(label),
        label: '${(value * 100).round()}%',
        value: value,
        divisions: 100,
        onChanged: onChanged,
        onChangeEnd: (_) => context.read<SettingsCubit>().save(),
      ),
    ],
  );
}
