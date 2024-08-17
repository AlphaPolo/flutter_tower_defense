import 'package:badges/badges.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:provider/provider.dart';
import 'package:tower_defense/extension/iterable_extension.dart';
import 'package:tower_defense/model/building/obstacle_tower.dart';
import 'package:tower_defense/providers/player_provider.dart';

import '../../../manager/buildings_manager.dart';
import '../../../model/building/building_model.dart';
import '../../../providers/game_event_provider.dart';

class BuildingBottomPanel extends StatelessWidget {
  const BuildingBottomPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BuildingsManager>();
    final templates = provider.buildingTemplates;
    final entries = templates.entries.toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: entries
            .map<Widget>((entry) {
              if(entry.key.runtimeType == ObstacleTower) return createObstacleBuildingIcon(context, entry);
              return createBuildingIcon(context, entry);
            })
            .joinElement(const SizedBox(width: 16.0))
            .toList(),
      ),
    );
  }

  Widget createBuildingIcon(BuildContext context, MapEntry<BuildingModel, List<dynamic>> data) {
    return InkWell(
      onTap: () => context.read<GameEventProvider>().pushSelectedBuildingEvent(data.key),
      child: Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 2,
              blurRadius: 3,
              // offset: const Offset(0, 2), // changes position of shadow
            ),
          ],
        ),
        child: data.value.first,
      ),
    );
  }

  Widget createObstacleBuildingIcon(BuildContext context, MapEntry<BuildingModel, List<dynamic>> data) {
    return Selector<PlayerProvider, int>(
      selector: (context, vm) => vm.freeObstacleCount,
      builder: (context, value, child) {
        return Badge(
          showBadge: value > 0,
          badgeContent: Center(
            child: Text(
              value.toString(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.grey.withOpacity(0.5),
                    blurRadius: 5,
                    offset: const Offset(0, 2), // changes position of shadow
                  ),
                ],
              ),
            ),
          ),
          child: child,
        );
      },
      child: createBuildingIcon(context, data),
    );
  }
}
