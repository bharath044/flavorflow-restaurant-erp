import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class WeeklySalesChart extends StatelessWidget {
  const WeeklySalesChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Most Popular Time",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          const labels = ["3 PM", "5 PM", "7 PM", "9 PM", "11 PM"];
                          return Text(labels[value.toInt()]);
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    _bar(0, 60, const Color(0xFFFF6F6F)),
                    _bar(1, 80, const Color(0xFFFFC75F)),
                    _bar(2, 100, const Color(0xFF7ED957)),
                    _bar(3, 70, const Color(0xFF42A5F5)),
                    _bar(4, 120, const Color(0xFF1E88E5)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _bar(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 18,
          borderRadius: BorderRadius.circular(6),
        ),
      ],
    );
  }
}
