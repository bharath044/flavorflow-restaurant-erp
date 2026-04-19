import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/category_provider.dart';
import '../services/api_service.dart';
import '../models/product.dart';

class CustomerMenuScreen extends StatefulWidget {
  final String tableNo;
  const CustomerMenuScreen({super.key, required this.tableNo});

  @override
  State<CustomerMenuScreen> createState() => _CustomerMenuScreenState();
}

class _CustomerMenuScreenState extends State<CustomerMenuScreen> {
  String selectedCategory = 'All';
  final Map<String, int> cart = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<ProductProvider>().fetchProducts();
      context.read<CategoryProvider>().fetchCategories();
    });
  }

  void _updateCart(String productId, int delta) {
    setState(() {
      final current = cart[productId] ?? 0;
      final newValue = current + delta;
      if (newValue <= 0) {
        cart.remove(productId);
      } else {
        cart[productId] = newValue;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>().products;
    final categories = context.watch<CategoryProvider>().categories;

    final filteredProducts = selectedCategory == 'All'
        ? products
        : products.where((p) => p.category == selectedCategory).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF6A00),
        elevation: 0,
        title: const Text('FlavorFlow Restaurant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(child: Text('📍 ${widget.tableNo}', style: const TextStyle(fontWeight: FontWeight.bold))),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Selector
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryChip('All'),
                ...categories.map((c) => _buildCategoryChip(c['name'])),
              ],
            ),
          ),
          
          Expanded(
            child: filteredProducts.isEmpty
                ? const Center(child: Text('No items found', style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredProducts.length,
                    itemBuilder: (ctx, i) {
                      final p = filteredProducts[i];
                      final qty = cart[p.id] ?? 0;
                      return _buildProductCard(p, qty);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6A00),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  // Implement Checkout Logic
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${cart.length} Items - Place Order', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCategoryChip(String name) {
    final isSelected = selectedCategory == name;
    return GestureDetector(
      onTap: () => setState(() => selectedCategory = name),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6A00) : Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            name,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Product p, int qty) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: p.image.isNotEmpty
                ? Image.network(p.image, width: 70, height: 70, fit: BoxFit.cover, errorBuilder: (ctx, e, s) => _placeholder())
                : _placeholder(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('₹${p.price}', style: const TextStyle(color: Color(0xFFFF6A00), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Color(0xFFFF6A00)),
                  onPressed: () => _updateCart(p.id, -1),
                ),
                Text('$qty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Color(0xFFFF6A00)),
                  onPressed: () => _updateCart(p.id, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 70,
      height: 70,
      color: Colors.white10,
      child: const Icon(Icons.fastfood_rounded, color: Colors.white24),
    );
  }
}
