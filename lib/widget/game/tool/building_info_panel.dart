import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tower_defense/extension/duration_extension.dart';
import 'package:tower_defense/model/building/building_model.dart';
import 'package:tower_defense/providers/player_provider.dart';
import 'package:tower_defense/widget/animated/animated_shrink_size.dart';

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
          secondChild: content(model),
          // switchInCurve: Curves.easeInOutCubicEmphasized,
        );
      },
    );
  }

  Widget content(BuildingModel? model) {
    if(model == null) return Container(width: 0, height: 0);
    return Container(
      // duration: 300.ms,
      // curve: Curves.easeInOutCubicEmphasized,
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(12),
      constraints: BoxConstraints(
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
          const Placeholder(
            fallbackHeight: 50,
            fallbackWidth: 50,
          ),
          const SizedBox(height: 16.0),
          Text(model.runtimeType.toString()),
        ],
      ),
    );
  }
}
