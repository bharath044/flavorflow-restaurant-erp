import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_provider.dart';

class IdleLogoutWrapper extends StatefulWidget {
  final Widget child;
  const IdleLogoutWrapper({super.key, required this.child});

  @override
  State<IdleLogoutWrapper> createState() => _IdleLogoutWrapperState();
}

class _IdleLogoutWrapperState extends State<IdleLogoutWrapper> {
  static const Duration idleTimeout = Duration(minutes: 60);
  Timer? _timer;

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(idleTimeout, _handleLogout);
  }

  void _handleLogout() {
    final auth = context.read<AuthProvider>();

    if (auth.isLoggedIn) {
      /// ✅ ONLY LOGOUT
      /// ❌ NO NAVIGATION HERE
      auth.logout();
    }
  }

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      onPointerSignal: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
