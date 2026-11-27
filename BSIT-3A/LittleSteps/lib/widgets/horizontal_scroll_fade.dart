import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Applies a soft right-edge fade when a horizontal scroll view has more content.
class HorizontalScrollFade extends StatefulWidget {
  /// Creates a [HorizontalScrollFade].
  const HorizontalScrollFade({super.key, required this.child});

  /// Horizontally scrollable child widget.
  final Widget child;

  @override
  State<HorizontalScrollFade> createState() => _HorizontalScrollFadeState();
}

class _HorizontalScrollFadeState extends State<HorizontalScrollFade> {
  bool _showRightFade = true;

  bool _handleScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.horizontal) return false;
    final hasMoreRight =
        notification.metrics.maxScrollExtent > 0 &&
        notification.metrics.extentAfter > 4;
    if (hasMoreRight != _showRightFade) {
      setState(() => _showRightFade = hasMoreRight);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScroll,
      child: _showRightFade
          ? ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.surfaceCard,
                  AppColors.surfaceCard,
                  Colors.transparent,
                ],
                stops: [0.0, 0.9, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: widget.child,
            )
          : widget.child,
    );
  }
}
