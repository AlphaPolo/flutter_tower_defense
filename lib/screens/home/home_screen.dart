import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tower_defense/extension/iterable_extension.dart';

import '../../manager/game_manager.dart';
import '../../providers/building_provider.dart';
import '../../providers/game_event_provider.dart';
import '../../providers/player_provider.dart';
import '../../widget/game/tool/left_col.dart';
import '../game/game_board.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The scene is drawn by a CustomPaint, but user interaction is handled by
    // the InteractiveViewer parent widget.
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Hexagon'),
      ),
      body: MultiProvider(
        providers: [
          Provider(create: (context) => GameEventProvider(), dispose: (context, manager) => manager.dispose(), lazy: false),
          Provider(create: (context) => GameManager(), dispose: (context, manager) => manager.dispose(), lazy: false),
          ChangeNotifierProvider(create: (context) => PlayerProvider(context)),
          Provider(create: (context) => BuildingProvider()),

        ],
        child: Container(
          color: Colors.lightBlue,
          alignment: Alignment.center,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          GameBoard(),
                          LeftCol(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              bottomCol(),
            ],
          ),
        ),
      ),
    );
  }

  IconButton get resetButton {
    return IconButton(
      tooltip: 'Reset',
      color: Theme.of(context).colorScheme.surface,
      icon: const Icon(Icons.replay),
      onPressed: () {},
    );
  }

  IconButton get editButton {
    return IconButton(
      onPressed: () {},
      tooltip: 'Edit',
      color: Theme.of(context).colorScheme.surface,
      icon: const Icon(Icons.edit),
    );
  }

  IconButton get changeStateButton {
    return IconButton(
      onPressed: () {},
      tooltip: 'MotionEdit',
      color: Theme.of(context).colorScheme.surface,
      icon: const Icon(Icons.accessibility),
    );
  }

  Widget bottomCol() {
    return Builder(builder: (context) {
      return Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  context.read<GameManager>().start();
                },
                icon: const Icon(Icons.play_circle),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 2,
                  blurRadius: 3,
                  offset: const Offset(0, 2), // changes position of shadow
                ),
              ],
            ),
            child: const BuildingListview(),
          ),
        ],
      );
    });
  }
}


class BuildingListview extends StatelessWidget {
  const BuildingListview({super.key});


  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BuildingProvider>();
    final templates = provider.buildingTemplates;
    final entries = templates.entries.toList();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: entries.map<Widget>((entry) => InkWell(
          onTap: () {
            context.read<GameEventProvider>().pushSelectedBuildingEvent(entry.key);
          },
          child: Container(
            width: 75,
            height: 75,
            color: Colors.redAccent,
            child: Text('${entry.key.runtimeType}'),
          ),
        )).joinElement(const SizedBox(width: 16.0)).toList(),
      ),
    );
  }
}
