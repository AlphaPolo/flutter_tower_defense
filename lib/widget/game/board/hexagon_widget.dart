import 'package:flutter/material.dart';

import '../../clip/hexagon_clipper.dart';

class HexagonWidget extends StatelessWidget {
  const HexagonWidget({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    // print('hexagon rebuild');
    return RepaintBoundary(
      child: ClipPath(
        clipper: HexagonClipper(),
        child: Container(
          color: color,
        ),
      ),
    );
  }
}
