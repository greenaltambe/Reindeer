import 'package:flutter/material.dart';

/// Keeps every tab alive (like an indexed stack) but fades and lifts the tab
/// that has just been selected.
class BranchFader extends StatelessWidget {
  const BranchFader({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          _Branch(active: i == currentIndex, child: children[i]),
      ],
    );
  }
}

class _Branch extends StatefulWidget {
  const _Branch({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_Branch> createState() => _BranchState();
}

class _BranchState extends State<_Branch> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: widget.active ? 1 : 0,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void didUpdateWidget(_Branch old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _controller.forward(from: 0);
    } else if (!widget.active && old.active) {
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: !widget.active,
      child: TickerMode(
        enabled: widget.active,
        child: FadeTransition(
          opacity: _curve,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(_curve),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
