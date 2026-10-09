import 'package:flutter/material.dart';

/// Fades and lifts its child in once when it first appears. Give list items an
/// [index] so they arrive one after another.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 14,
  });

  final Widget child;
  final int index;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final i = index.clamp(0, 8);
    final delayMs = 55 * i;
    final totalMs = 280 + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(delayMs / totalMs, 1, curve: Curves.easeOutCubic),
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * offset),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Slides and fades between pages of a flow. The direction follows whether
/// [index] went up (forward) or down (back).
class StepSwitcher extends StatefulWidget {
  const StepSwitcher({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<StepSwitcher> createState() => _StepSwitcherState();
}

class _StepSwitcherState extends State<StepSwitcher> {
  bool _forward = true;

  @override
  void didUpdateWidget(StepSwitcher old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _forward = widget.index > old.index;
  }

  @override
  Widget build(BuildContext context) {
    final currentKey = ValueKey<int>(widget.index);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final incoming = child.key == currentKey;
        final dx = (_forward ? 1.0 : -1.0) * (incoming ? 0.12 : -0.12);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(dx, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: currentKey, child: widget.child),
    );
  }
}
