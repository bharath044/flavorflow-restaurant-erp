import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/kitchen_provider.dart';
import '../services/server_config.dart';

// ─── DESIGN TOKENS ───────────────────────────────────────────────────────────
const Color _kCardBg  = Color(0xFF1A1A1A);
const Color _kOrange  = Color(0xFFFF6A00);

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAdd;

  const ProductCard({
    super.key,
    required this.product,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final kitchen   = context.watch<KitchenProvider>();
    final sessionQty = kitchen.getQty(product.id);
    final displayQty = sessionQty < 999 ? sessionQty : product.quantity;
    final isOutOfStock = !kitchen.isItemAvailable(product.id);
    final disabled = isOutOfStock || !product.isAvailable || displayQty <= 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: _kCardBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ══════════════ IMAGE ══════════════
            Expanded(
              flex: 58,
              child: MouseRegion(
                cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: disabled ? null : onAdd,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Product image
                      _productImage(),

                      // QTY badge — top-left
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.72),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            displayQty == 0 ? 'OUT' : 'QTY: $displayQty',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),

                      // Out-of-stock overlay
                      if (disabled)
                        Container(
                          color: Colors.black.withOpacity(0.52),
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'OUT OF STOCK',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // ══════════════ INFO ══════════════
            Expanded(
              flex: 42,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Name + Price row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '₹${product.price.toInt()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Description / category
                    Text(
                      product.description.isNotEmpty
                          ? product.description
                          : product.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.42),
                        fontSize: 11.5,
                      ),
                    ),

                    const Spacer(),

                    // ADD button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: disabled ? null : onAdd,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kOrange,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor:
                              const Color(0xFF2E2E2E),
                          disabledForegroundColor: Colors.white24,
                          elevation: 0,
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          disabled ? 'OUT' : 'ADD',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productImage() {
    if (product.imageBytes != null) {
      return Image.memory(product.imageBytes!, fit: BoxFit.cover);
    }
    return _smartImage(product.image);
  }

  /// Handles: network URLs, local assets, and "default" / missing paths.
  static Widget _smartImage(String path) {
    if (path.isEmpty ||
        path.contains('default') ||
        path == 'null') {
      return _placeholderStatic();
    }

    // Server-side uploads (absolute from root)
    if (path.startsWith('/uploads/')) {
      final fullUrl = '${ServerConfig.baseUrl}$path';
      return Image.network(
        fullUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholderStatic(),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _placeholderStatic(),
      );
    }

    // Network image (http/https)
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholderStatic(),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _placeholderStatic(),
      );
    }

    // Local asset
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _placeholderStatic(),
    );
  }

  static Widget _placeholderStatic() => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu_rounded,
                color: Colors.white.withOpacity(0.05), size: 48),
            const SizedBox(height: 8),
            Text(
              "NO IMAGE",
              style: TextStyle(
                color: Colors.white.withOpacity(0.04),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      );

}
