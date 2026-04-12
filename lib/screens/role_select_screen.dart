import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../utils/platform_check.dart';
import '../models/user_role.dart';
import '../services/auth_provider.dart';
import 'login_screen.dart';
import '../utils/responsive_helper.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  bool get _isMobileDevice => !kIsWeb && platformIsMobile;

  void _onRoleTap(BuildContext context, UserRole role) {
    context.read<AuthProvider>().setRole(role);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsiveHelper.isMobile(context)
          ? _MobileLayout(
              isMobileDevice: _isMobileDevice,
              onRoleTap: _onRoleTap,
            )
          : _DesktopLayout(
              isMobileDevice: _isMobileDevice,
              onRoleTap: _onRoleTap,
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  DESKTOP LAYOUT (side by side)
// ═══════════════════════════════════════════════════════
class _DesktopLayout extends StatelessWidget {
  final bool isMobileDevice;
  final void Function(BuildContext, UserRole) onRoleTap;

  const _DesktopLayout({
    required this.isMobileDevice,
    required this.onRoleTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isTablet = ResponsiveHelper.isTablet(context);
    return Row(
      children: [
        // ─── LEFT PANEL ───
        Expanded(
          flex: isTablet ? 45 : 55,
          child: _LeftPanel(),
        ),
        // ─── RIGHT PANEL ───
        Expanded(
          flex: isTablet ? 55 : 45,
          child: _RightPanel(
            isMobileDevice: isMobileDevice,
            onRoleTap: onRoleTap,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  MOBILE LAYOUT (stacked, left panel hidden)
// ═══════════════════════════════════════════════════════
class _MobileLayout extends StatelessWidget {
  final bool isMobileDevice;
  final void Function(BuildContext, UserRole) onRoleTap;

  const _MobileLayout({
    required this.isMobileDevice,
    required this.onRoleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ─── MESH / GLOW BACKGROUND ───
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D1117),
              gradient: LinearGradient(
                colors: [Color(0xFF1A1F2E), Color(0xFF0D1117)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        // Subtle orange glow behind top content
        Positioned(
          top: -100,
          left: -40,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF6A00).withOpacity(0.08),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        // Another glow at bottom right
        Positioned(
          bottom: -50,
          right: -50,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2A2F3E).withOpacity(0.4),
            ),
          ),
        ),

        // ─── MAIN CONTENT ───
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand Section
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6A00), Color(0xFFFF8C38)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6A00).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.local_fire_department,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FLAVORFLOW',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 2,
                          ),
                        ),
                        Container(
                          height: 2,
                          width: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6A00),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                const Text(
                  'Welcome Back',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select your terminal role to continue.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    ),
                ),
                const SizedBox(height: 36),
                _RoleTiles(
                    onRoleTap: onRoleTap,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  LEFT PANEL
// ═══════════════════════════════════════════════════════
class _LeftPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Orange gradient base
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF6A00), Color(0xFFFF8C38)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        // Restaurant ambiance overlay (image with opacity)
        Opacity(
          opacity: 0.18,
          child: Image.asset(
            'assets/images/veg_fried_rice.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(),
          ),
        ),

        // Content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Brand logo
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'FlavorFlow',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 2),

              // Headline
              const Text(
                'Restaurant\nBilling\nSoftware',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 40),

              // Feature list
              _FeatureRow(Icons.receipt_long_outlined, 'GST Billing & Invoicing'),
              _FeatureRow(Icons.kitchen_outlined, 'KDS Integration'),
              _FeatureRow(Icons.bar_chart_rounded, 'Real-time Reports'),
              _FeatureRow(Icons.inventory_2_outlined, 'Inventory Management'),

              const Spacer(flex: 3),

              // Trust badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.soup_kitchen,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Trusted by 500+ Kitchens',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Empowering the Kinetic Hearth.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureRow(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  RIGHT PANEL
// ═══════════════════════════════════════════════════════
class _RightPanel extends StatelessWidget {
  final bool isMobileDevice;
  final void Function(BuildContext, UserRole) onRoleTap;

  const _RightPanel({
    required this.isMobileDevice,
    required this.onRoleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1F2E), Color(0xFF0D1117)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Select your terminal role to continue.',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 36),

                      _RoleTiles(
                        onRoleTap: onRoleTap,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom bar
          Padding(
            padding: const EdgeInsets.only(bottom: 24, left: 40, right: 40),
            child: Row(
              children: [
                TextButton(
                  onPressed: () {},
                  child: const Text('Help Center',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () {},
                  child: const Text('Technical Support',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ),
                const Spacer(),
                const Text(
                  'v4.5.1-CLOUD',
                  style: TextStyle(color: Colors.white24, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  ROLE TILES (shared between desktop + mobile)
// ═══════════════════════════════════════════════════════
class _RoleTiles extends StatelessWidget {
  final void Function(BuildContext, UserRole) onRoleTap;

  const _RoleTiles({
    required this.onRoleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RoleCard(
          icon: Icons.shield_outlined,
          title: 'Admin Login',
          subtitle: 'FULL SYSTEM CONTROL',
          role: UserRole.admin,
          onTap: () => onRoleTap(context, UserRole.admin),
        ),
        const SizedBox(height: 12),
        _RoleCard(
          icon: Icons.person_outline_rounded,
          title: 'Staff Login',
          subtitle: 'ORDERS & CHECKOUT',
          role: UserRole.staff,
          onTap: () => onRoleTap(context, UserRole.staff),
        ),
        const SizedBox(height: 12),
        _RoleCard(
          icon: Icons.restaurant_outlined,
          title: 'Server Login',
          subtitle: 'TABLE MANAGEMENT',
          role: UserRole.server,
          onTap: () => onRoleTap(context, UserRole.server),
        ),
        const SizedBox(height: 12),
        _RoleCard(
          icon: Icons.display_settings_outlined,
          title: 'Kitchen Login',
          subtitle: 'PREP QUEUE & KDS',
          role: UserRole.kitchen,
          onTap: () => onRoleTap(context, UserRole.kitchen),
        ),
      ],
    );
  }
}

class _RoleCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final UserRole role;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.role,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFF2A2F3E)
                : const Color(0xFF1A2130).withOpacity(0.5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hovered
                  ? const Color(0xFFFF6A00).withOpacity(0.6)
                  : Colors.white.withOpacity(0.08),
              width: 1.5,
            ),
            boxShadow: [
              if (_hovered)
                BoxShadow(
                  color: const Color(0xFFFF6A00).withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _hovered
                      ? const Color(0xFFFF6A00).withOpacity(0.12)
                      : Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _hovered
                        ? const Color(0xFFFF6A00).withOpacity(0.25)
                        : Colors.white.withOpacity(0.05),
                  ),
                ),
                child: Icon(
                  widget.icon,
                  color: _hovered ? const Color(0xFFFF6A00) : Colors.white70,
                  size: 24,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.role.name.toUpperCase(),
                      style: TextStyle(
                        color: const Color(0xFFFF6A00).withOpacity(0.8),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 11,
                        letterSpacing: 0.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _hovered
                      ? const Color(0xFFFF6A00).withOpacity(0.1)
                      : Colors.transparent,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: _hovered
                      ? const Color(0xFFFF6A00)
                      : Colors.white.withOpacity(0.2),
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
