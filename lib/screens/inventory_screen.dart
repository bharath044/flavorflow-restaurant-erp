import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/raw_material.dart';
import '../models/stock_entry.dart';
import '../models/product.dart'; // 🔥 NEW: Added to fix Recipe tab type crash
import '../providers/inventory_provider.dart';
import '../providers/product_provider.dart';
import '../utils/responsive_helper.dart';

const _orange = Color(0xFFFF6A00);

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 76,
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Inventory Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Track materials, stock levels & wastage',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.38),
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(color: Color(0xFF1E2235), height: 1, thickness: 1),
              TabBar(
                controller: _tabs,
                isScrollable: true,
                indicatorColor: _orange,
                indicatorWeight: 2,
                labelColor: _orange,
                unselectedLabelColor: Colors.white38,
                labelStyle: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w500),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tabs: const [
                  Tab(icon: Icon(Icons.kitchen_rounded, size: 16),         text: 'Materials'),
                  Tab(icon: Icon(Icons.add_shopping_cart_rounded, size: 16), text: 'Stock In'),
                  Tab(icon: Icon(Icons.delete_outline_rounded, size: 16),   text: 'Wastage'),
                  Tab(icon: Icon(Icons.tune_rounded, size: 16),             text: 'Adjust'),
                  Tab(icon: Icon(Icons.restaurant_menu_rounded, size: 16),  text: 'Recipe'),
                  Tab(icon: Icon(Icons.bar_chart_rounded, size: 16),        text: 'Reports'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _MaterialsTab(),
          _StockInTab(),
          _WastageTab(),
          _AdjustTab(),
          _RecipeTab(),
          _InventoryReportTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 1 — RAW MATERIALS
// ═══════════════════════════════════════════════════════════
class _MaterialsTab extends StatelessWidget {
  const _MaterialsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (_, inv, __) {
        final mats = inv.materials;
        return Scaffold(
          backgroundColor: const Color(0xFF0F1117),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_inventory_materials',
            backgroundColor: _orange,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Entry',
                style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () => _showMaterialDialog(context),
          ),
          body: mats.isEmpty
              ? _emptyState('No raw materials yet.\nTap + to add.')
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: mats.length,
                  itemBuilder: (_, i) => _MaterialCard(mats[i]),
                ),
        );
      },
    );
  }

  void _showMaterialDialog(BuildContext context, [RawMaterial? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name);
    final stockCtrl =
        TextEditingController(text: existing?.currentStock.toString() ?? '0');
    final minCtrl =
        TextEditingController(text: existing?.minStockLevel.toString() ?? '0');
    final supplierCtrl = TextEditingController(text: existing?.supplierName);
    String unit = existing?.unit ?? 'kg';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, ss) {
        return AlertDialog(
          title: Text(existing == null ? 'Add Raw Material' : 'Edit Material'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _field('Item Name', nameCtrl),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: unit,
                decoration: _dec('Unit'),
                items: ['kg', 'g', 'litre', 'ml', 'pcs', 'dozen']
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => ss(() => unit = v!),
              ),
              const SizedBox(height: 12),
              _field('Current Stock', stockCtrl, isNum: true),
              const SizedBox(height: 12),
              _field('Min Stock Alert Level', minCtrl, isNum: true),
              const SizedBox(height: 12),
              _field('Supplier Name (optional)', supplierCtrl),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _orange),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                final mat = RawMaterial(
                  id: existing?.id ?? const Uuid().v4(),
                  name: nameCtrl.text.trim(),
                  unit: unit,
                  currentStock:
                      double.tryParse(stockCtrl.text) ?? 0,
                  minStockLevel:
                      double.tryParse(minCtrl.text) ?? 0,
                  supplierName: supplierCtrl.text.trim().isEmpty
                      ? null
                      : supplierCtrl.text.trim(),
                );
                context.read<InventoryProvider>().addMaterial(mat);
                Navigator.pop(ctx);
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        );
      }),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  final RawMaterial m;
  const _MaterialCard(this.m);

  @override
  Widget build(BuildContext context) {
    final isLow = m.isLowStock;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLow
              ? Colors.red.withOpacity(0.5)
              : const Color(0xFF1E2235),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isLow
                ? Colors.red.withOpacity(0.14)
                : const Color(0xFF4ADE80).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.inventory_2_rounded,
              color: isLow ? Colors.red.shade400 : const Color(0xFF4ADE80),
              size: 20),
        ),
        title: Text(m.name,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
        subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stock: ${m.currentStock} ${m.unit}',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12),
              ),
              if (isLow)
                Text(
                  'Low! Min: ${m.minStockLevel} ${m.unit}',
                  style: const TextStyle(
                      color: Colors.red, fontSize: 11.5),
                ),
              if (m.supplierName != null)
                Text(
                  'Supplier: ${m.supplierName}',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withOpacity(0.28)),
                ),
            ]),
        trailing: PopupMenuButton(
          color: const Color(0xFF1A1A1A),
          icon: const Icon(Icons.more_vert_rounded,
              color: Colors.white38),
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'edit',
                child: Text('Edit',
                    style: TextStyle(color: Colors.white70))),
            const PopupMenuItem(
                value: 'delete',
                child: Text('Delete',
                    style: TextStyle(color: Colors.red))),
          ],
          onSelected: (v) {
            if (v == 'edit') {
              _MaterialsTab()._showMaterialDialog(context, m);
            } else {
              context.read<InventoryProvider>().deleteMaterial(m.id);
            }
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 2 — STOCK IN (PURCHASE)
// ═══════════════════════════════════════════════════════════
class _StockInTab extends StatelessWidget {
  const _StockInTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (_, inv, __) {
        final items = inv.stockIns;
        return Scaffold(
          backgroundColor: const Color(0xFF0F1117),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_inventory_stockin',
            backgroundColor: _orange,
            icon: const Icon(Icons.add),
            label: const Text('Add Purchase',
                style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () => _showStockInDialog(context, inv.materials),
          ),
          body: items.isEmpty
              ? _emptyState('No purchases yet.\nTap + to record.')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final e = items[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF1E2235)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.shopping_cart_rounded,
                                color: Color(0xFF3B82F6), size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.materialName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(
                                    '${e.quantity} ${e.unit}  •  ₹${e.purchasePrice}/${e.unit}',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.45),
                                        fontSize: 12)),
                                Text('Supplier: ${e.supplierName}',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.3),
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('₹${e.computedTotal.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      color: Color(0xFF3B82F6),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(
                                  '${e.date.day}/${e.date.month}/${e.date.year}',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.3),
                                      fontSize: 11)),
                            ],
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            color: const Color(0xFF1A1A1A),
                            icon: const Icon(Icons.more_vert_rounded, color: Colors.white24, size: 20),
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'delete', child: Text('Delete Log', style: TextStyle(color: Colors.red))),
                            ],
                            onSelected: (v) {
                              if (v == 'delete') {
                                context.read<InventoryProvider>().deleteStockIn(e.id);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _showStockInDialog(BuildContext context, List<RawMaterial> materials) {
    if (materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add raw materials first')));
      return;
    }
    String? selectedId = materials.first.id;
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final supplierCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, ss) {
        final mat = materials.firstWhere((m) => m.id == selectedId,
            orElse: () => materials.first);
        return AlertDialog(
          title: const Text('Record Purchase'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: selectedId,
                decoration: _dec('Material'),
                items: materials
                    .map((m) => DropdownMenuItem(
                        value: m.id, child: Text('${m.name} (${m.unit})')))
                    .toList(),
                onChanged: (v) => ss(() => selectedId = v),
              ),
              const SizedBox(height: 12),
              _field('Quantity (${mat.unit})', qtyCtrl, isNum: true),
              const SizedBox(height: 12),
              _field('Purchase Price (₹ per ${mat.unit})', priceCtrl, isNum: true),
              const SizedBox(height: 12),
              _field('Supplier Name', supplierCtrl),
              const SizedBox(height: 12),
              _field('Notes (optional)', notesCtrl),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _orange),
              onPressed: () {
                final qty = double.tryParse(qtyCtrl.text) ?? 0;
                final price = double.tryParse(priceCtrl.text) ?? 0;
                if (qty <= 0 || supplierCtrl.text.trim().isEmpty) return;
                final entry = StockIn(
                  id: const Uuid().v4(),
                  materialId: mat.id,
                  materialName: mat.name,
                  unit: mat.unit,
                  quantity: qty,
                  purchasePrice: price,
                  supplierName: supplierCtrl.text.trim(),
                  date: DateTime.now(),
                  notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                );
                context.read<InventoryProvider>().addStockIn(entry);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        '✅ ${mat.name}: +$qty ${mat.unit} added to stock')));
              },
              child: const Text('Record'),
            ),
          ],
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 3 — WASTAGE
// ═══════════════════════════════════════════════════════════
class _WastageTab extends StatelessWidget {
  const _WastageTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (_, inv, __) {
        final items = inv.wastage;
        return Scaffold(
          backgroundColor: const Color(0xFF0F1117),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_inventory_wastage',
            backgroundColor: const Color(0xFFEF4444),
            icon: const Icon(Icons.delete_forever),
            label: const Text('Record Wastage',
                style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () => _showWastageDialog(context, inv.materials),
          ),
          body: items.isEmpty
              ? _emptyState('No wastage recorded yet.')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final e = items[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFFEF4444).withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.delete_outline_rounded,
                                color: Color(0xFFEF4444), size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.materialName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                                const SizedBox(height: 4),
                                Text('${e.quantity} ${e.unit}  •  ${e.reason}',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.45),
                                        fontSize: 12)),
                                Text(
                                    '${e.date.day}/${e.date.month}/${e.date.year}',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.3),
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.white24, size: 20),
                            onPressed: () => context
                                .read<InventoryProvider>()
                                .deleteWastage(e.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _showWastageDialog(BuildContext context, List<RawMaterial> materials) {
    if (materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add raw materials first')));
      return;
    }
    String? selectedId = materials.first.id;
    final qtyCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, ss) {
        final mat = materials.firstWhere((m) => m.id == selectedId,
            orElse: () => materials.first);
        return AlertDialog(
          title: const Text('Record Wastage'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: selectedId,
              decoration: _dec('Material'),
              items: materials
                  .map((m) => DropdownMenuItem(
                      value: m.id, child: Text('${m.name} (${m.unit})')))
                  .toList(),
              onChanged: (v) => ss(() => selectedId = v),
            ),
            const SizedBox(height: 12),
            _field('Wasted Quantity (${mat.unit})', qtyCtrl, isNum: true),
            const SizedBox(height: 12),
            _field('Reason (spoilage / damage / etc)', reasonCtrl),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                final qty = double.tryParse(qtyCtrl.text) ?? 0;
                if (qty <= 0 || reasonCtrl.text.trim().isEmpty) return;
                context.read<InventoryProvider>().addWastage(WastageEntry(
                  id: const Uuid().v4(),
                  materialId: mat.id,
                  materialName: mat.name,
                  unit: mat.unit,
                  quantity: qty,
                  reason: reasonCtrl.text.trim(),
                  date: DateTime.now(),
                ));
                Navigator.pop(ctx);
              },
              child: const Text('Record'),
            ),
          ],
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 4 — STOCK ADJUSTMENT
// ═══════════════════════════════════════════════════════════
class _AdjustTab extends StatelessWidget {
  const _AdjustTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (_, inv, __) {
        final items = inv.adjustments;
        return Scaffold(
          backgroundColor: const Color(0xFF0F1117),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_inventory_adjust',
            backgroundColor: const Color(0xFF6366F1),
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Adjust Stock',
                style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () => _showAdjustDialog(context, inv.materials),
          ),
          body: items.isEmpty
              ? _emptyState('No adjustments yet.')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final a = items[i];
                    final isIncrease = a.difference >= 0;
                    final accent = isIncrease
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFFFB923C);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: accent.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isIncrease
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              color: accent, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.materialName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(
                                    '${a.oldQty} → ${a.newQty} ${a.unit}',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.45),
                                        fontSize: 12)),
                                Text('Reason: ${a.reason}',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.3),
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                          Text(
                            '${isIncrease ? '+' : ''}${a.difference.toStringAsFixed(1)}',
                            style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.white24, size: 18),
                            onPressed: () => context
                                .read<InventoryProvider>()
                                .deleteAdjustment(a.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _showAdjustDialog(BuildContext context, List<RawMaterial> materials) {
    if (materials.isEmpty) return;
    String? selectedId = materials.first.id;
    final newQtyCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, ss) {
        final mat = materials.firstWhere((m) => m.id == selectedId,
            orElse: () => materials.first);
        return AlertDialog(
          title: const Text('Stock Adjustment'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: selectedId,
              decoration: _dec('Material'),
              items: materials
                  .map((m) => DropdownMenuItem(
                      value: m.id,
                      child: Text('${m.name} (${m.currentStock} ${m.unit})')))
                  .toList(),
              onChanged: (v) => ss(() {
                selectedId = v;
                newQtyCtrl.text = '';
              }),
            ),
            const SizedBox(height: 8),
            Text('Current: ${mat.currentStock} ${mat.unit}',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            _field('New Correct Quantity (${mat.unit})', newQtyCtrl, isNum: true),
            const SizedBox(height: 12),
            _field('Reason for adjustment', reasonCtrl),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
              onPressed: () {
                final newQty = double.tryParse(newQtyCtrl.text);
                if (newQty == null || reasonCtrl.text.trim().isEmpty) return;
                context.read<InventoryProvider>().addAdjustment(
                  StockAdjustment(
                    id: const Uuid().v4(),
                    materialId: mat.id,
                    materialName: mat.name,
                    unit: mat.unit,
                    oldQty: mat.currentStock,
                    newQty: newQty,
                    reason: reasonCtrl.text.trim(),
                    date: DateTime.now(),
                  ),
                );
                Navigator.pop(ctx);
              },
              child: const Text('Adjust'),
            ),
          ],
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 5 — RECIPE MAPPING
// ═══════════════════════════════════════════════════════════
class _RecipeTab extends StatelessWidget {
  const _RecipeTab();

  @override
  Widget build(BuildContext context) {
    return Consumer2<InventoryProvider, ProductProvider>(
      builder: (_, inv, prod, __) {
        final products = prod.products;
        final recipes = inv.recipes;

        // Group by product
        final Map<String, List<RecipeIngredient>> grouped = {};
        for (final r in recipes) {
          grouped.putIfAbsent(r.productId, () => []).add(r);
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0F1117),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_inventory_recipe',
            backgroundColor: _orange,
            icon: const Icon(Icons.restaurant_menu_rounded),
            label: const Text('Map Recipe',
                style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () => _showRecipeDialog(context, products, inv.materials),
          ),
          body: grouped.isEmpty
              ? _emptyState('No recipes mapped yet.\nMap products → ingredients.')
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: grouped.entries.map((entry) {
                    final productName = entry.value.first.productName;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF1E2235)),
                      ),
                      child: ExpansionTile(
                        iconColor: _orange,
                        collapsedIconColor: Colors.white38,
                        title: Text(productName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        subtitle: Text('${entry.value.length} ingredient(s)',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 12)),
                        leading: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: _orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.restaurant_rounded,
                              color: _orange, size: 18),
                        ),
                        children: entry.value
                            .map((ri) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                        top: BorderSide(
                                            color: Color(0xFF1E2235))),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.fiber_manual_record,
                                          size: 6, color: Colors.white24),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(ri.materialName,
                                                style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600)),
                                            Text(
                                                '${ri.quantityPerServing} ${ri.unit} per serving',
                                                style: TextStyle(
                                                    color: Colors.white
                                                        .withOpacity(0.35),
                                                    fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded,
                                            color: Color(0xFFEF4444), size: 18),
                                        onPressed: () =>
                                            inv.deleteRecipeIngredient(
                                                ri.productId, ri.materialId),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    );
                  }).toList(),
                ),
        );
      },
    );
  }

  void _showRecipeDialog(BuildContext context, List<Product> products,
      List<RawMaterial> materials) {
    if (products.isEmpty || materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add products and raw materials first')));
      return;
    }
    String? productId = products.first.id;
    String? materialId = materials.first.id;
    final qtyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, ss) {
        final mat =
            materials.firstWhere((m) => m.id == materialId, orElse: () => materials.first);
        final prod = products.firstWhere((p) => p.id == productId,
            orElse: () => products.first);
        return AlertDialog(
          title: const Text('Map Recipe Ingredient'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: productId,
              decoration: _dec('Product (Dish)'),
              items: products
                  .map((p) => DropdownMenuItem(
                      value: p.id, child: Text(p.name)))
                  .toList(),
              onChanged: (v) => ss(() => productId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: materialId,
              decoration: _dec('Raw Material'),
              items: materials
                  .map((m) => DropdownMenuItem(
                      value: m.id, child: Text('${m.name} (${m.unit})')))
                  .toList(),
              onChanged: (v) => ss(() => materialId = v),
            ),
            const SizedBox(height: 12),
            _field('Qty per serving (${mat.unit})', qtyCtrl, isNum: true),
            const SizedBox(height: 8),
            Text(
                'Example: 1 ${prod.name} uses ${qtyCtrl.text.isEmpty ? '?' : qtyCtrl.text} ${mat.unit} of ${mat.name}',
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _orange),
              onPressed: () {
                final qty = double.tryParse(qtyCtrl.text) ?? 0;
                if (qty <= 0) return;
                context.read<InventoryProvider>().upsertRecipeIngredient(
                  RecipeIngredient(
                    productId: prod.id,
                    productName: prod.name,
                    materialId: mat.id,
                    materialName: mat.name,
                    unit: mat.unit,
                    quantityPerServing: qty,
                  ),
                );
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 6 — INVENTORY REPORTS
// ═══════════════════════════════════════════════════════════
class _InventoryReportTab extends StatelessWidget {
  const _InventoryReportTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (_, inv, __) {
        final mats = inv.materials;
        final lowStock = inv.lowStockMaterials;
        final totalItems = mats.length;
        final totalStockIns = inv.stockIns.length;
        final totalWastage = inv.wastage.length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // KPI Grid (Responsive)
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: ResponsiveHelper.responsiveValue<int>(
                context,
                mobile: 2,
                desktop: 4,
              ),
              childAspectRatio: ResponsiveHelper.responsiveValue<double>(
                context,
                mobile: 1.3,
                desktop: 1.6,
              ),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _reportKpi('Total Materials', '$totalItems',
                    const Color(0xFF3B82F6), Icons.inventory_2_rounded),
                _reportKpi('Low Stock', '${lowStock.length}',
                    const Color(0xFFEF4444), Icons.warning_amber_rounded),
                _reportKpi('Purchases', '$totalStockIns',
                    const Color(0xFF4ADE80), Icons.shopping_cart_rounded),
                _reportKpi('Wastage', '$totalWastage',
                    const Color(0xFFFB923C), Icons.delete_outline_rounded),
              ],
            ),
            const SizedBox(height: 24),

            // Low Stock Alert Panel
            if (lowStock.isNotEmpty) ...[
              _sectionHeader('⚠️  Low Stock Alerts'),
              const SizedBox(height: 10),
              ...lowStock.map((m) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFEF4444).withOpacity(0.35)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFEF4444), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                            Text(
                                'Current: ${m.currentStock} ${m.unit}  •  Min: ${m.minStockLevel} ${m.unit}',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ]),
                  )),
              const SizedBox(height: 20),
            ],

            // All Materials Stock Level
            _sectionHeader('📦  Current Stock Levels'),
            const SizedBox(height: 10),
            if (mats.isEmpty)
              _emptyState('No materials added yet.')
            else
              ...mats.map((m) {
                final pct = m.minStockLevel > 0
                    ? (m.currentStock / (m.minStockLevel * 3)).clamp(0.0, 1.0)
                    : 1.0;
                final accent = m.isLowStock
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF4ADE80);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E2235)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(m.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          Text('${m.currentStock} ${m.unit}',
                              style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: Colors.white.withOpacity(0.06),
                          color: accent,
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ]),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════

Widget _emptyState(String msg) => Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1E2235)),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                size: 48, color: Colors.white24),
          ),
          const SizedBox(height: 20),
          Text(msg,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 15,
                  height: 1.5)),
        ]),
      ),
    );

Widget _sectionHeader(String title) => Text(
      title,
      style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2),
    );

Widget _reportKpi(String label, String value, Color accent, IconData icon) =>
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2235)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );

TextField _field(String label, TextEditingController ctrl,
        {bool isNum = false}) =>
    TextField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: _dec(label),
    );

InputDecoration _dec(String label) => InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
