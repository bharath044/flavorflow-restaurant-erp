import 'package:flutter/material.dart';

class IconPicker extends StatelessWidget {
  final IconData selected;
  final ValueChanged<IconData> onSelect;

  const IconPicker({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  static final icons = [
    Icons.rice_bowl,
    Icons.ramen_dining,
    Icons.lunch_dining,
    Icons.local_pizza,
    Icons.restaurant,
    Icons.icecream,
    Icons.local_cafe,
    Icons.set_meal,
    Icons.fastfood,
    Icons.emoji_food_beverage,
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: icons.map((icon) {
        final selectedIcon = icon == selected;

        return GestureDetector(
          onTap: () => onSelect(icon),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selectedIcon
                  ? const Color(0xFFFF6A00)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: selectedIcon ? Colors.white : Colors.black,
            ),
          ),
        );
      }).toList(),
    );
  }
}
