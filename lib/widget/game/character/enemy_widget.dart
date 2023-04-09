import 'package:flutter/material.dart';

class EnemyWidget extends StatelessWidget {
  const EnemyWidget({super.key});


  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.indigo,
        shape: BoxShape.circle,
      ),
    );
  }
}
