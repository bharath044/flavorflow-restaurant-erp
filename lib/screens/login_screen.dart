import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/auth_provider.dart';
import '../models/user_role.dart';
import 'root_router.dart';
import '../utils/responsive_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _error;
  bool _obscure = true;

  // Shake animation
  late AnimationController _shakeCtrl;
  late Animation<double>   _shakeAnim;

  static const Color _orange  = Color(0xFFFF6A00);
  static const int   _pinLen  = 4;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10),  weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -8),   weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8),    weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: 0),     weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _appendDigit(String digit) {
    if (_pin.length >= _pinLen) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == _pinLen) {
      _login();
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _login() {
    final auth = context.read<AuthProvider>();
    final success = auth.loginWithPin(_pin);
    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RootRouter()),
        (route) => false,
      );
    } else {
      HapticFeedback.vibrate();
      _shakeCtrl.forward(from: 0);
      setState(() {
        _error = 'Wrong PIN. Try again.';
        _pin   = '';
      });
    }
  }

  String _roleLabel(UserRole? role) {
    switch (role) {
      case UserRole.admin:   return 'ADMIN LOGIN';
      case UserRole.staff:   return 'STAFF LOGIN';
      case UserRole.server:  return 'SERVER LOGIN';
      case UserRole.kitchen: return 'KITCHEN LOGIN';
      default:               return 'LOGIN';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final size     = MediaQuery.sizeOf(context);
    final isMobile = ResponsiveHelper.isMobile(context);
    
    // Dynamic width for the login card
    final cardWidth = ResponsiveHelper.responsiveValue<double>(
      context,
      mobile: size.width * 0.9,
      tablet: 420,
      desktop: 420,
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: PopScope(
        canPop: true, // Allow back navigation
        child: Stack(
          children: [
            // ── Orange gradient bg ───────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF6A00), Color(0xFFFF8C38)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
  
            // ── Main UI Layout (Column ensures the header doesn't overlap centered card) ──
            SafeArea(
              child: Column(
                children: [
                  // ── Header row with EXIT button ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          context.read<AuthProvider>().setRole(null);
                          Navigator.of(context).pop();
                        },
                        child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.4), width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'EXIT',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 1.5),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.exit_to_app_rounded, color: Colors.white, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Centered login card ──
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 20 : 0,
                        vertical: 30,
                      ),
                      child: Container(
                        width: cardWidth,
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 28 : 40,
                          vertical: 40,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8F4),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 60,
                              offset: const Offset(0, 30),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Lock icon
                            Container(
                              width: 72,
                              height: 72,
                      decoration: BoxDecoration(
                        color: _orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.lock_rounded,
                          color: _orange, size: 34),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      _roleLabel(auth.role),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Color(0xFF1A0A00),
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'The Kinetic Hearth  •  Terminal 01',
                      style: TextStyle(
                          color: Colors.black45,
                          fontSize: 12,
                          letterSpacing: 0.3),
                    ),

                    const SizedBox(height: 36),

                    // ── PIN LABEL ─────────────────────────────
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'ENTER 4-DIGIT PIN',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── 4-DOT PIN DISPLAY ─────────────────────
                    AnimatedBuilder(
                      animation: _shakeAnim,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(_shakeAnim.value, 0),
                        child: child,
                      ),
                      child: Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1117),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _error != null
                                ? Colors.red.withOpacity(0.5)
                                : Colors.transparent,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Dot indicators
                            Center(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: List.generate(_pinLen, (i) {
                                  final filled = i < _pin.length;
                                  final showDigit =
                                      !_obscure && filled;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: showDigit
                                        ? Text(
                                            _pin[i],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 150),
                                            width: filled ? 16 : 10,
                                            height: filled ? 16 : 10,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: filled
                                                  ? _orange
                                                  : Colors.white24,
                                            ),
                                          ),
                                  );
                                }),
                              ),
                            ),

                            // Eye toggle
                            Positioned(
                              right: 14,
                              top: 0,
                              bottom: 0,
                              child: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.white38,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Error
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 12)),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 28),

                    // ── ON-SCREEN NUMPAD ──────────────────────
                    _buildNumpad(),

                    const SizedBox(height: 24),
                    const Divider(color: Colors.black12),
                    const SizedBox(height: 14),

                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Contact your admin to reset credentials.'),
                          ),
                        );
                      },
                      child: const Text(
                        'FORGOT PIN?',
                        style: TextStyle(
                          color: Colors.black38,
                          fontSize: 12,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      '• POWERED BY FLAVORFLOW •',
                      style: TextStyle(
                        color: Colors.black26,
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  ),

          // ── Bottom status bar ────────────────────────────────
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatusDot(label: 'NETWORK STABLE', active: true),
                const SizedBox(width: 24),
                _StatusDot(label: 'KITCHEN LINK ACTIVE', active: true),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  // ── ON-SCREEN NUMPAD ────────────────────────────────────────────
  Widget _buildNumpad() {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    final size = MediaQuery.sizeOf(context);
    // Dynamic sizing for keys based on screen
    final keyWidth = ResponsiveHelper.responsiveValue<double>(
      context,
      mobile: (size.width * 0.9 - 80) / 3, // Roughly fit in card
      tablet: 90,
      desktop: 80,
    ).clamp(60.0, 100.0);

    final keyHeight = ResponsiveHelper.responsiveValue<double>(
      context,
      mobile: 50,
      tablet: 60,
      desktop: 56,
    );

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) {
                return SizedBox(width: keyWidth, height: keyHeight);
              }
              final isBack = key == '⌫';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _NumKey(
                  label   : key,
                  isBack  : isBack,
                  width   : keyWidth,
                  height  : keyHeight,
                  onTap   : isBack
                      ? _backspace
                      : () => _appendDigit(key),
                  disabled: !isBack && _pin.length >= _pinLen,
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

// ── NUM KEY ───────────────────────────────────────────────────────
class _NumKey extends StatelessWidget {
  final String   label;
  final bool     isBack;
  final bool     disabled;
  final double   width;
  final double   height;
  final VoidCallback onTap;

  const _NumKey({
    required this.label,
    required this.isBack,
    required this.onTap,
    required this.width,
    required this.height,
    this.disabled = false,
  });

  static const Color _orange = Color(0xFFFF6A00);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isBack
              ? _orange.withOpacity(0.08)
              : const Color(0xFFF3EDE8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isBack
                ? _orange.withOpacity(0.25)
                : Colors.black.withOpacity(0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: isBack
              ? Icon(Icons.backspace_rounded,
                    color: _orange, size: 22)
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: disabled
                        ? Colors.black26
                        : const Color(0xFF1A0A00),
                  ),
                ),
        ),
      ),
    );
  }
}

// ── STATUS DOT ────────────────────────────────────────────────────
class _StatusDot extends StatelessWidget {
  final String label;
  final bool   active;

  const _StatusDot({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? Colors.white.withOpacity(0.6)
                : Colors.white24,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 10,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
