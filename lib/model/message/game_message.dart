enum GameMessageType {
  goldNotEnough,
  enemyArriveGoal,
}

class GameMessage {
  final GameMessageType type;
  final String message;


  const GameMessage({
    required this.type,
    required this.message,
  });

  const GameMessage.goldNotEnough() : this(
    type: GameMessageType.goldNotEnough,
    message: 'We need more gold!',
  );
}