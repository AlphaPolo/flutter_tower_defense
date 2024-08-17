import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tower_defense/providers/player_provider.dart';
import 'package:tower_defense/widget/game/tool/building_info_panel.dart';
import 'package:tower_defense/widget/game/tool/status_panel.dart';

import '../../../manager/game_manager.dart';


class LeftCol extends StatelessWidget {
  const LeftCol({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        buildCheatSwitch(),
        const StatusPanel(),
        const BuildingInfoPanel(),
        buildStartBtn(context),
        // SkillPanel(),
      ],
    );
  }

  Widget buildCheatSwitch() {
    return Selector<PlayerProvider, bool>(
      selector: (context, player) => player.cheatMode,
      builder: (context, cheatMode, _) {
        return Row(
          children: [
            CupertinoSwitch(
              value: cheatMode,
              onChanged: (bool value) {
                context.read<PlayerProvider>().toggleCheat();
              },
            ),
            Text('作弊模式',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cheatMode ? Colors.greenAccent : Colors.grey[400],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget buildStartBtn(BuildContext context) {
    return IconButton(
      onPressed: () {
        context.read<GameManager>().start();
      },
      icon: const Icon(Icons.play_circle),
    );
  }
}