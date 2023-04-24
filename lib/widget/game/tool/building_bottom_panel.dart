import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tower_defense/extension/iterable_extension.dart';

import '../../../manager/buildings_manager.dart';
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
            .map<Widget>(
              (entry) => InkWell(
                onTap: () {
                  context.read<GameEventProvider>().pushSelectedBuildingEvent(entry.key);
                },
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
                  // color: Colors.redAccent,
                  child: Image(
                    image: entry.value.first,
                  ),
                  // child: Text('${entry.key.runtimeType}'),
                ),
              ),
            )
            .joinElement(const SizedBox(width: 16.0))
            .toList(),
      ),
    );
  }
}
