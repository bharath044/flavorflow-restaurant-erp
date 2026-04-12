import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../providers/category_provider.dart';
import '../widgets/icon_picker.dart';

// ─── DESIGN TOKENS ────────────────────────────────────────────
const Color _kBg      = Color(0xFF0F1117);
const Color _kCard    = Color(0xFF1A1A1A);
const Color _kDivider = Color(0xFF1E2235);
const Color _kOrange  = Color(0xFFFF6A00);
const Color _kField   = Color(0xFF1A1A2E);
const Color _kBorder  = Color(0xFF252D45);

class CategoryManageScreen extends StatefulWidget {
  const CategoryManageScreen({super.key});

  @override
  State<CategoryManageScreen> createState() =>
      _CategoryManageScreenState();
}

class _CategoryManageScreenState extends State<CategoryManageScreen> {
  final _nameCtrl = TextEditingController();
  IconData selectedIcon = Icons.fastfood;

  // ─── ADD ────────────────────────────────────────────────────
  void _addCategory() {
    if (_nameCtrl.text.trim().isEmpty) return;
    context.read<CategoryProvider>().addCategory(
          Category(name: _nameCtrl.text.trim(), icon: selectedIcon),
        );
    _nameCtrl.clear();
    selectedIcon = Icons.fastfood;
    setState(() {});
  }

  // ─── EDIT ───────────────────────────────────────────────────
  void _editCategory(int index, Category c) {
    _nameCtrl.text = c.name;
    selectedIcon = c.icon;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Category',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _darkField(controller: _nameCtrl, hint: 'Category name'),
            const SizedBox(height: 16),
            IconPicker(
              selected: selectedIcon,
              onSelect: (i) => setState(() => selectedIcon = i),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _kOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              context.read<CategoryProvider>().updateCategory(
                    index,
                    Category(name: _nameCtrl.text.trim(), icon: selectedIcon),
                  );
              _nameCtrl.clear();
              selectedIcon = Icons.fastfood;
              Navigator.pop(context);
            },
            child: const Text('SAVE',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── BUILD ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    final categories = context.watch<CategoryProvider>().categories;

    return Container(
      color: _kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── PAGE HEADER ───────────────────────────────────
          Container(
            color: const Color(0xFF0D1117),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Category Management',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Create and manage menu categories',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.38),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2235),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kDivider),
                  ),
                  child: Text(
                    '${categories.length} CATEGORIES',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: _kDivider, height: 1),

          // ── CONTENT ───────────────────────────────────────
          Expanded(
            child: isMobile
                ? _mobileLayout(categories)
                : _desktopLayout(categories),
          ),
        ],
      ),
    );
  }

  Widget _desktopLayout(List<Category> categories) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 340,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _addCard(),
          ),
        ),
        Container(width: 1, color: _kDivider),
        Expanded(
          child: _categoryList(categories),
        ),
      ],
    );
  }

  Widget _mobileLayout(List<Category> categories) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _addCard(),
          const SizedBox(height: 16),
          ..._buildCategoryItems(categories),
        ],
      ),
    );
  }

  // ── ADD FORM CARD ───────────────────────────────────────────
  Widget _addCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        const Text(
          'NEW CATEGORY',
          style: TextStyle(
            color: Colors.white24,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kDivider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category name field
              const Text('Category Name',
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _darkField(controller: _nameCtrl, hint: 'e.g. Starters, Beverages'),
              const SizedBox(height: 18),

              // Icon picker
              const Text('Select Icon',
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              IconPicker(
                selected: selectedIcon,
                onSelect: (i) => setState(() => selectedIcon = i),
              ),

              const SizedBox(height: 18),

              // Create button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _addCategory,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Create Category',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13.5)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Pro tip card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kOrange.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: _kOrange.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  color: _kOrange, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pro Tip: Use clear, descriptive names. Categories appear on the POS menu.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── CATEGORY LIST ───────────────────────────────────────────
  Widget _categoryList(List<Category> categories) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EXISTING CATEGORIES',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (categories.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 48),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kDivider),
              ),
              child: Column(
                children: [
                  Icon(Icons.category_rounded,
                      color: Colors.white.withOpacity(0.1), size: 48),
                  const SizedBox(height: 12),
                  Text('No categories yet',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.28),
                          fontSize: 14)),
                ],
              ),
            )
          else
            ..._buildCategoryItems(categories),
        ],
      ),
    );
  }

  List<Widget> _buildCategoryItems(List<Category> categories) {
    return categories.asMap().entries.map((entry) {
      final i = entry.key;
      final c = entry.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kDivider),
          ),
          child: Row(
            children: [
              // Icon circle
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _kOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(c.icon, color: _kOrange, size: 20),
              ),
              const SizedBox(width: 14),
              // Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        )),
                    Text(
                      'Kitchen route: Main',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              // Edit button
              _iconBtn(
                icon: Icons.edit_rounded,
                color: Colors.white24,
                onTap: () => _editCategory(i, c),
              ),
              const SizedBox(width: 6),
              // Delete button
              _iconBtn(
                icon: Icons.delete_rounded,
                color: Colors.red.shade400,
                onTap: () => context.read<CategoryProvider>().deleteCategory(i),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  // ─── HELPERS ────────────────────────────────────────────────
  Widget _darkField({
    required TextEditingController controller,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 13.5),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Colors.white24, fontSize: 13),
        filled: true,
        fillColor: _kField,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kOrange, width: 1.5),
        ),
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
      ),
    );
  }
}
