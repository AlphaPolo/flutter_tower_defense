part of towers;



class ObstacleTowerWidget  extends StatelessWidget {
  const ObstacleTowerWidget({super.key, required this.model});
  final BuildingModel model;

  Widget buildTurret() {
    return Transform.rotate(
      angle: model.direction,
      child: FractionalTranslation(
        translation: const Offset(0.5, 0),
        child: Container(
          color: Colors.blue,
          width: 25,
          height: 5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildStackBase(
      children: [
        const HexagonWidget(color: Colors.black87),
        Transform.scale(
          scale: 0.9,
          child: const HexagonWidget(color: Colors.brown)
        ),
      ],
    );
  }
}
