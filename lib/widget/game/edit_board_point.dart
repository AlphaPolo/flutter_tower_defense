import 'package:flutter/material.dart';

import 'board/board_painter.dart';
import 'color_picker.dart';

@immutable
class EditBoardPoint extends StatelessWidget {
  const EditBoardPoint({
    super.key,
    required this.boardPoint,
    this.onColorSelection,
  });

  final BoardPoint boardPoint;
  final ValueChanged<Color>? onColorSelection;

  @override
  Widget build(BuildContext context) {
    final boardPointColors = <Color>{
      Colors.white,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${boardPoint.q}, ${boardPoint.r}',
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        ColorPicker(
          colors: boardPointColors,
          selectedColor: boardPoint.color,
          onColorSelection: onColorSelection,
        ),
      ],
    );
  }
}