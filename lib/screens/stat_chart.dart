import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';

class StatChart extends StatelessWidget {
  final String title;
  final String unit;
  final List<StatPoint> points;
  final List<ChartSeries> series;
  final double? fixedMax;
  final StatRange range;

  const StatChart({
    super.key,
    required this.title,
    required this.unit,
    required this.points,
    required this.series,
    required this.range,
    this.fixedMax,
  });

  String _time(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    if (range == StatRange.live) return '${two(t.minute)}:${two(t.second)}';
    return range.index <= StatRange.h24.index ? '${two(t.hour)}:${two(t.minute)}' : '${two(t.day)}/${two(t.month)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lines = <LineChartBarData>[];
    var maxY = 0.0;
    for (final s in series) {
      final spots = <FlSpot>[];
      for (var i = 0; i < points.length; i++) {
        final v = s.value(points[i]);
        if (v == null) continue;
        spots.add(FlSpot(i.toDouble(), v));
        if (v > maxY) maxY = v;
      }
      lines.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.2,
        preventCurveOverShooting: true,
        barWidth: 2.2,
        color: s.color,
                dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: true, color: s.color.withValues(alpha: series.length == 1 ? 0.15 : 0.06)),
      ));
    }
    final top = fixedMax ?? (maxY <= 0 ? 1.0 : maxY * 1.2);
    final last = points.isEmpty ? null : series.first.value(points.last);

    return BzCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
            if (series.length > 1)
              for (final s in series) ...[
                Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(s.label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                const SizedBox(width: 10),
              ]
            else if (last != null)
              Text('${last.toStringAsFixed(last < 10 ? 1 : 0)}$unit', style: TextStyle(fontWeight: FontWeight.w700, color: series.first.color)),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            child: points.length < 2
                ? Center(child: Text('Nessun dato', style: TextStyle(color: cs.onSurfaceVariant)))
                : LineChart(LineChartData(
                    minY: 0,
                    maxY: top,
                    minX: 0,
                    maxX: (points.length - 1).toDouble(),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: top / 4,
                      getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withValues(alpha: 0.4), strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 34,
                          interval: top / 4,
                          getTitlesWidget: (v, meta) => (v == meta.max)
                              ? const SizedBox.shrink()
                              : Text(v.toStringAsFixed(top < 8 ? 1 : 0), style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          interval: ((points.length - 1) / 3).clamp(1, 1e9).toDouble(),
                          getTitlesWidget: (v, meta) {
                            final i = v.round();
                            if (i < 0 || i >= points.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(_time(points[i].time), style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                            );
                          },
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) => [
                          for (final s in spots)
                            LineTooltipItem(
                              '${series[s.barIndex].label.isEmpty ? '' : '${series[s.barIndex].label} '}${s.y.toStringAsFixed(1)}$unit\n${_time(points[s.x.round()].time)}',
                              TextStyle(color: series[s.barIndex].color, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                    lineBarsData: lines,
                  )),
          ),
        ]),
    );
  }
}

class ChartSeries {
  final String label;
  final Color color;
  final double? Function(StatPoint) value;
  const ChartSeries(this.label, this.color, this.value);
}
