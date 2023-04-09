import 'package:flutter/material.dart';

/// 開關式 AnimationSize 類似 transition 效果
class AnimatedShrinkSize extends ImplicitlyAnimatedWidget{
  const AnimatedShrinkSize({
    super.key,
    this.axis = Axis.vertical,
    this.axisAlignment = 0.0,
    this.child,
    required this.open,
    required super.duration,
    super.curve,
    super.onEnd,
  });

  @override
  ImplicitlyAnimatedWidgetState<ImplicitlyAnimatedWidget> createState() => _AnimatedShrinkSizeState();

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget? child;

  /// The target size.
  ///
  /// An open of true is fully size. an open of false is size 0
  /// (i.e., invisible).
  ///
  /// The open must not be null.
  final bool open;

  final Axis axis;
  final double axisAlignment;
}

class _AnimatedShrinkSizeState extends ImplicitlyAnimatedWidgetState<AnimatedShrinkSize> {
  Tween<double>? _size;
  late Animation<double> _sizeAnimation;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _size = visitor(_size, (widget.open ? 1 : 0).toDouble(), (dynamic value) => Tween<double>(begin: value as double)) as Tween<double>?;
  }

  @override
  void didUpdateTweens() {
    _sizeAnimation = animation.drive(_size!);
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      axis: widget.axis,
      axisAlignment: widget.axisAlignment,
      sizeFactor: _sizeAnimation,
      child: widget.child,
    );
  }
}