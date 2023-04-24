import 'package:flutter/material.dart';
import 'package:tower_defense/widget/game/tool/building_info_panel.dart';
import 'package:tower_defense/widget/game/tool/status_panel.dart';


class LeftCol extends StatelessWidget {
  const LeftCol({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Spacer(),
        StatusPanel(),
        BuildingInfoPanel(),
        // SkillPanel(),
      ],
    );
  }
}