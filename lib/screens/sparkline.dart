import 'package:flutter/material.dart';

/// Tiny line chart with a soft fill, no axes. Values are plotted on 0..[max].
class Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double max;
  final double height;
  const Sparkline({super.key, required this.values, required this.color, this.max = 100, this.height = 30});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _SparkPainter(values, color, max)),
      );
}

class _SparkPainter extends CustomPainter {
  final List<double> v;
  final Color color;
  final double max;
  _SparkPainter(this.v, this.color, this.max);

  @override
  void paint(Canvas canvas, Size size) {
    if (v.length < 2) return;
    final dx = size.width / (v.length - 1);
    Offset pt(int i) => Offset(i * dx, size.height - 2 - (v[i] / max).clamp(0.0, 1.0) * (size.height - 4));
    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < v.length; i++) {
      final a = pt(i - 1), b = pt(i), mid = (a.dx + b.dx) / 2;
      line.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)])
            .createShader(Offset.zero & size),
    );
    canvas.drawPath(line, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.6..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_SparkPainter o) => o.v != v || o.color != color;
}
