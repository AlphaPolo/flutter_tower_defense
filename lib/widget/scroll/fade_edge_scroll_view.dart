import 'package:flutter/material.dart';

class FadeEdgeScrollView extends StatefulWidget {
  final Axis axis;
  final Widget child;
  final double size;
  final Color color;

  const FadeEdgeScrollView({
    super.key,
    required this.axis,
    required this.child,
    this.size = 20,
    this.color = Colors.white,
  });

  @override
  State<FadeEdgeScrollView> createState() => _FadeEdgeScrollViewState();
}

class _FadeEdgeScrollViewState extends State<FadeEdgeScrollView> {

  final ValueNotifier<bool> isLeadFading = ValueNotifier(false);
  final ValueNotifier<bool> isTrailFading = ValueNotifier(false);

  @override
  void dispose() {
    isLeadFading.dispose();
    isTrailFading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        if(notification.metrics.axis != widget.axis) {
          return false;
        }
        _handleNotification(notification.metrics);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if(notification.metrics.axis != widget.axis) {
            return false;
          }

          if (notification is ScrollUpdateNotification || notification is ScrollEndNotification) {
            _handleNotification(notification.metrics);
          }
          return false;
        },
        // 使用 LayoutBuilder 取得 parent 提供的"最大可用寬度"
        child: Stack(
          children: [
            SingleChildScrollView(
              scrollDirection: widget.axis,
              child: widget.child,
            ),
            _buildFade(lead: true),
            _buildFade(lead: false),
          ],
        ),
      ),
    );
  }

  void _handleNotification(ScrollMetrics metrics) {
    isLeadFading.value = metrics.extentBefore > 0;
    isTrailFading.value = metrics.extentAfter > 0;
  }

  /// 單側漸層遮罩：[lead]＝軸起點側（左/上），否則為終點側（右/下）。
  /// 漸層自外緣實色往內淡出；只在該側還有可捲內容時淡入顯示。
  Widget _buildFade({required bool lead}) {
    final horizontal = widget.axis == Axis.horizontal;
    final outerEdge = horizontal
        ? (lead ? Alignment.centerLeft : Alignment.centerRight)
        : (lead ? Alignment.topCenter : Alignment.bottomCenter);
    return Positioned(
      // 貼齊該側外緣，另一軸兩端撐滿。
      left: !horizontal || lead ? 0 : null,
      right: !horizontal || !lead ? 0 : null,
      top: horizontal || lead ? 0 : null,
      bottom: horizontal || !lead ? 0 : null,
      child: ValueListenableBuilder<bool>(
        valueListenable: lead ? isLeadFading : isTrailFading,
        builder: (context, fading, child) => AnimatedOpacity(
          opacity: fading ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          child: child,
        ),
        child: IgnorePointer(
          child: Container(
            width: horizontal ? widget.size : null,
            height: horizontal ? null : widget.size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: outerEdge,
                end: -outerEdge,
                colors: [
                  widget.color,
                  widget.color.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
