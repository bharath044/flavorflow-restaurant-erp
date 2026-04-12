import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/product_provider.dart';
import '../providers/kitchen_provider.dart';
import 'product_card.dart';
import '../utils/responsive_helper.dart';

class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final Function(Product) onTap;

  const ProductGrid({
    super.key,
    required this.products,
    required this.onTap,
  });

  int _crossAxisCount(double width) {
    if (width < 500)  return 2;
    if (width < 780)  return 3;
    if (width < 1100) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    context.watch<KitchenProvider>();

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                color: Colors.white.withOpacity(0.12), size: 60),
            const SizedBox(height: 14),
            const Text(
              'No items found',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try a different category or search term',
              style: TextStyle(color: Colors.white12, fontSize: 12.5),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = _crossAxisCount(constraints.maxWidth);
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            // Taller cards on mobile (ratio ~0.56) to prevent clipping button
            childAspectRatio: ResponsiveHelper.isMobile(context) ? 0.56 : 0.62,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: products.length,
          itemBuilder: (_, index) {
            final p = products[index];
            final liveProduct = productProvider.getById(p.id) ?? p;
            return ProductCard(
              product: liveProduct,
              onAdd: () => onTap(liveProduct),
            );
          },
        );
      },
    );
  }
}
