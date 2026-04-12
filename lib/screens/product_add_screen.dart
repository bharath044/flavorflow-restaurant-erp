import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/product_provider.dart';
import '../providers/category_provider.dart';
import '../services/auth_provider.dart';

class ProductAddScreen extends StatefulWidget {
  const ProductAddScreen({super.key});

  @override
  State<ProductAddScreen> createState() => _ProductAddScreenState();
}

class _ProductAddScreenState extends State<ProductAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  String selectedCategory = "";
  Product? editingProduct;
  File? pickedFile;
  Uint8List? webImageBytes;
  bool _isSaving = false;
  final picker = ImagePicker();

  static const Color _bg = Color(0xFF0F1117);
  static const Color _card = Color(0xFF1A1A1A);
  static const Color _divider = Color(0xFF1E2235);
  static const Color _orange = Color(0xFFFF6A00);
  static const Color _field = Color(0xFF1A1A2E);

  Future<void> pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    if (kIsWeb) {
      webImageBytes = await picked.readAsBytes();
    } else {
      pickedFile = File(picked.path);
    }
    setState(() {});
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final product = Product(
        id: editingProduct?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameCtrl.text.trim(),
        price: double.parse(_priceCtrl.text),
        category: selectedCategory,
        // The image path in the model is less important now as the server will provide the URL
        image: editingProduct?.image ?? "assets/images/user.png",
      );

      final provider = context.read<ProductProvider>();
      bool success = false;

      if (editingProduct == null) {
        success = await provider.addProduct(
          product,
          imageFile: pickedFile,
          imageBytes: webImageBytes,
        );
      } else {
        success = await provider.updateProduct(
          product,
          imageFile: pickedFile,
          imageBytes: webImageBytes,
        );
      }

      if (success) {
        _clearForm();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green,
              content: Text(
                editingProduct == null ? "Product synced to cloud" : "Changes saved to cloud",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text("Failed to sync with server. Check connection.", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _clearForm() {
    _nameCtrl.clear();
    _priceCtrl.clear();
    pickedFile = null;
    webImageBytes = null;
    editingProduct = null;
    setState(() {});
  }

  void _startEdit(Product p) {
    _nameCtrl.text = p.name;
    _priceCtrl.text = p.price.toString();
    selectedCategory = p.category;
    editingProduct = p;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>().products;
    final isAdmin = context.watch<AuthProvider>().isAdmin;
    final isMobile = MediaQuery.of(context).size.width < 900;
    final categoryNames = context.watch<CategoryProvider>().categories.map((c) => c.name).toList();

    if (selectedCategory.isEmpty && categoryNames.isNotEmpty) {
      selectedCategory = categoryNames.first;
    }

    return Container(
      color: _bg,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: isMobile
            ? SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPageHeader(),
                    const SizedBox(height: 24),
                    _buildForm(categoryNames),
                    const SizedBox(height: 32),
                    const Text('Product Inventory', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    _buildProductList(products, isAdmin, isMobile),
                  ],
                ),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 400,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPageHeader(),
                          const SizedBox(height: 24),
                          _buildForm(categoryNames),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Product Inventory', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 16),
                        Expanded(child: _buildProductList(products, isAdmin, isMobile)),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          editingProduct == null ? "Add New Product" : "Edit Product Details",
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage your menu items and prices',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildForm(List<String> categories) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            GestureDetector(
              onTap: pickImage,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _field,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _divider),
                ),
                child: Center(
                  child: webImageBytes != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(webImageBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity))
                      : pickedFile != null
                          ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(pickedFile!, fit: BoxFit.cover, width: double.infinity, height: double.infinity))
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_rounded, color: Colors.white.withOpacity(0.2), size: 32),
                                const SizedBox(height: 8),
                                Text('Upload Product Image', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildTextField(_nameCtrl, 'Product Name', Icons.drive_file_rename_outline_rounded),
            const SizedBox(height: 16),
            _buildTextField(_priceCtrl, 'Price (INR)', Icons.payments_rounded, isNum: true),
            const SizedBox(height: 16),
            _buildCategoryDropdown(categories),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _isSaving ? null : _saveProduct,
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        editingProduct == null ? "CONFIRM ADDITION" : "SAVE CHANGES",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2),
                      ),
              ),
            ),
            if (editingProduct != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton(onPressed: _clearForm, child: const Text('Cancel Edit', style: TextStyle(color: Colors.white38))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {bool isNum = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white12, size: 18),
        filled: true,
        fillColor: _field,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _orange)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (v) => v == null || v.isEmpty ? "Required field" : null,
    );
  }

  Widget _buildCategoryDropdown(List<String> categories) {
    return DropdownButtonFormField<String>(
      value: selectedCategory,
      dropdownColor: _card,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: "Category",
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: const Icon(Icons.category_rounded, color: Colors.white12, size: 18),
        filled: true,
        fillColor: _field,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _orange)),
      ),
      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
      onChanged: (v) => setState(() => selectedCategory = v!),
    );
  }

  Widget _buildProductList(List<Product> products, bool isAdmin, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider),
      ),
      child: products.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, color: Colors.white.withOpacity(0.05), size: 48), const SizedBox(height: 12), const Text('No products found', style: TextStyle(color: Colors.white24))]))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              shrinkWrap: isMobile,
              physics: isMobile ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final p = products[i];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _bg.withOpacity(0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: _divider.withOpacity(0.5))),
                  child: Row(
                    children: [
                      Container(width: 48, height: 48, decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.fastfood_rounded, color: Colors.white12, size: 20)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(p.category, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text("₹${p.price.toStringAsFixed(0)}", style: const TextStyle(color: _orange, fontWeight: FontWeight.w900, fontSize: 15)),
                      if (isAdmin)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 12),
                            _ActionButton(Icons.edit_rounded, Colors.blue, () => _startEdit(p)),
                            const SizedBox(width: 8),
                            _ActionButton(Icons.delete_rounded, Colors.red, () => context.read<ProductProvider>().removeProduct(p.id)),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton(this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}
