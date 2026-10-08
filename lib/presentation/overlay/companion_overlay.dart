import 'dart:io';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/game_controller.dart';
import '../../core/balance/game_balance.dart';
import '../../core/numbers/number_formatter.dart';
import '../../domain/progression/infinite_upgrade.dart';
import '../equipment/equipment_panel.dart';
import '../settings/settings_panel.dart';
import '../statistics/statistics_panel.dart';
import '../upgrades/upgrade_list.dart';
import 'debug_panel.dart';

class CompanionOverlay extends ConsumerStatefulWidget {
  const CompanionOverlay({super.key});
  @override
  ConsumerState<CompanionOverlay> createState() => _CompanionOverlayState();
}

class _CompanionOverlayState extends ConsumerState<CompanionOverlay>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(gameControllerProvider.notifier).save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final game = controller.simulation;
    return Scaffold(
      backgroundColor: Platform.isWindows
          ? const Color(0xff010101)
          : Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: GameBalance.viewportHeight,
              child: GameWidget(game: controller.game),
            ),
            Positioned(
              bottom: 0,
              left: 68,
              width: 72,
              height: GameBalance.heroHitboxHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => controller.show(
                  ui.panel == null ? OverlayPanel.menu : null,
                ),
              ),
            ),
            Positioned(
              bottom: 144,
              right: 8,
              width: 38,
              height: 38,
              child: IconButton.filledTonal(
                tooltip: 'Open companion menu',
                onPressed: () => controller.show(
                  ui.panel == null ? OverlayPanel.menu : null,
                ),
                icon: const Icon(Icons.more_horiz),
              ),
            ),
            Positioned(
              bottom: GameBalance.viewportHeight - 26,
              left: 14,
              right: 56,
              child: IgnorePointer(
                child: Row(
                  children: [
                    Text(
                      'Lv ${game.character.level}  ·  ${game.phase.name}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                        backgroundColor: Color(0x99101720),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${NumberFormatter.amount(game.character.gold)} G · ${NumberFormatter.amount(game.character.books)} B',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xffffd58a),
                        backgroundColor: Color(0x99101720),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (ui.panel != null)
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                bottom: 194,
                child: Material(
                  color: const Color(0xee151c2b),
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
                        child: Row(
                          children: [
                            if (ui.panel != OverlayPanel.menu)
                              IconButton(
                                onPressed: () =>
                                    controller.show(OverlayPanel.menu),
                                icon: const Icon(Icons.arrow_back, size: 18),
                              ),
                            Expanded(
                              child: Text(
                                _title(ui.panel!),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => controller.show(null),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ],
                        ),
                      ),
                      if (ui.error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ui.error!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.orangeAccent,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: controller.dismissError,
                                icon: const Icon(Icons.close, size: 14),
                              ),
                            ],
                          ),
                        ),
                      const Divider(height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _panel(ui.panel!, controller),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _title(OverlayPanel panel) => switch (panel) {
    OverlayPanel.menu => 'Idle Companion',
    OverlayPanel.statistics => 'Statistics',
    OverlayPanel.upgrades => 'Character Upgrades',
    OverlayPanel.equipment => 'Equipment',
    OverlayPanel.settings => 'Settings',
    OverlayPanel.debug => 'Debug Tools',
  };
  Widget _panel(
    OverlayPanel panel,
    GameController controller,
  ) => switch (panel) {
    OverlayPanel.menu => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'A small adventure while you work.',
          style: TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 14),
        for (final destination in OverlayPanel.values.where(
          (v) =>
              v != OverlayPanel.menu && (v != OverlayPanel.debug || kDebugMode),
        ))
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            visualDensity: VisualDensity.compact,
            title: Text(_title(destination)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => controller.show(destination),
          ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Exit'),
          trailing: const Icon(Icons.exit_to_app),
          onTap: controller.close,
        ),
        const SizedBox(height: 8),
        Text(
          'User idle: ${NumberFormatter.duration(ref.read(gameControllerProvider).idleSeconds)}',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    ),
    OverlayPanel.statistics => StatisticsPanel(controller: controller),
    OverlayPanel.upgrades => UpgradeList(
      controller: controller,
      definitions: UpgradeCatalog.character,
      equipment: false,
    ),
    OverlayPanel.equipment => EquipmentPanel(controller: controller),
    OverlayPanel.settings => SettingsPanel(controller: controller),
    OverlayPanel.debug => DebugPanel(controller: controller),
  };
}
