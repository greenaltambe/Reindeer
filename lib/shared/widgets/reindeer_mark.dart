import 'dart:math';

import 'package:flutter/material.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/core/utils/reindeer_voice.dart';

/// The Reindeer mascot: a friendly face with antlers, drawn in code.
///
/// With [interactive] set, tapping it lights up the nose and shows a short
/// quip (a small easter egg).
class ReindeerMark extends StatefulWidget {
  const ReindeerMark({super.key, this.size = 64, this.interactive = false});

  final double size;
  final bool interactive;

  @override
  State<ReindeerMark> createState() => _ReindeerMarkState();
}

class _ReindeerMarkState extends State<ReindeerMark> {
  final Random _random = Random();
  bool _glow = false;

  void _onTap() {
    setState(() => _glow = true);
    context.showSnackBar(ReindeerVoice.quip(_random));
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _glow = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final mark = AnimatedScale(
      scale: _glow ? 1.12 : 1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _ReindeerPainter(
            face: scheme.primary,
            antlers: scheme.secondary,
            eyes: scheme.onPrimary,
            glow: _glow,
          ),
        ),
      ),
    );
    if (!widget.interactive) return ExcludeSemantics(child: mark);
    return Semantics(
      button: true,
      label: 'Reindeer mascot',
      child: GestureDetector(onTap: _onTap, child: mark),
    );
  }
}

class _ReindeerPainter extends CustomPainter {
  const _ReindeerPainter({
    required this.face,
    required this.antlers,
    required this.eyes,
    required this.glow,
  });

  final Color face;
  final Color antlers;
  final Color eyes;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    Offset p(double x, double y) => Offset(x * s, y * s);

    final antlerPaint = Paint()
      ..color = antlers
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void antler(bool mirror) {
      double x(double v) => mirror ? 100 - v : v;
      final beam = Path()
        ..moveTo(p(x(38), 42).dx, p(x(38), 42).dy)
        ..lineTo(p(x(30), 26).dx, p(x(30), 26).dy)
        ..lineTo(p(x(22), 8).dx, p(x(22), 8).dy);
      canvas.drawPath(beam, antlerPaint);
      canvas.drawLine(p(x(30), 26), p(x(15), 22), antlerPaint);
      canvas.drawLine(p(x(26), 17), p(x(14), 11), antlerPaint);
      canvas.drawLine(p(x(24), 12), p(x(31), 5), antlerPaint);
    }

    antler(false);
    antler(true);

    final facePaint = Paint()..color = face;
    // Ears.
    canvas.save();
    canvas.translate(p(27, 50).dx, p(27, 50).dy);
    canvas.rotate(-0.6);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 16 * s, height: 9 * s),
      facePaint,
    );
    canvas.restore();
    canvas.save();
    canvas.translate(p(73, 50).dx, p(73, 50).dy);
    canvas.rotate(0.6);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 16 * s, height: 9 * s),
      facePaint,
    );
    canvas.restore();
    // Head and muzzle.
    canvas.drawOval(
      Rect.fromCenter(center: p(50, 60), width: 44 * s, height: 50 * s),
      facePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: p(50, 80), width: 26 * s, height: 18 * s),
      Paint()
        ..color = Color.alphaBlend(Colors.white.withValues(alpha: 0.28), face),
    );
    // Eyes.
    final eyePaint = Paint()..color = eyes;
    canvas.drawCircle(p(41, 58), 3 * s, eyePaint);
    canvas.drawCircle(p(59, 58), 3 * s, eyePaint);
    // Nose.
    if (glow) {
      canvas.drawCircle(
        p(50, 80),
        10 * s,
        Paint()
          ..color = const Color(0xFFE53935).withValues(alpha: 0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * s),
      );
    }
    canvas.drawCircle(
      p(50, 80),
      5.5 * s,
      Paint()..color = glow ? const Color(0xFFE53935) : const Color(0xFF3B2A25),
    );
  }

  @override
  bool shouldRepaint(_ReindeerPainter old) =>
      old.face != face ||
      old.antlers != antlers ||
      old.eyes != eyes ||
      old.glow != glow;
}
