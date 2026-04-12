import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/category_provider.dart';

class CategoryList extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final Function(String) onSelect;

  const CategoryList({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  static const Color _bg = Color(0xFF0D1117);
  static const Color _orange = Color(0xFFFF6A00);

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();

    return Container(
      width: 76,
      color: _bg,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10),
        children: categories.map((c) {
          final isSelected = c == selected;
          final icon = categoryProvider.iconOf(c);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelect(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _orange
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? null
                      : Border.all(
                          color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: isSelected ? Colors.white : Colors.white54,
                      size: 22,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      c,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isSelected ? Colors.white : Colors.white54,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        letterSpacing: 0.2,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
