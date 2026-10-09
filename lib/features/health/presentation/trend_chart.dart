import 'package:flutter/material.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/core/i18n/strings.dart';

/// A simple line chart over time. [second] draws a second line (for blood
/// pressure). Points must be oldest first.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.times,
    required this.values,
    this.second,
    this.compact = false,
    this.height = 180,
  });

  final List<DateTime> times;
  final List<double> values;
  final List<double>? second;
  final bool compact;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SizedBox(
      height: compact ? 40 : height,
      width: double.infinity,
      // The line draws itself in from the left the first time it appears.
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) => CustomPaint(
          painter: _TrendPainter(
            times: times,
            values: values,
            second: second,
            compact: compact,
            line: scheme.primary,
            line2: scheme.secondary,
            grid: scheme.outlineVariant,
            text: scheme.onSurfaceVariant,
            progress: progress,
          ),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.times,
    required this.values,
    required this.second,
    required this.compact,
    required this.line,
    required this.line2,
    required this.grid,
    required this.text,
    this.progress = 1,
  });

  final List<DateTime> times;
  final List<double> values;
  final List<double>? second;
  final bool compact;
  final Color line, line2, grid, text;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final all = [...values, ...?second];
    var lo = all.reduce((a, b) => a < b ? a : b);
    var hi = all.reduce((a, b) => a > b ? a : b);
    if (hi - lo < 1) {
      lo -= 1;
      hi += 1;
    }
    final pad = (hi - lo) * 0.12;
    lo -= pad;
    hi += pad;

    final left = compact ? 2.0 : 34.0;
    final bottom = compact ? 2.0 : 18.0;
    final rect = Rect.fromLTRB(left, 4, size.width - 6, size.height - bottom);

    final t0 = times.first.millisecondsSinceEpoch.toDouble();
    final t1 = times.last.millisecondsSinceEpoch.toDouble();
    double x(int i) => values.length == 1 || t1 == t0
        ? (values.length == 1
              ? rect.center.dx
              : rect.left + rect.width * i / (values.length - 1))
        : rect.left +
              rect.width * (times[i].millisecondsSinceEpoch - t0) / (t1 - t0);
    double y(double v) => rect.bottom - rect.height * (v - lo) / (hi - lo);

    if (!compact) {
      final gridPaint = Paint()
        ..color = grid
        ..strokeWidth = 1;
      for (var i = 0; i <= 2; i++) {
        final v = lo + (hi - lo) * i / 2;
        final yy = y(v);
        canvas.drawLine(
          Offset(rect.left, yy),
          Offset(rect.right, yy),
          gridPaint,
        );
        _label(canvas, v.round().toString(), Offset(0, yy - 6));
      }
      _label(
        canvas,
        '${times.first.day}/${times.first.month}',
        Offset(rect.left, size.height - 14),
      );
      final endText = '${times.last.day}/${times.last.month}';
      _label(canvas, endText, Offset(rect.right - 28, size.height - 14));
    }

    void draw(List<double> vs, Color color) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = compact ? 2 : 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      for (var i = 0; i < vs.length; i++) {
        final p = Offset(x(i), y(vs[i]));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
      if (!compact || vs.length == 1) {
        final dot = Paint()..color = color;
        for (var i = 0; i < vs.length; i++) {
          canvas.drawCircle(Offset(x(i), y(vs[i])), compact ? 3 : 4, dot);
        }
      }
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    draw(values, line);
    final s = second;
    if (s != null && s.length == values.length) draw(s, line2);
    canvas.restore();
  }

  void _label(Canvas canvas, String s, Offset at) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: text, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.values != values ||
      old.times != times ||
      old.second != second ||
      old.line != line ||
      old.progress != progress;
}

/// Friendly "2 days ago" text.
String agoText(DateTime at, DateTime now) {
  final d = dateOnly(now).difference(dateOnly(at)).inDays;
  if (d <= 0) return trf('Today, {n}', {'n': formatTime(at)});
  if (d == 1) return tr('Yesterday');
  if (d < 30) return trf('{n} days ago', {'n': '$d'});
  return trn((d / 30).floor(), '{n} month ago', '{n} months ago');
}
