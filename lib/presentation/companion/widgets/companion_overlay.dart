import 'dart:math' as math;
import 'dart:io';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/session/session_cubit.dart';
import '../cubit/overlay_cubit.dart';
import '../../menu/widgets/menu_panel.dart';
import '../../../core/balance/game_balance.dart';
import '../../../core/balance/progression_balance.dart';
import '../../menu/upgrades/equipment/widgets/equipment_panel.dart';
import '../../menu/upgrades/talents/widgets/talents_panel.dart';
import '../../menu/settings/widgets/settings_panel.dart';
import '../../menu/statistics/widgets/statistics_panel.dart';
import '../../menu/debug/widgets/debug_panel.dart';
import 'hero_health_bar.dart';
import '../hero_return_speech/widgets/hero_return_speech.dart';

class CompanionOverlay extends StatelessWidget {
  const CompanionOverlay({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<OverlayCubit, CompanionOverlayState>(
    builder: (context, ui) {
      final cubit = context.read<OverlayCubit>();
      final session = context.read<SessionCubit>();
      return Scaffold(
        backgroundColor: Platform.isWindows
            ? const Color(0xff010101)
            : Colors.transparent,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final sceneScale = math.min(
              ui.windowScale,
              math.min(
                constraints.maxWidth / GameBalance.viewportWidth,
                constraints.maxHeight / GameBalance.viewportHeight,
              ),
            );
            final sceneHeight = GameBalance.viewportHeight * sceneScale;
            final sceneWidth = GameBalance.viewportWidth * sceneScale;
            final speechScale = math.max(1.0, sceneScale);
            final panelHeight = math.min(418.0, constraints.maxHeight - 16);
            final panelBottom = math.min(
              194.0,
              math.max(8.0, constraints.maxHeight - panelHeight - 8),
            );
            return Stack(
              children: [
                Positioned(
                  right: 0,
                  bottom: 0,
                  width: sceneWidth,
                  height: sceneHeight,
                  child: FittedBox(
                    child: SizedBox(
                      width: GameBalance.viewportWidth,
                      height: GameBalance.viewportHeight,
                      child: Stack(
                        children: [
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: GameBalance.viewportHeight,
                            child: Opacity(
                              key: const ValueKey('gameOpacity'),
                              opacity: ui.overallOpacity,
                              child: IgnorePointer(
                                child: GameWidget(game: session.game),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 112 * sceneScale,
                  right: 54 * sceneScale,
                  width: (GameBalance.viewportWidth - 110 - 54) * speechScale,
                  child: Opacity(
                    opacity: ui.overallOpacity,
                    child: const FittedBox(
                      alignment: Alignment.bottomRight,
                      child: SizedBox(
                        width: GameBalance.viewportWidth - 110 - 54,
                        child: HeroReturnSpeech(),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: constraints.maxHeight - sceneHeight + 8,
                  right: 8,
                  width: sceneWidth - 16,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: IgnorePointer(
                            child: Opacity(
                              key: const ValueKey('hudOpacity'),
                              opacity: ui.overallOpacity * ui.backgroundOpacity,
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  HeroHealthBar(
                                    current: ui.heroHp,
                                    maximum: ui.maxHp,
                                  ),
                                  Text(
                                    'Stage ${ui.stage} · Wave ${ui.wave}/${ProgressionBalance.enemiesPerStage}',
                                    key: const ValueKey('stageProgress'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white70,
                                      backgroundColor: Color(0x99101720),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton.filledTonal(
                          padding: EdgeInsets.zero,
                          alignment: Alignment.center,
                          style: IconButton.styleFrom(
                            minimumSize: const Size.square(28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => cubit.show(
                            ui.panel == null ? OverlayPanel.menu : null,
                          ),
                          icon: const Icon(Icons.menu, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                if (ui.panel != null)
                  Positioned(
                    right: 8,
                    width: GameBalance.viewportWidth - 16,
                    height: panelHeight,
                    bottom: panelBottom,
                    child: Material(
                      key: const ValueKey('menuPanel'),
                      color: const Color(0xff151c2b),
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
                                        cubit.show(OverlayPanel.menu),
                                    icon: const Icon(
                                      Icons.arrow_back,
                                      size: 18,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    ui.panel!.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => cubit.show(null),
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                              ],
                            ),
                          ),
                          if (ui.error != null || ui.notice != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      (ui.error ?? ui.notice)!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.orangeAccent,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: ui.error != null
                                        ? cubit.dismissError
                                        : cubit.dismissNotice,
                                    icon: const Icon(Icons.close, size: 14),
                                  ),
                                ],
                              ),
                            ),
                          const Divider(height: 1),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: _panel(ui.panel!),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    },
  );

  Widget _panel(OverlayPanel panel) => switch (panel) {
    OverlayPanel.menu => const MenuPanel(),
    OverlayPanel.statistics => const StatisticsPanel(),
    OverlayPanel.equipment => const EquipmentPanel(),
    OverlayPanel.talents => const TalentsPanel(),
    OverlayPanel.settings => const SettingsPanel(),
    OverlayPanel.debug => const DebugPanel(),
  };
}
