import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tower_defense/extension/duration_extension.dart';
import 'package:tuple/tuple.dart';

import '../../../providers/player_provider.dart';


class StatusPanel extends StatefulWidget {
  const StatusPanel({super.key});

  @override
  State<StatusPanel> createState() => _LeftColState();
}

class _LeftColState extends State<StatusPanel> {

  bool fold = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      margin: const EdgeInsets.all(12),
      width: 100,
      constraints: BoxConstraints(
          maxHeight: fold ? 50 : 125
      ),
      duration: 300.ms,
      curve: Curves.easeOutQuart,
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

      child: Stack(
        children: [
          closeButton(),
          buildStatus(),
        ],
      ),
    );
  }

  Positioned closeButton() {
    final child = fold ?
    IconButton(onPressed: () => setState(() => fold = false), icon: const Icon(Icons.unfold_more)) :
    IconButton(onPressed: () => setState(() => fold = true), icon: const Icon(Icons.unfold_less));

    return Positioned(
      top: 0,
      right: 0,
      child: AnimatedSwitcher(
        duration: 100.ms,
        child: SizedBox(
            key: ValueKey(fold),
            height: 50,
            child: Row(
              children: [
                const Text('狀態表'),
                child,
              ],
            )
        ),
      ),
    );
  }

  Widget buildStatus() {
    return Positioned.fill(
      top: 50,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Selector<PlayerProvider, PlayerStatus>(
              selector: (context, player) => player.status,
              builder: (context, status, _) {
                if(fold) return const SizedBox.shrink();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      const Icon(Icons.favorite),
                      const SizedBox(width: 16.0),
                      Text(status.heart.toString()),
                    ]),
                    Row(children: [
                      const Icon(Icons.attach_money),
                      const SizedBox(width: 16.0),
                      Text(status.coin.toString()),
                    ]),
                  ],
                );
              }
          ),
        ),
      ),
    );
  }
}


class StatusBar extends StatelessWidget {
  const StatusBar({
    super.key,
    this.axis = Axis.vertical,
    required this.backgroundColor,
    required this.statusColor,
    required this.totalAmount,
    required this.currentAmount,
    this.costPreview,
  });
  final Axis axis;
  final Color backgroundColor;
  final Color statusColor;
  final double totalAmount;
  final double currentAmount;
  final double? costPreview;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.all(Radius.circular(2.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 3,
            offset: const Offset(0, 2), // changes position of shadow
          ),
        ],
      ),
      child: buildColorBar(),
    );
  }

  AnimatedFractionallySizedBox buildColorBar() {
    final afterCost = max(0, currentAmount - (costPreview ?? 0));
    final alignment = axis == Axis.vertical ? Alignment.bottomCenter : Alignment.centerLeft;
    return AnimatedFractionallySizedBox(
      alignment: alignment,
      heightFactor: currentAmount / totalAmount,
      duration: 300.ms,
      curve: Curves.easeInOutCubicEmphasized,
      child: ColoredBox(
        color: statusColor.withOpacity(0.5),
        child: AnimatedFractionallySizedBox(
          alignment: alignment,
          heightFactor: afterCost / currentAmount,
          duration: 300.ms,
          curve: Curves.easeInOutCubicEmphasized,
          child: ColoredBox(color: statusColor.withOpacity(0.5)),
        ),
      ),
    );
  }
}

