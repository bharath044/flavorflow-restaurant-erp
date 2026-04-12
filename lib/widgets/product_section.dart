import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/category_provider.dart';
import 'category_list.dart';
import 'product_grid.dart';
import '../utils/responsive_helper.dart';

class ProductSection extends StatelessWidget {
  final String selectedCategory;
  final Function(String) onCategorySelected;
  final List<Product> products;
  final Function(Product) onProductTap;
  final Function(String) onSearch;
  final String? tableNo;      // null = takeaway
  final bool isTakeaway;

  const ProductSection({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.products,
    required this.onProductTap,
    required this.onSearch,
    this.tableNo,
    this.isTakeaway = false,
  });

  static const Color _bg         = Color(0xFF0F1117);
  static const Color _headerBg   = Color(0xFF0D1117);
  static const Color _fieldBg    = Color(0xFF1A1A2E);
  static const Color _fieldBorder= Color(0xFF252D45);
  static const Color _orange     = Color(0xFFFF6A00);
  static const Color _badgeBg    = Color(0xFF1E2235);

  @override
  Widget build(BuildContext context) {
    final categories = [
      'All',
      ...context.watch<CategoryProvider>().categories.map((c) => c.name),
    ];

    final subtitle = isTakeaway
        ? "Select items to add to takeaway order"
        : tableNo != null
            ? "Select items to add to Table ${tableNo}'s order"
            : "Select items to add to order";

    return Container(
      color: _bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // ─── HEADER ──────────────────────────────────────────────
          Container(
            color: _headerBg,
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                ResponsiveHelper.isMobile(context)
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Main Menu',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 38,
                                  child: TextField(
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: 'Search menu items...',
                                      hintStyle: const TextStyle(
                                          color: Colors.white30, fontSize: 13),
                                      prefixIcon: const Icon(Icons.search_rounded,
                                          color: Colors.white30, size: 18),
                                      filled: true,
                                      fillColor: _fieldBg,
                                      contentPadding:
                                          const EdgeInsets.symmetric(vertical: 10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: _fieldBorder, width: 1),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: _orange, width: 1.5),
                                      ),
                                    ),
                                    onChanged: onSearch,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _badgeBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _fieldBorder),
                                ),
                                child: Text(
                                  '${products.length}',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Title + subtitle
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Main Menu',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  subtitle,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Search bar
                          SizedBox(
                            width: 220,
                            height: 38,
                            child: TextField(
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Search menu items...',
                                hintStyle: const TextStyle(
                                    color: Colors.white30, fontSize: 13),
                                prefixIcon: const Icon(Icons.search_rounded,
                                    color: Colors.white30, size: 18),
                                filled: true,
                                fillColor: _fieldBg,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: _fieldBorder, width: 1),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: _orange, width: 1.5),
                                ),
                              ),
                              onChanged: onSearch,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Items found badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _badgeBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _fieldBorder),
                            ),
                            child: Text(
                              '${products.length} ITEMS FOUND',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),

          // thin divider
          const Divider(color: Color(0xFF1E2235), height: 1),

          // ─── CATEGORY SIDEBAR + PRODUCT GRID ─────────────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CategoryList(
                  categories: categories,
                  selected: selectedCategory,
                  onSelect: onCategorySelected,
                ),
                Expanded(
                  child: ProductGrid(
                    products: products,
                    onTap: onProductTap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
