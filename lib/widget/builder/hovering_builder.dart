import 'package:flutter/material.dart';

class HoveringBuilder extends StatelessWidget {
  const HoveringBuilder({super.key, required this.hoveringBuilder});

  final Widget Function(bool) hoveringBuilder;

  @override
  Widget build(BuildContext context) {
    bool isHovering = false;
    return StatefulBuilder(
      builder: (context, setState) {
        final child = hoveringBuilder(isHovering);
        return MouseRegion(
          onEnter: (event) {
            isHovering = true;
            setState((){});
          },
          onExit: (event) {
            isHovering = false;
            setState((){});
          },
          child: child,
        );
      }
    );
  }
}
