import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_provider.dart';

class LeftSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onSelect;

  const LeftSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  static const Color _orange  = Color(0xFFFF6A00);
  static const Color _bg      = Color(0xFF0F1117);
  static const Color _divider = Color(0xFF1E2235);
  static const Color _card    = Color(0xFF1A1A2E);

  // Updated navigation structure based on design images
  static const List<_NavItem> _mainNav = [
    _NavItem(0,  Icons.grid_view_rounded,              'Dashboard'),
    _NavItem(1,  Icons.bar_chart_rounded,              'Reports'),
    _NavItem(4,  Icons.star_rounded,                   'Top Products'),
    _NavItem(6,  Icons.add_business_rounded,           'Add Product'),
    _NavItem(7,  Icons.calendar_month_rounded,         'Monthly Report'),
    _NavItem(3,  Icons.view_week_rounded,              'Weekly Report'),
    _NavItem(9,  Icons.account_balance_wallet_rounded, 'Expenses'),
    _NavItem(8,  Icons.inventory_2_rounded,            'Inventory'),
  ];

  static const List<_NavItem> _secondaryNav = [
    _NavItem(5, Icons.category_rounded,           'Categories'),
    _NavItem(11, Icons.table_restaurant_rounded,   'Tables'),
    _NavItem(10, Icons.help_outline_rounded,       'Support'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240, // Slightly wider for premium feel
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(right: BorderSide(color: _divider, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 38),

          // ── BRAND ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FlavorFlow',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'THE KINETIC HEARTH',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),

          // ── MAIN NAVIGATION ────────────────────────────────
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  ..._mainNav.map((item) {
                  final active = selectedIndex == item.index;
                  return _NavTile(
                    item: item,
                    active: active,
                    onTap: () => onSelect(item.index),
                  );
                }),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                  child: Divider(color: _divider, height: 1),
                ),

                ..._secondaryNav.map((item) {
                  final active = selectedIndex == item.index;
                  return _NavTile(
                    item: item,
                    active: active,
                    onTap: () => onSelect(item.index),
                  );
                }),
              ],
            ),
            ),
          ),

          // ── FOOTER ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _divider, width: 1)),
            ),
            child: Column(
              children: [
                // Quick Bill Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _card,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                    ),
                    icon: const Icon(Icons.confirmation_number_outlined, size: 18),
                    label: const Text(
                      'Quick Bill',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Logout Button
                InkWell(
                  onTap: () => context.read<AuthProvider>().logout(),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.logout_rounded, color: Colors.white38, size: 18),
                        const SizedBox(width: 12),
                        const Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── DATA CLASS ────────────────────────────────────────────────
class _NavItem {
  final int index;
  final IconData icon;
  final String label;
  const _NavItem(this.index, this.icon, this.label);
}

// ── TILE WIDGET ───────────────────────────────────────────────
class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  static const Color _orange  = Color(0xFFFF6A00);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: active
                  ? _orange.withOpacity(0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: active
                  ? Border.all(
                      color: _orange.withOpacity(0.35), width: 0.8)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: active ? _orange : Colors.white24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? Colors.white : Colors.white38,
                    ),
                  ),
                ),
                if (active)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: _orange,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
