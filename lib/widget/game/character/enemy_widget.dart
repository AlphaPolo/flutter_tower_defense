import 'package:flutter/material.dart';
import 'package:tower_defense/model/enemy/enemy.dart';
import 'package:tower_defense/widget/game/tool/status_panel.dart';

class EnemyWidget extends StatelessWidget {
  const EnemyWidget(this.data, {super.key});
  final Enemy data;

  @override
  Widget build(BuildContext context) {
    // print('enemy rebuild: ${data.status.currentHp}/${data.status.totalHp}');
    return Container(
      decoration: const BoxDecoration(
        color: Colors.indigo,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      child: SizedOverflowBox(
        size: Size.zero,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 20,
          height: 5,
          child: buildStatusBar(),
        ),
      ),
    );
  }

  Container buildStatusBar() {
    return Container(
      color: Colors.grey,
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(color: Colors.red, border: Border.all(color: Colors.redAccent)),
        child: FractionallySizedBox(
          widthFactor: data.status.currentHp / data.status.totalHp,
          heightFactor: 1,
        ),
      ),
    );
  }
}
