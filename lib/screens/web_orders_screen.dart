import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/order_provider.dart';
import '../models/web_order.dart';
import '../models/cart_item.dart';
import 'billing_screen.dart';

// ─── DESIGN TOKENS ──────────────────────────────────────────────────────────
const Color _bg     = Color(0xFF0F1117);
const Color _card   = Color(0xFF1A1A2E);
const Color _cardAlt= Color(0xFF141420);
const Color _orange = Color(0xFFFF6A00);
const Color _div    = Color(0xFF1E2235);
const Color _green  = Color(0xFF00C853);
const Color _red    = Color(0xFFFF3D3D);
const Color _blue   = Color(0xFF2979FF);

class WebOrdersScreen extends StatefulWidget {
  const WebOrdersScreen({super.key});

  @override
  State<WebOrdersScreen> createState() => _WebOrdersScreenState();
}

class _WebOrdersScreenState extends State<WebOrdersScreen> {
  int? _selectedOrderId;   // currently selected order for detail panel
  // local edited copies: orderId → edited items list
  final Map<int, List<CartItem>> _editedItems = {};

  @override
  void initState() {
    super.initState();
    // refresh immediately when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().fetchPendingWebOrders();
    });
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  List<CartItem> _itemsFor(WebOrder order) {
    return _editedItems[order.id] ?? List.from(order.items);
  }

  void _startEditing(WebOrder order) {
    setState(() {
      _selectedOrderId = order.id;
      _editedItems[order.id] ??= order.items.map((i) => CartItem(
            product: i.product,
            quantity: i.quantity,
          )).toList();
    });
  }

  void _changeQty(int orderId, int itemIndex, int delta) {
    final list = _editedItems[orderId]!;
    setState(() {
      list[itemIndex].quantity += delta;
      if (list[itemIndex].quantity <= 0) list.removeAt(itemIndex);
    });
  }

  void _removeItem(int orderId, int itemIndex) {
    setState(() => _editedItems[orderId]!.removeAt(itemIndex));
  }

  void _cancelEdit(int orderId) {
    setState(() {
      _editedItems.remove(orderId);
      if (_selectedOrderId == orderId) _selectedOrderId = null;
    });
  }

  double _total(List<CartItem> items) =>
      items.fold(0.0, (s, i) => s + i.total);

  // ── accept → kitchen ─────────────────────────────────────────────────────
  Future<void> _acceptToKitchen(BuildContext ctx, WebOrder order) async {
    final editedList = _editedItems[order.id];
    final provider   = ctx.read<OrderProvider>();

    if (editedList != null) {
      // accept with edited items
      final edited = WebOrder(
        id:        order.id,
        tableNo:   order.tableNo,
        items:     editedList,
        note:      order.note,
        status:    order.status,
        createdAt: order.createdAt,
      );
      await provider.acceptWebOrder(edited);
    } else {
      await provider.acceptWebOrder(order);
    }

    _editedItems.remove(order.id);
    if (_selectedOrderId == order.id) setState(() => _selectedOrderId = null);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Table ${order.tableNo} → Kitchen ✓'),
      backgroundColor: _green,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── accept → billing ─────────────────────────────────────────────────────
  void _acceptToBilling(BuildContext ctx, WebOrder order) {
    final items = _editedItems[order.id] ?? List<CartItem>.from(order.items);

    // reject from pending list first
    ctx.read<OrderProvider>().rejectWebOrder(order.id);
    _editedItems.remove(order.id);
    if (_selectedOrderId == order.id) setState(() => _selectedOrderId = null);

    // navigate to billing with prefilled items
    Navigator.of(ctx).push(MaterialPageRoute(
      builder: (_) => BillingScreen(
        onToggleTheme: () {},
        tableNo: order.tableNo,
        customerName: order.customerName, // 🔥 NEW
        prefillItems: items,
      ),
    ));
  }

  // ── reject ────────────────────────────────────────────────────────────────
  void _reject(BuildContext ctx, WebOrder order) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Order?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(
          'Remove Table ${order.tableNo} web order?',
          style: const TextStyle(color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ctx.read<OrderProvider>().rejectWebOrder(order.id);
              _editedItems.remove(order.id);
              if (_selectedOrderId == order.id)
                setState(() => _selectedOrderId = null);
            },
            child: const Text('REJECT',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>().pendingWebOrders;

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(context, orders.length),
      body: LayoutBuilder(
        builder: (context, c) {
          final isWide = c.maxWidth >= 860;

          if (orders.isEmpty) return _emptyState();

          if (!isWide) {
            // ── MOBILE: full list ──
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (ctx, i) =>
                  _OrderCard(
                    order: orders[i],
                    editedItems: _editedItems[orders[i].id],
                    isSelected: false,
                    onEdit: () => _showEditSheet(context, orders[i]),
                    onReject: () => _reject(context, orders[i]),
                    onKitchen: () => _acceptToKitchen(context, orders[i]),
                    onBilling: () => _acceptToBilling(context, orders[i]),
                  ),
            );
          }

          // ── DESKTOP: split panel ──
          final selected = _selectedOrderId != null
              ? orders.where((o) => o.id == _selectedOrderId).firstOrNull
              : null;

          return Row(
            children: [
              // left: order list
              SizedBox(
                width: 380,
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: _div)),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: orders.length,
                    itemBuilder: (ctx, i) => _OrderListTile(
                      order: orders[i],
                      editedItems: _editedItems[orders[i].id],
                      isSelected: _selectedOrderId == orders[i].id,
                      onTap: () => _startEditing(orders[i]),
                    ),
                  ),
                ),
              ),
              // right: detail / edit panel
              Expanded(
                child: selected == null
                    ? _selectPrompt()
                    : _EditPanel(
                        key: ValueKey(selected.id),
                        order: selected,
                        items: _itemsFor(selected),
                        onQtyChange: (idx, d) =>
                            _changeQty(selected.id, idx, d),
                        onRemove: (idx) => _removeItem(selected.id, idx),
                        onCancel: () => _cancelEdit(selected.id),
                        onKitchen: () =>
                            _acceptToKitchen(context, selected),
                        onBilling: () =>
                            _acceptToBilling(context, selected),
                        onReject: () => _reject(context, selected),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── AppBar ──────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext ctx, int count) {
    return AppBar(
      backgroundColor: const Color(0xFF0D1117),
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          const Icon(Icons.language_rounded, color: _orange, size: 22),
          const SizedBox(width: 10),
          const Text(
            'Web Orders',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17),
          ),
          const SizedBox(width: 12),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _orange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count pending',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3),
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
          onPressed: () =>
              ctx.read<OrderProvider>().fetchPendingWebOrders(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ─── Empty state ─────────────────────────────────────────────────────────
  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.language_rounded,
              color: Colors.white12, size: 72),
          const SizedBox(height: 16),
          const Text('No pending web orders',
              style: TextStyle(
                  color: Colors.white24,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('New customer orders will appear here',
              style: TextStyle(color: Colors.white12, fontSize: 13)),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white38,
              side: const BorderSide(color: Colors.white12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () =>
                context.read<OrderProvider>().fetchPendingWebOrders(),
          ),
        ],
      ),
    );
  }

  Widget _selectPrompt() {
    return const Center(
      child: Text('← Select an order to edit',
          style: TextStyle(color: Colors.white24, fontSize: 15)),
    );
  }

  // ─── Mobile edit bottom sheet ─────────────────────────────────────────────
  void _showEditSheet(BuildContext ctx, WebOrder order) {
    _startEditing(order); // initialise edited copy
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          final items = _editedItems[order.id]!;
          return Container(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
            decoration: const BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // handle
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 4),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  _sheetHeader(order),
                  const Divider(color: _div, height: 1),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight:
                            MediaQuery.of(sheetCtx).size.height * 0.5),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _ItemEditRow(
                        item: items[i],
                        onInc: () {
                          setState(() => items[i].quantity++);
                          setSheet(() {});
                        },
                        onDec: () {
                          setState(() {
                            items[i].quantity--;
                            if (items[i].quantity <= 0) items.removeAt(i);
                          });
                          setSheet(() {});
                        },
                        onRemove: () {
                          setState(() => items.removeAt(i));
                          setSheet(() {});
                        },
                      ),
                    ),
                  ),
                  const Divider(color: _div, height: 1),
                  _sheetTotal(items),
                  _sheetActions(ctx, order),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      // if user dismissed without explicitly saving, keep edits
    });
  }

  Widget _sheetHeader(WebOrder order) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: _orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _orange.withOpacity(0.4))),
            child: Text('TABLE ${order.tableNo}',
                style: const TextStyle(
                    color: _orange,
                    fontWeight: FontWeight.w900,
                    fontSize: 13)),
          ),
          const Spacer(),
          Text('Order #${order.id}',
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _sheetTotal(List<CartItem> items) {
    final total = _total(items);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${items.length} items',
              style: const TextStyle(color: Colors.white38, fontSize: 13)),
          Text(
            '₹${total.toStringAsFixed(0)}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _sheetActions(BuildContext ctx, WebOrder order) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline_rounded, size: 15),
              label: const Text('REJECT'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _red,
                side: const BorderSide(color: _red, width: 0.8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _reject(ctx, order);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.soup_kitchen_rounded, size: 15),
              label: const Text('KITCHEN'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B4F1E),
                foregroundColor: _green,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _acceptToKitchen(ctx, order);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.receipt_long_rounded, size: 15),
              label: const Text('BILLING'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _acceptToBilling(ctx, order);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// ORDER LIST TILE (left panel on desktop)
// ──────────────────────────────────────────────────────────────────────────
class _OrderListTile extends StatelessWidget {
  final WebOrder order;
  final List<CartItem>? editedItems;
  final bool isSelected;
  final VoidCallback onTap;

  const _OrderListTile({
    required this.order,
    required this.editedItems,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items   = editedItems ?? order.items;
    final total   = items.fold(0.0, (s, i) => s + i.total);
    final minutes = DateTime.now().difference(order.createdAt).inMinutes;
    final isEdited = editedItems != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? _orange.withOpacity(0.12) : _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? _orange.withOpacity(0.6)
                : Colors.white.withOpacity(0.05),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'TABLE ${order.tableNo}',
                  style: const TextStyle(
                      color: _orange,
                      fontWeight: FontWeight.w900,
                      fontSize: 14),
                ),
                const SizedBox(width: 8),
                if (order.customerName.isNotEmpty)
                  Text(
                    order.customerName.toUpperCase(),
                    style: TextStyle(
                        color: Colors.white60,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 0.5),
                  ),
                const Spacer(),
                if (isEdited)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('EDITED',
                        style: TextStyle(
                            color: _blue,
                            fontSize: 9,
                            fontWeight: FontWeight.w800)),
                  ),
                const SizedBox(width: 6),
                Text(
                  '${minutes}m ago',
                  style: const TextStyle(
                      color: Colors.white24, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              items.map((i) => '${i.quantity}× ${i.product.name}').join(', '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${items.length} item${items.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white24, fontSize: 11),
                ),
                Text(
                  '₹${total.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// ORDER CARD  (mobile full view)
// ──────────────────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final WebOrder order;
  final List<CartItem>? editedItems;
  final bool isSelected;
  final VoidCallback onEdit;
  final VoidCallback onReject;
  final VoidCallback onKitchen;
  final VoidCallback onBilling;

  const _OrderCard({
    required this.order,
    required this.editedItems,
    required this.isSelected,
    required this.onEdit,
    required this.onReject,
    required this.onKitchen,
    required this.onBilling,
  });

  @override
  Widget build(BuildContext context) {
    final items   = editedItems ?? order.items;
    final total   = items.fold(0.0, (s, i) => s + i.total);
    final minutes = DateTime.now().difference(order.createdAt).inMinutes;
    final isEdited = editedItems != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── header ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              color: _cardAlt,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Text('TABLE ${order.tableNo}',
                    style: const TextStyle(
                        color: _orange,
                        fontWeight: FontWeight.w900,
                        fontSize: 15)),
                const SizedBox(width: 10),
                Text('#${order.id}',
                    style: const TextStyle(
                        color: Colors.white24, fontSize: 12)),
                const Spacer(),
                if (order.customerName.isNotEmpty)
                  _badge(order.customerName.toUpperCase(), _blue),
                const SizedBox(width: 6),
                _badge('${minutes}m', Colors.white24),
              ],
            ),
          ),
          // ── items ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.quantity}×  ${item.product.name}',
                        style: TextStyle(
                          color: item.isCancelled ? Colors.white24 : Colors.white,
                          fontSize: 14,
                          decoration: item.isCancelled ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (item.isCancelled)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: _red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: const Text('CANCELLED', style: TextStyle(color: _red, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    Text('₹${item.total.toStringAsFixed(0)}',
                        style: TextStyle(
                            color: item.isCancelled ? Colors.white12 : Colors.white54, 
                            fontSize: 13,
                            decoration: item.isCancelled ? TextDecoration.lineThrough : null,
                        )),
                  ],
                ),
              )).toList(),
            ),
          ),
          if (order.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text('📝 ${order.note}',
                  style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 12,
                      fontStyle: FontStyle.italic)),
            ),
          // ── total ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${items.length} item${items.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        color: Colors.white24, fontSize: 12)),
                Text('₹${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18)),
              ],
            ),
          ),
          const Divider(color: _div, height: 1),
          // ── actions ──
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Edit
                _iconBtn(
                  icon: Icons.edit_rounded,
                  color: Colors.white54,
                  tooltip: 'Edit Items',
                  onTap: onEdit,
                ),
                const SizedBox(width: 8),
                // Reject
                _iconBtn(
                  icon: Icons.delete_outline_rounded,
                  color: _red,
                  tooltip: 'Reject',
                  onTap: onReject,
                ),
                const Spacer(),
                // Kitchen
                _actionBtn(
                  label: 'KITCHEN',
                  icon: Icons.soup_kitchen_rounded,
                  bg: const Color(0xFF1B4F1E),
                  fg: _green,
                  onTap: onKitchen,
                ),
                const SizedBox(width: 8),
                // Billing
                _actionBtn(
                  label: 'BILLING',
                  icon: Icons.receipt_long_rounded,
                  bg: _orange,
                  fg: Colors.white,
                  onTap: onBilling,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(5)),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      );

  Widget _iconBtn(
      {required IconData icon,
      required Color color,
      required String tooltip,
      required VoidCallback onTap}) =>
      Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
      );

  Widget _actionBtn(
      {required String label,
      required IconData icon,
      required Color bg,
      required Color fg,
      required VoidCallback onTap}) =>
      ElevatedButton.icon(
        icon: Icon(icon, size: 14),
        label: Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9)),
        ),
        onPressed: onTap,
      );
}

