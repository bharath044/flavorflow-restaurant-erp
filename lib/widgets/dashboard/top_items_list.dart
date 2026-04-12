import 'package:flutter/material.dart';

class TopItemsList extends StatelessWidget {
  const TopItemsList({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      "Cream Pancake",
      "Red Sauce Pasta",
      "Cheese Garlic Pizza",
      "Veg Cheese Sandwich",
      "White Sauce Pasta",
    ];

    return Card(
      child: ListView.builder(
        itemCount: items.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (_, i) {
          return ListTile(
            title: Text(items[i]),
            trailing: Text("${120 - i * 10} times"),
          );
        },
      ),
    );
  }
}
