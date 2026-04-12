import 'package:flutter/material.dart';
import '../models/cart_item.dart';

class CartPanel extends StatelessWidget {
  final List<CartItem> cart;
  final Function(CartItem, int) onQtyChange;
  final double subTotal;
  final double gstAmount;
  final double grandTotal;
  final VoidCallback onClear;
  final VoidCallback onPrint;
  final String actionLabel;
  final String? customerName; // 🔥 NEW
  final String? tableNo; // 🔥 NEW

  const CartPanel({
    super.key,
    required this.cart,
    required this.onQtyChange,
    required this.subTotal,
    required this.gstAmount,
    required this.grandTotal,
    required this.onClear,
    required this.onPrint,
    this.actionLabel = 'SAVE BILL',
    this.customerName, // 🔥 NEW
    this.tableNo, // 🔥 NEW
  });

  static const Color _bg = Color(0xFF131720);
  static const Color _card = Color(0xFF1C2235);
  static const Color _orange = Color(0xFFFF6A00);
  static const Color _divider = Color(0xFF252D45);

  @override
  Widget build(BuildContext context) {
    // Generate a deterministic short order number from current time
    final orderNo =
        'ORD#${(DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000).toString().padLeft(5, '0')}';

    return Material(
      color: _bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── HEADER ───
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: _card,
              border: Border(bottom: BorderSide(color: _divider, width: 1)),
            ),
            child: Row(
              children: [
                const Text(
                  'Bill Summary',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _orange.withOpacity(0.4), width: 1),
                  ),
                  child: Text(
                    customerName != null && customerName!.isNotEmpty 
                      ? customerName!.toUpperCase() 
                      : orderNo,
                    style: const TextStyle(
                      color: _orange,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (customerName != null && tableNo != null)
                   Padding(
                     padding: const EdgeInsets.only(left: 8),
                     child: Text(
                       '#$tableNo',
                       style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w900),
                     ),
                   ),
              ],
            ),
          ),

          // ─── CART ITEMS ───
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            color: Colors.white12, size: 52),
                        const SizedBox(height: 12),
                        const Text(
                          'Cart is empty',
                          style: TextStyle(
                              color: Colors.white30, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Add items to start billing',
                          style: TextStyle(
                              color: Colors.white24, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    physics: const BouncingScrollPhysics(),
                    itemCount: cart.length,
                    separatorBuilder: (_, __) => const Divider(
                        color: _divider, height: 1, indent: 14, endIndent: 14),
                    itemBuilder: (_, i) {
                      final c = cart[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            // Item info
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.product.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '₹${c.product.price.toInt()} × ${c.quantity}',
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Qty controls
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _qtyBtn(
                                    icon: Icons.remove,
                                    onTap: () => onQtyChange(c, -1)),
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    c.quantity.toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                _qtyBtn(
                                    icon: Icons.add,
                                    onTap: () => onQtyChange(c, 1)),
                              ],
                            ),

                            const SizedBox(width: 10),

                            // Line total
                            SizedBox(
                              width: 56,
                              child: Text(
                                '₹${c.total.toInt()}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: _orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // ─── TOTALS + ACTIONS ───
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: const BoxDecoration(
              color: _card,
              border: Border(top: BorderSide(color: _divider, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _totalRow('Subtotal', subTotal),
                const SizedBox(height: 6),
                _totalRow('GST (5%)', gstAmount),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: _divider, height: 1),
                ),
                _totalRow('GRAND TOTAL', grandTotal, isTotal: true),

                const SizedBox(height: 14),

                Row(
                  children: [
                    // CLEAR
                    Expanded(
                      child: OutlinedButton(
                        onPressed: cart.isEmpty ? null : onClear,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade400,
                          side: BorderSide(
                              color: cart.isEmpty
                                  ? Colors.white12
                                  : Colors.red.shade400,
                              width: 1.5),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          'CLEAR',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // PRINT BILL
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: cart.isEmpty ? null : onPrint,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _orange,
                          disabledBackgroundColor:
                              Colors.white.withOpacity(0.06),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              actionLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── QTY BUTTON ───
  Widget _qtyBtn({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14, color: Colors.white70),
      ),
    );
  }

  // ─── TOTAL ROW ───
  Widget _totalRow(String label, double value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? Colors.white : Colors.white54,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
            fontSize: isTotal ? 14.5 : 13,
            letterSpacing: isTotal ? 0.5 : 0,
          ),
        ),
        Text(
          '₹${value.toStringAsFixed(2)}',
          style: TextStyle(
            color: isTotal ? _orange : Colors.white70,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
            fontSize: isTotal ? 16 : 13,
          ),
        ),
      ],
    );
  }
}
