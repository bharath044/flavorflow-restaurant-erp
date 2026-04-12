import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class CategoryPieChart extends StatelessWidget {
  const CategoryPieChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Most Popular Food",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                  sections: [
                    _section(40, const Color(0xFFFF6F6F), "Pizza"),
                    _section(30, const Color(0xFFFFC75F), "Burger"),
                    _section(20, const Color(0xFF4CAF50), "Dessert"),
                    _section(10, const Color(0xFF42A5F5), "Drinks"),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PieChartSectionData _section(double value, Color color, String title) {
    return PieChartSectionData(
      value: value,
      title: title,
      color: color,
      radius: 60,
      titleStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
}
