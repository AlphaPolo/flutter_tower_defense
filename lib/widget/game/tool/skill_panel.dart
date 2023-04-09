import 'package:flutter/material.dart';
import 'package:tower_defense/extension/duration_extension.dart';
import '../../animated/animated_shrink_size.dart';


class SkillPanel extends StatefulWidget {
  const SkillPanel({super.key});

  @override
  State<SkillPanel> createState() => _SkillPanelState();
}

class _SkillPanelState extends State<SkillPanel> {

  bool fold = false;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildHeader(fold),
        skillsButtons(),
      ],
    );
    return Container(
      width: 100,
      margin: const EdgeInsets.all(12),
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
      child: child,
    );
  }

  Widget buildHeader(bool fold) {
    final icon = fold ? const Icon(Icons.unfold_more) : const Icon(Icons.unfold_less);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text('技能列'),
        IconButton(onPressed: () => setState(() => this.fold = !fold), icon: icon),
      ],
    );
  }

  Widget skillsButtons() {
    return AnimatedShrinkSize(
      open: !fold,
      duration: 300.ms,
      curve: Curves.easeOutQuart,
      axisAlignment: -1,
      // child: Selector<PlayerProvider, Tuple2<List<Skill>, Skill?>>(
      //   selector: (context, vm) => Tuple2(vm.skills, vm.selectedSkill),
      //   builder: (context, tuple, _) {
      //     final skills = tuple.item1;
      //     final selected = tuple.item2;
      //     return Column(
      //       children: skills.map((skill) => buildSkillButton(context, skill, selected)).toList(),
      //     );
      //   }
      // ),
    );
  }

  Widget buildSkillButton(BuildContext context) {
    return Tooltip(
      waitDuration: 700.ms,
      richMessage: TextSpan(
        children: [
          // TextSpan(text: '${skill.name}\n', style: const TextStyle(fontSize: 16)),
          // TextSpan(text: skill.description, style: const TextStyle(fontSize: 12)),
        ],
      ),
      // child: IconButton(
      //   onPressed: () {
      //     context.read<PlayerProvider>().selectedSkill = skill;
      //   },
      //   icon: Icon(switchIcon(skill), color: isSelected ? Colors.orangeAccent : null),
      // ),
    );
  }

  // List<Widget> skillButtons() {
  //   return [
  //     IconButton(onPressed: () {}, icon: const Icon(Icons.run_circle_outlined)),
  //     IconButton(onPressed: () {}, icon: const Icon(Icons.ac_unit)),
  //   ];
  // }
}
