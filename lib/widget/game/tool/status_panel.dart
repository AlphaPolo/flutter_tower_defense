import 'dart:math';

import 'package:flutter/material.dart';
import 'package:tower_defense/extension/duration_extension.dart';


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
          maxHeight: fold ? 50 : 200
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
          // buildStatus(),
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

  // Widget buildStatus() {
  //   return Positioned.fill(
  //     top: 50,
  //     child: Padding(
  //       padding: const EdgeInsets.all(8.0),
  //       child: Selector<PlayerProvider, Tuple2<CharacterStatus, double?>>(
  //           selector: (context, vm) => Tuple2(vm.status, vm.costStamina),
  //           builder: (context, tuple, _) {
  //             final status = tuple.item1;
  //             final costStamina = tuple.item2;
  //             return Row(
  //               crossAxisAlignment: CrossAxisAlignment.stretch,
  //               children: [
  //                 SizedBox(
  //                   width: 20,
  //                   child: StatusBar(
  //                     backgroundColor: Colors.grey,
  //                     statusColor: Colors.redAccent,
  //                     totalAmount: status.totalHp,
  //                     currentAmount: status.currentHp,
  //                     // costPreview: costStamina,
  //                   ),
  //                 ),
  //                 // Container(width: 20, color: Colors.redAccent),
  //                 const SizedBox(width: 8.0),
  //                 SizedBox(
  //                   width: 20,
  //                   child: StatusBar(
  //                     backgroundColor: Colors.grey,
  //                     statusColor: Colors.greenAccent,
  //                     totalAmount: status.totalStamina,
  //                     currentAmount: status.currentStamina,
  //                     costPreview: costStamina,
  //                   ),
  //                 ),
  //               ],
  //             );
  //           }
  //       ),
  //     ),
  //   );
  // }
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

