// import 'package:flame/sprite.dart';
// import 'package:flame/widgets.dart';
// import 'package:flutter/material.dart';
// import 'package:timeline_game_prototype/model/character/sprite_character.dart';
//
// class CharacterWidget extends StatefulWidget {
//   const CharacterWidget({super.key, required this.character});
//   final SpriteCharacter character;
//
//
//   @override
//   State<CharacterWidget> createState() => _CharacterWidgetState();
// }
//
// class _CharacterWidgetState extends State<CharacterWidget> {
//
//   SpriteSheet? animationSpriteSheet;
//   SpriteAnimation? animation;
//
//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     loadData();
//   }
//
//   Future<void> loadData() async {
//     print('loadData');
//     final character = widget.character;
//     await character.init();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     print('characterRebuild');
//     return AnimatedBuilder(
//       animation: widget.character,
//       builder: (context, _) {
//         if(widget.character.current == null) {
//           return const SizedBox.shrink();
//         }
//
//         return FractionalTranslation(
//           translation: const Offset(0, -0.5),
//           child: Transform.scale(
//             scale: 2.0,
//             child: ColoredBox(
//               color: Colors.redAccent.withOpacity(0.0),
//               child: SpriteAnimationWidget(
//                 animation: widget.character.current!,
//                 anchor: Anchor.center,
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }
