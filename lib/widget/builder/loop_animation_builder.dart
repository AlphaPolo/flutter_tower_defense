import 'package:flutter/material.dart';

class LoopAnimationBuilder extends StatefulWidget {
  const LoopAnimationBuilder({
    super.key,
    required this.builder,
    this.child,
    this.duration = const Duration(milliseconds: 300),
    this.reverse = true,
  });

  final AnimatedTransitionBuilder builder;
  final Duration duration;
  final bool reverse;
  final Widget? child;

  @override
  State<LoopAnimationBuilder> createState() => _LoopAnimationBuilderState();
}

class _LoopAnimationBuilderState extends State<LoopAnimationBuilder> with SingleTickerProviderStateMixin {
  late AnimationController controller;
  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: widget.reverse);
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
  }

  @override
  void didUpdateWidget(covariant LoopAnimationBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(oldWidget.duration != widget.duration) {
      controller.duration = widget.duration;
    }
    if(oldWidget.reverse != widget.reverse) {
      controller.repeat(reverse: widget.reverse);
    }
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return widget.builder.call(context, controller.view, child);
      },
      child: widget.child,
    );
  }
}
