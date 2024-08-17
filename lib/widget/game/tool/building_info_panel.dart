import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tower_defense/extension/duration_extension.dart';
import 'package:tower_defense/manager/buildings_manager.dart';
import 'package:tower_defense/model/building/building_model.dart';
import 'package:tower_defense/providers/player_provider.dart';

class BuildingInfoPanel extends StatelessWidget {
  const BuildingInfoPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerProvider, BuildingModel?>(
      selector: (context, player) => player.selectingModel,
      builder: (context, model, _) {
        return AnimatedCrossFade(
          duration: 300.ms,
          sizeCurve: Curves.easeInOutQuart,
          crossFadeState: model == null ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: const SizedBox.shrink(),
          secondChild: content(context, model),
          // switchInCurve: Curves.easeInOutCubicEmphasized,
        );
      },
    );
  }

  Widget content(BuildContext context, BuildingModel? model) {
    if(model == null) return Container(width: 0, height: 0);
    final template = context.read<BuildingsManager>().buildingTemplates[model]!;
    final [_, title, description] = template;

    return Container(
      // duration: 300.ms,
      // curve: Curves.easeInOutCubicEmphasized,
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(
        maxWidth: 150,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(8.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 3,
            offset: const Offset(0, 2), // changes position of shadow
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Transform.scale(
              scale: 1.5,
              child: SizedBox.square(
                dimension: 45,
                child: model.getRenderWidget(),
              ),
            ),
          ),
          const SizedBox(height: 16.0),
          Text(model.runtimeType.toString()),
          const SizedBox(height: 16.0),
          Text(title),
          const SizedBox(height: 16.0),
          Text(description, textAlign: TextAlign.start),
          const SizedBox(height: 16.0),
          buildTowerStuffDescription(model),
        ],
      ),
    );
  }

  Widget buildTowerStuffDescription(BuildingModel model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('花費: ${model.cost}'),
        Text('範圍: ${model.range}'),
        // Text('攻擊頻率: ${(1000 / model.fireCD)}'),
        Text('傷害: ${model.damage}'),
      ],
    );
  }
}