// ──────────────────────────────────────────────────────────────────────────
// EDIT PANEL (right panel on desktop)
// ──────────────────────────────────────────────────────────────────────────
class _EditPanel extends StatelessWidget {
  final WebOrder order;
  final List<CartItem> items;
  final void Function(int index, int delta) onQtyChange;
  final void Function(int index) onRemove;
  final VoidCallback onCancel;
  final VoidCallback onKitchen;
  final VoidCallback onBilling;
  final VoidCallback onReject;

  const _EditPanel({
    super.key,
    required this.order,
    required this.items,
    required this.onQtyChange,
    required this.onRemove,
    required this.onCancel,
    required this.onKitchen,
    required this.onBilling,
    required this.onReject,
  });

  double get _total => items.fold(0.0, (s, i) => s + i.total);

  @override
  Widget build(BuildContext context) {
    final minutes = DateTime.now().difference(order.createdAt).inMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Panel Header ──
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _div))),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'TABLE ${order.tableNo}',
                        style: const TextStyle(
                            color: _orange,
                            fontWeight: FontWeight.w900,
                            fontSize: 20),
                      ),
                      const SizedBox(width: 12),
                      Text('#${order.id}',
                          style: const TextStyle(
                              color: Colors.white24, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Received $minutes min ago  •  ${items.length} items',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ],
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Cancel Edit'),
                style: TextButton.styleFrom(foregroundColor: Colors.white38),
                onPressed: onCancel,
              ),
            ],
          ),
        ),

        // ── Items ──
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text('No items — all removed',
                      style: TextStyle(color: Colors.white24)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _ItemEditRow(
                    item: items[i],
                    onInc: () => onQtyChange(i, 1),
                    onDec: () => onQtyChange(i, -1),
                    onRemove: () => onRemove(i),
                  ),
                ),
        ),

        // ── Total ──
        Container(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _div))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              Text(
                '₹${_total.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),

        // ── Action Buttons ──
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Row(
            children: [
              // Reject
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('REJECT'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _red,
                  side: const BorderSide(color: _red, width: 0.8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 14),
                ),
                onPressed: onReject,
              ),
              const Spacer(),
              // Kitchen
              ElevatedButton.icon(
                icon: const Icon(Icons.soup_kitchen_rounded, size: 16),
                label: const Text('SEND TO KITCHEN'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B4F1E),
                  foregroundColor: _green,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                ),
                onPressed: items.isEmpty ? null : onKitchen,
              ),
              const SizedBox(width: 12),
              // Billing
              ElevatedButton.icon(
                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                label: const Text('PROCEED TO BILLING'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                ),
                onPressed: items.isEmpty ? null : onBilling,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// ITEM EDIT ROW — used in both desktop panel + mobile sheet
// ──────────────────────────────────────────────────────────────────────────
class _ItemEditRow extends StatelessWidget {
  final CartItem item;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback onRemove;

  const _ItemEditRow({
    required this.item,
    required this.onInc,
    required this.onDec,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _cardAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          // product name + price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('₹${item.product.price.toStringAsFixed(0)} each',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          // qty controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _qtyBtn(Icons.remove_rounded, onDec),
              Container(
                width: 36,
                alignment: Alignment.center,
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15),
                ),
              ),
              _qtyBtn(Icons.add_rounded, onInc),
            ],
          ),
          const SizedBox(width: 12),
          // line total
          SizedBox(
            width: 60,
            child: Text(
              '₹${item.total.toStringAsFixed(0)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          // remove
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                color: Colors.white24, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: Colors.white54, size: 16),
      ),
    );
  }
}
