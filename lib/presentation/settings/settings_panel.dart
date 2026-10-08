import 'package:flutter/material.dart';
import '../../app/game_controller.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key, required this.controller});
  final GameController controller;
  @override
  Widget build(BuildContext context) {
    final settings = controller.simulation.settings;
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Always on top'),
          value: settings.alwaysOnTop,
          onChanged: (v) => controller.updateSettings(topmost: v),
        ),
        const SizedBox(height: 12),
        _opacitySlider(
          label: 'Background opacity',
          value: settings.backgroundOpacity,
          onChanged: (value) => controller.updateSettings(
            backgroundOpacity: value,
            persist: false,
          ),
        ),
        _opacitySlider(
          label: 'Road opacity',
          value: settings.roadOpacity,
          onChanged: (value) =>
              controller.updateSettings(roadOpacity: value, persist: false),
        ),
        _opacitySlider(
          label: 'Overall opacity',
          value: settings.overallOpacity,
          onChanged: (value) =>
              controller.updateSettings(overallOpacity: value, persist: false),
        ),
        const Text(
          'The settings button stays visible at 0%.',
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sound'),
          subtitle: const Text('Audio integration is planned'),
          value: settings.sound,
          onChanged: (v) => controller.updateSettings(sound: v),
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
              onChanged: (v) => controller.updateSettings(fps: v),
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
            onPressed: () async {
              final reset = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset all progress?'),
                  content: const Text(
                    'Levels, currencies, upgrades, activity statistics and settings will be cleared.',
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
              if (reset == true) await controller.reset();
            },
            child: const Text('Reset save data'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: controller.close,
            child: const Text('Save & quit'),
          ),
        ),
      ],
    );
  }

  Widget _opacitySlider({
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
        onChangeEnd: (_) => controller.save(),
      ),
    ],
  );
}
