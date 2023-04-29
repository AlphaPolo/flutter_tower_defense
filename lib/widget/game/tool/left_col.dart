import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
        const StatusPanel(),
        const BuildingInfoPanel(),
        buildStartBtn(context),
        // SkillPanel(),
      ],
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