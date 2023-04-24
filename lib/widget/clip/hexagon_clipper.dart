import 'dart:math';

import 'package:flutter/material.dart';


class HexagonClipper extends CustomClipper<Path> {
  // const HexagonClipper();

  Path? _cachePath;

  @override
  Path getClip(Size size) {

    if(_cachePath != null) {
      return _cachePath!;
    }
    // print(size);
    // print('reclip');

    <Offset>[
      Offset(size.width / 2, 0),  // top
    ];

    final radius = size.longestSide / 2;
    final center = size.center(Offset.zero);
    final horizonX = radius * sqrt(3) / 2;

    final path = Path()
      ..moveTo(center.dx, 0) // moving to topCenter 1st, then draw the path
      ..lineTo(center.dx + horizonX, size.height * .25)
      ..lineTo(center.dx + horizonX, size.height * .75)
      ..lineTo(center.dx, size.height)
      ..lineTo(center.dx - horizonX, size.height * .75)
      ..lineTo(center.dx - horizonX, size.height * .25)
      ..close();

    _cachePath = path;

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    return false;
  }
}
